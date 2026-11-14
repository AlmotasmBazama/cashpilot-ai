import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/agent/ai_agent_contracts.dart';
import '../../domain/gateway/ai_conversation_gateway.dart';
import '../config/ai_gateway_feature_flags.dart';
import 'buffered_sse_decoder.dart';
import 'firebase_gateway_token_provider.dart';

class GroqGatewayClient {
  GroqGatewayClient({
    required AiGatewayRuntimeConfig config,
    required AiGatewayTokenProvider tokenProvider,
    required http.Client httpClient,
    String? clientPlatform,
    void Function(String message)? safeDiagnosticLog,
  }) : _config = config,
       _tokenProvider = tokenProvider,
       _httpClient = httpClient,
       _clientPlatform = _safeClientPlatform(clientPlatform),
       _safeDiagnosticLog = safeDiagnosticLog;

  final AiGatewayRuntimeConfig _config;
  final AiGatewayTokenProvider _tokenProvider;
  final http.Client _httpClient;
  final String _clientPlatform;
  final void Function(String message)? _safeDiagnosticLog;

  Stream<AiGatewayEvent> streamRequest(
    String path,
    AiGatewayRequest request, {
    required AiProviderEgressGuard egressGuard,
  }) {
    final cancellation = _AiGatewayRequestCancellation();
    return Stream<AiGatewayEvent>.multi((events) {
      final subscription = _streamRequest(
        path,
        request,
        egressGuard: egressGuard,
        cancellation: cancellation,
      ).listen(events.add, onError: events.addError, onDone: events.close);
      events.onCancel = () async {
        cancellation.cancel();
        try {
          await subscription.cancel();
        } on AiProviderEgressRevokedException {
          // Expected when cancellation releases a readiness wait before egress.
        }
      };
    });
  }

  Stream<AiGatewayEvent> _streamRequest(
    String path,
    AiGatewayRequest request, {
    required AiProviderEgressGuard egressGuard,
    required _AiGatewayRequestCancellation cancellation,
  }) async* {
    final trace = _FlutterGatewayStreamTrace(
      requestId: request.requestId,
      route: path,
      sink: _safeDiagnosticLog,
    );
    final baseUri = _config.baseUri;
    if (baseUri == null) {
      trace.finish(
        parserResult: 'configurationFailure',
        failureCode: AiGatewayFailureCode.groqNotConfigured,
      );
      throw const AiGatewayException(
        code: AiGatewayFailureCode.groqNotConfigured,
        safeMessage: 'The AI gateway is not configured.',
      );
    }
    late AiGatewayTokens tokens;
    try {
      cancellation.assertActive();
      egressGuard.assertActive();
      tokens = await _tokenProvider.freshTokens(egressGuard: egressGuard);
      cancellation.assertActive();
      egressGuard.assertActive();
    } on AiGatewayException catch (failure) {
      trace.finish(parserResult: 'tokenFailure', failureCode: failure.code);
      rethrow;
    }
    final uri = baseUri.resolve(path);
    final transport = http.Request('POST', uri)
      ..headers.addAll(<String, String>{
        'Authorization': 'Bearer ${tokens.firebaseIdToken}',
        'X-Firebase-AppCheck': tokens.appCheckToken,
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        'X-Request-ID': request.requestId,
        'X-CashPilot-Platform': _clientPlatform,
      })
      ..body = jsonEncode(request.toJson());
    late http.StreamedResponse response;
    try {
      cancellation.assertActive();
      response = await egressGuard.runSerializedAuthOperation(() {
        cancellation.assertActive();
        egressGuard.assertActive();
        return _httpClient.send(transport).timeout(_config.requestTimeout);
      });
      cancellation.assertActive();
    } on AiProviderEgressRevokedException {
      rethrow;
    } on TimeoutException {
      trace.finish(
        parserResult: 'requestTimeout',
        failureCode: AiGatewayFailureCode.groqRequestTimedOut,
      );
      throw const AiGatewayException(
        code: AiGatewayFailureCode.groqRequestTimedOut,
        safeMessage: 'The AI gateway request timed out.',
      );
    } on Object {
      trace.finish(
        parserResult: 'networkFailure',
        failureCode: AiGatewayFailureCode.gatewayUnavailable,
      );
      throw const AiGatewayException(
        code: AiGatewayFailureCode.gatewayUnavailable,
        safeMessage: 'The AI gateway could not be reached.',
      );
    }

    trace.httpStatus = _httpStatusCategory(response.statusCode);
    final gatewayRequestId =
        response.headers['x-request-id']?.trim() ?? request.requestId;
    trace.gatewayRequestId = gatewayRequestId;
    if (gatewayRequestId != request.requestId) {
      trace.finish(
        parserResult: 'requestIdMismatch',
        failureCode: AiGatewayFailureCode.groqMalformedResponse,
      );
      throw const AiGatewayException(
        code: AiGatewayFailureCode.groqMalformedResponse,
        safeMessage: 'The AI gateway request identifier did not match.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      final failure = _failureFromHttp(
        response.statusCode,
        body,
        response.headers['retry-after'],
      );
      if (failure.code == AiGatewayFailureCode.appCheckRejected) {
        _reportAppCheckRejected();
      }
      trace.finish(parserResult: 'httpFailure', failureCode: failure.code);
      throw failure;
    }

    var sawStarted = false;
    var sawCompleted = false;
    var sawContent = false;
    try {
      await for (final frame
          in response.stream
              .transform(const BufferedSseDecoder())
              .timeout(_config.requestTimeout)) {
        cancellation.assertActive();
        if (frame.event != null &&
            frame.event != 'cashpilot' &&
            frame.event != 'message') {
          throw const _MalformedSseException();
        }
        final payload = frame.data.trim();
        if (payload.isEmpty) {
          continue;
        }
        final decoded = jsonDecode(payload);
        if (decoded is! Map) {
          throw const _MalformedSseException();
        }
        final event = _eventFromJson(Map<String, Object?>.from(decoded));
        if (event.requestId != request.requestId) {
          throw const _MalformedSseException();
        }
        trace.recordEvent(event.type);
        if (event.type == AiGatewayEventType.failure) {
          final eventFailureCode = event.failureCode;
          final failure = AiGatewayException(
            code:
                eventFailureCode == AiGatewayFailureCode.gatewayAppCheckRequired
                ? AiGatewayFailureCode.appCheckRejected
                : eventFailureCode ??
                      AiGatewayFailureCode.unknownTemporaryFailure,
            safeMessage: 'The AI gateway failed safely.',
            retryAfterSeconds: event.retryAfterSeconds,
          );
          if (failure.code == AiGatewayFailureCode.appCheckRejected) {
            _reportAppCheckRejected();
          }
          trace.finish(
            parserResult: 'gatewayFailureEvent',
            failureCode: failure.code,
          );
          throw failure;
        }
        if (sawCompleted) {
          throw const _MalformedSseException();
        }
        switch (event.type) {
          case AiGatewayEventType.started:
            if (sawStarted) {
              throw const _MalformedSseException();
            }
            sawStarted = true;
            break;
          case AiGatewayEventType.textDelta:
            if (!sawStarted || event.delta == null || event.delta!.isEmpty) {
              throw const _MalformedSseException();
            }
            sawContent = true;
            break;
          case AiGatewayEventType.toolSelection:
            if (!sawStarted || event.toolSelection == null) {
              throw const _MalformedSseException();
            }
            sawContent = true;
            break;
          case AiGatewayEventType.warning:
            if (!sawStarted || event.warningCode == null) {
              throw const _MalformedSseException();
            }
            break;
          case AiGatewayEventType.completed:
            if (!sawStarted) {
              throw const _MalformedSseException();
            }
            if (!sawContent) {
              final failure = const AiGatewayException(
                code: AiGatewayFailureCode.groqMalformedResponse,
                safeMessage: 'The AI gateway returned no usable content.',
              );
              trace.finish(
                parserResult: 'emptyResponse',
                failureCode: failure.code,
              );
              throw failure;
            }
            sawCompleted = true;
            break;
          case AiGatewayEventType.failure:
            throw const _MalformedSseException();
        }
        yield event;
      }
      if (!sawCompleted) {
        final failure = const AiGatewayException(
          code: AiGatewayFailureCode.groqMalformedResponse,
          safeMessage: 'The AI gateway stream ended before completion.',
        );
        trace.finish(
          parserResult: 'streamEndedWithoutCompleted',
          failureCode: failure.code,
        );
        throw failure;
      }
      trace.finish(parserResult: 'completed');
    } on AiProviderEgressRevokedException {
      rethrow;
    } on AiGatewayException {
      rethrow;
    } on TimeoutException {
      trace.finish(
        parserResult: 'streamTimeout',
        failureCode: AiGatewayFailureCode.groqStreamTimedOut,
      );
      throw const AiGatewayException(
        code: AiGatewayFailureCode.groqStreamTimedOut,
        safeMessage: 'The AI gateway stream timed out.',
      );
    } on Object {
      trace.finish(
        parserResult: 'malformedSse',
        failureCode: AiGatewayFailureCode.groqMalformedResponse,
      );
      throw const AiGatewayException(
        code: AiGatewayFailureCode.groqMalformedResponse,
        safeMessage: 'The AI gateway returned malformed SSE.',
      );
    }
  }

  Future<AiGatewayHealth> healthCheck() async {
    final baseUri = _config.baseUri;
    if (baseUri == null) {
      return const AiGatewayHealth(reachable: false);
    }
    try {
      final response = await _httpClient
          .get(baseUri.resolve('/health'))
          .timeout(const Duration(seconds: 5));
      return AiGatewayHealth(reachable: response.statusCode == 200);
    } on Object {
      return const AiGatewayHealth(reachable: false);
    }
  }

  AiGatewayException _failureFromHttp(
    int status,
    String body,
    String? retryAfterHeader,
  ) {
    AiGatewayFailureCode? code;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final failure = decoded['failure'];
        if (failure is Map) {
          code = _failureCode(failure['code']?.toString());
        }
      }
    } on Object {
      // Raw gateway error bodies are intentionally discarded.
    }
    if (status == 403 || code == AiGatewayFailureCode.gatewayAppCheckRequired) {
      code = AiGatewayFailureCode.appCheckRejected;
    }
    code ??= switch (status) {
      400 => AiGatewayFailureCode.gatewayRequestInvalid,
      401 => AiGatewayFailureCode.gatewayAuthenticationRequired,
      403 => AiGatewayFailureCode.appCheckRejected,
      413 => AiGatewayFailureCode.gatewayRequestInvalid,
      429 => AiGatewayFailureCode.groqRateLimited,
      >= 500 => AiGatewayFailureCode.groqUpstreamUnavailable,
      _ => AiGatewayFailureCode.gatewayRequestInvalid,
    };
    return AiGatewayException(
      code: code,
      safeMessage: 'The AI gateway rejected the request safely.',
      retryAfterSeconds: int.tryParse(retryAfterHeader ?? ''),
    );
  }

  void _reportAppCheckRejected() {
    final tokenProvider = _tokenProvider;
    if (tokenProvider is AiGatewayAppCheckRejectionReporter) {
      (tokenProvider as AiGatewayAppCheckRejectionReporter)
          .reportAppCheckRejected();
    }
  }

  AiGatewayEvent _eventFromJson(Map<String, Object?> json) {
    final type = AiGatewayEventType.values
        .where((value) => value.name == json['type'])
        .firstOrNull;
    final requestId = json['requestId'];
    if (type == null || requestId is! String) {
      throw const _MalformedSseException();
    }
    final failureCode = type == AiGatewayEventType.failure
        ? _failureCode(json['code']?.toString())
        : null;
    if (type == AiGatewayEventType.failure && failureCode == null) {
      throw const _MalformedSseException();
    }
    return AiGatewayEvent(
      type: type,
      requestId: requestId,
      delta: json['delta'] as String?,
      warningCode: json['code'] as String?,
      failureCode: failureCode,
      retryAfterSeconds: json['retryAfterSeconds'] as int?,
      toolSelection: type == AiGatewayEventType.toolSelection
          ? _toolSelection(json['selection'])
          : null,
    );
  }

  AiGatewayToolSelection _toolSelection(Object? value) {
    if (value is! Map ||
        value['toolSelections'] is! List ||
        (value['clarification'] != null && value['clarification'] is! String)) {
      throw const FormatException('Invalid tool selection.');
    }
    final calls = <AiGatewayToolCall>[];
    for (final item in value['toolSelections'] as List) {
      if (item is! Map ||
          item['name'] is! String ||
          item['arguments'] is! Map) {
        throw const FormatException('Invalid tool call.');
      }
      calls.add(
        AiGatewayToolCall(
          name: item['name'] as String,
          arguments: Map<String, Object?>.from(item['arguments'] as Map),
        ),
      );
    }
    return AiGatewayToolSelection(
      calls: List<AiGatewayToolCall>.unmodifiable(calls),
      clarification: value['clarification'] as String?,
    );
  }

  AiGatewayFailureCode? _failureCode(String? value) {
    return AiGatewayFailureCode.values
        .where((code) => code.name == value)
        .firstOrNull;
  }
}

class _MalformedSseException implements Exception {
  const _MalformedSseException();
}

final class _AiGatewayRequestCancellation {
  var _cancelled = false;

  void cancel() => _cancelled = true;

  void assertActive() {
    if (_cancelled) throw const AiProviderEgressRevokedException();
  }
}

class _FlutterGatewayStreamTrace {
  _FlutterGatewayStreamTrace({
    required this.requestId,
    required this.route,
    required this.sink,
  });

  final String requestId;
  final String route;
  final void Function(String message)? sink;
  final Set<AiGatewayEventType> _eventTypes = <AiGatewayEventType>{};
  String httpStatus = 'notStarted';
  String gatewayRequestId = 'notReceived';
  bool _finished = false;

  void recordEvent(AiGatewayEventType type) => _eventTypes.add(type);

  void finish({
    required String parserResult,
    AiGatewayFailureCode? failureCode,
  }) {
    if (_finished) {
      return;
    }
    _finished = true;
    sink?.call(
      jsonEncode(<String, Object?>{
        'kind': 'cashpilot_ai_flutter_stream',
        'requestId': requestId,
        'gatewayRequestId': gatewayRequestId,
        'route': route,
        'httpStatusCategory': httpStatus,
        'normalizedSseEventTypes': _eventTypes
            .map((type) => type.name)
            .toList(growable: false),
        'parserResult': parserResult,
        'finalCode': failureCode?.name ?? 'completed',
      }),
    );
  }
}

String _httpStatusCategory(int status) => switch (status) {
  >= 200 && < 300 => 'success',
  401 || 403 => 'authenticationRejected',
  429 => 'rateLimited',
  >= 500 => 'serverError',
  _ => 'clientError',
};

String _safeClientPlatform(String? configured) {
  final value = (configured ?? _runtimeClientPlatform()).trim().toLowerCase();
  return const <String>{
        'web',
        'android',
        'ios',
        'macos',
        'windows',
        'linux',
        'fuchsia',
      }.contains(value)
      ? value
      : 'unknown';
}

String _runtimeClientPlatform() {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.linux => 'linux',
    TargetPlatform.fuchsia => 'fuchsia',
  };
}
