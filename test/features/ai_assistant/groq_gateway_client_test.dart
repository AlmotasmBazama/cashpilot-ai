import 'dart:async';
import 'dart:convert';

import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_gateway_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/gateway/firebase_gateway_token_provider.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/gateway/groq_gateway_client.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/gateway/groq_gateway_data_source.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/gateway/ai_conversation_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../helpers/ai_provider_egress_test_guard.dart';

void main() {
  test(
    'sends fresh Firebase Auth and App Check tokens, but no provider data',
    () async {
      late http.Request captured;
      final client = GroqGatewayClient(
        config: AiGatewayRuntimeConfig.resolve(
          baseUrl: 'https://gateway.example',
        ),
        tokenProvider: const _TokenProvider(),
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            [
              'data: ${jsonEncode(<String, Object?>{'type': 'started', 'requestId': 'request_12345'})}',
              '',
              'data: ${jsonEncode(<String, Object?>{'type': 'textDelta', 'requestId': 'request_12345', 'delta': 'Hello'})}',
              '',
              'data: ${jsonEncode(<String, Object?>{'type': 'completed', 'requestId': 'request_12345'})}',
              '',
            ].join('\n'),
            200,
            headers: <String, String>{'content-type': 'text/event-stream'},
          );
        }),
        clientPlatform: 'android',
      );

      final events = await client
          .streamRequest(
            '/v1/ai/general-chat',
            _generalRequest(),
            egressGuard: testAiProviderEgressGuard,
          )
          .toList();

      expect(events.map((event) => event.type), <AiGatewayEventType>[
        AiGatewayEventType.started,
        AiGatewayEventType.textDelta,
        AiGatewayEventType.completed,
      ]);
      expect(captured.headers['Authorization'], 'Bearer id-token-test');
      expect(captured.headers['X-Firebase-AppCheck'], 'app-check-test');
      expect(captured.headers['X-CashPilot-Platform'], 'android');
      expect(captured.body, isNot(contains('GROQ')));
      expect(captured.body, isNot(contains('model')));
      expect(captured.body, isNot(contains('id-token-test')));
      expect(captured.body, isNot(contains('app-check-test')));
      expect(captured.body, isNot(contains('test-user')));
      expect(
        captured.body,
        isNot(
          contains(
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          ),
        ),
      );
    },
  );

  test('typed failure event throws without exposing raw response', () async {
    final client = GroqGatewayClient(
      config: AiGatewayRuntimeConfig.resolve(
        baseUrl: 'https://gateway.example',
      ),
      tokenProvider: const _TokenProvider(),
      httpClient: MockClient(
        (_) async => http.Response(
          'data: ${jsonEncode(<String, Object?>{'type': 'failure', 'requestId': 'request_12345', 'code': 'appCheckRejected'})}\n\n',
          200,
        ),
      ),
    );

    await expectLater(
      client
          .streamRequest(
            '/v1/ai/general-chat',
            _generalRequest(),
            egressGuard: testAiProviderEgressGuard,
          )
          .toList(),
      throwsA(
        isA<AiGatewayException>().having(
          (failure) => failure.code,
          'code',
          AiGatewayFailureCode.appCheckRejected,
        ),
      ),
    );
  });

  test('gateway App Check failure event is a confirmed rejection', () async {
    final tokens = _RejectionAwareTokenProvider();
    final client = GroqGatewayClient(
      config: AiGatewayRuntimeConfig.resolve(
        baseUrl: 'https://gateway.example',
      ),
      tokenProvider: tokens,
      httpClient: MockClient(
        (_) async => http.Response(
          'data: ${jsonEncode(<String, Object?>{'type': 'failure', 'requestId': 'request_12345', 'code': 'gatewayAppCheckRequired'})}\n\n',
          200,
        ),
      ),
    );

    await expectLater(
      client
          .streamRequest(
            '/v1/ai/general-chat',
            _generalRequest(),
            egressGuard: testAiProviderEgressGuard,
          )
          .toList(),
      throwsA(
        isA<AiGatewayException>().having(
          (failure) => failure.code,
          'code',
          AiGatewayFailureCode.appCheckRejected,
        ),
      ),
    );
    expect(tokens.tokenCalls, 1);
    expect(tokens.rejectionReports, 1);
  });

  test('unconfigured gateway fails before tokens or transport', () async {
    final tokens = _CountingTokenProvider();
    final client = GroqGatewayClient(
      config: AiGatewayRuntimeConfig.resolve(),
      tokenProvider: tokens,
      httpClient: MockClient((_) async => http.Response('', 500)),
    );

    await expectLater(
      client
          .streamRequest(
            '/v1/ai/general-chat',
            _generalRequest(),
            egressGuard: testAiProviderEgressGuard,
          )
          .toList(),
      throwsA(
        isA<AiGatewayException>().having(
          (failure) => failure.code,
          'code',
          AiGatewayFailureCode.groqNotConfigured,
        ),
      ),
    );
    expect(tokens.calls, 0);
  });

  test(
    'stream cancellation while waiting for tokens sends zero HTTP',
    () async {
      final tokens = _PendingTokenProvider();
      final transport = _ChunkedClient(chunks: const <List<int>>[]);
      final client = GroqGatewayClient(
        config: AiGatewayRuntimeConfig.resolve(
          baseUrl: 'https://gateway.example',
        ),
        tokenProvider: tokens,
        httpClient: transport,
      );

      final subscription = client
          .streamRequest(
            '/v1/ai/general-chat',
            _generalRequest(),
            egressGuard: testAiProviderEgressGuard,
          )
          .listen((_) {});
      await tokens.started.future;
      final cancelled = subscription.cancel();
      tokens.complete();
      await cancelled;
      await Future<void>.delayed(Duration.zero);

      expect(tokens.calls, 1);
      expect(transport.calls, 0);
    },
  );

  test(
    'buffers arbitrary byte chunks, CRLF frames, multiline data, and Arabic UTF-8',
    () async {
      const arabic = 'ما هو التضخم؟';
      final startedJson = jsonEncode(<String, Object?>{
        'type': 'started',
        'requestId': 'request_12345',
      });
      final splitAt = startedJson.indexOf(',') + 1;
      final body =
          'event: cashpilot\r\n'
          'data: ${startedJson.substring(0, splitAt)}\r\n'
          'data: ${startedJson.substring(splitAt)}\r\n'
          '\r\n'
          'event: cashpilot\r\n'
          'data: ${jsonEncode(<String, Object?>{'type': 'textDelta', 'requestId': 'request_12345', 'delta': arabic})}\r\n'
          '\r\n'
          'event: cashpilot\r\n'
          'data: ${jsonEncode(<String, Object?>{'type': 'completed', 'requestId': 'request_12345'})}';
      final bytes = utf8.encode(body);
      final client = GroqGatewayClient(
        config: AiGatewayRuntimeConfig.resolve(
          baseUrl: 'https://gateway.example',
        ),
        tokenProvider: const _TokenProvider(),
        httpClient: _ChunkedClient(
          chunks: bytes.map((byte) => <int>[byte]).toList(growable: false),
        ),
      );

      final events = await client
          .streamRequest(
            '/v1/ai/general-chat',
            _generalRequest(),
            egressGuard: testAiProviderEgressGuard,
          )
          .toList();

      expect(events.map((event) => event.type), <AiGatewayEventType>[
        AiGatewayEventType.started,
        AiGatewayEventType.textDelta,
        AiGatewayEventType.completed,
      ]);
      expect(events[1].delta, arabic);
    },
  );

  test('does not duplicate deltas or fail after completed', () async {
    final client = _clientForSse(
      _sse(<Map<String, Object?>>[
        <String, Object?>{'type': 'started', 'requestId': 'request_12345'},
        <String, Object?>{
          'type': 'textDelta',
          'requestId': 'request_12345',
          'delta': 'one',
        },
        <String, Object?>{
          'type': 'textDelta',
          'requestId': 'request_12345',
          'delta': 'two',
        },
        <String, Object?>{'type': 'completed', 'requestId': 'request_12345'},
      ]),
    );

    final events = await client
        .streamRequest(
          '/v1/ai/general-chat',
          _generalRequest(),
          egressGuard: testAiProviderEgressGuard,
        )
        .toList();

    expect(
      events
          .where((event) => event.type == AiGatewayEventType.textDelta)
          .map((event) => event.delta),
      <String?>['one', 'two'],
    );
    expect(events.last.type, AiGatewayEventType.completed);
  });

  test('HTTP 200 failure event keeps its typed code', () async {
    final client = _clientForSse(
      _sse(<Map<String, Object?>>[
        <String, Object?>{'type': 'started', 'requestId': 'request_12345'},
        <String, Object?>{
          'type': 'failure',
          'requestId': 'request_12345',
          'code': 'providerUnavailable',
        },
      ]),
    );

    await expectLater(
      client
          .streamRequest(
            '/v1/ai/general-chat',
            _generalRequest(),
            egressGuard: testAiProviderEgressGuard,
          )
          .toList(),
      throwsA(
        isA<AiGatewayException>().having(
          (failure) => failure.code,
          'code',
          AiGatewayFailureCode.providerUnavailable,
        ),
      ),
    );
  });

  test('stream ending without completed is typed', () async {
    final client = _clientForSse(
      _sse(<Map<String, Object?>>[
        <String, Object?>{'type': 'started', 'requestId': 'request_12345'},
        <String, Object?>{
          'type': 'textDelta',
          'requestId': 'request_12345',
          'delta': 'partial',
        },
      ]),
    );

    await expectLater(
      client
          .streamRequest(
            '/v1/ai/general-chat',
            _generalRequest(),
            egressGuard: testAiProviderEgressGuard,
          )
          .toList(),
      throwsA(
        isA<AiGatewayException>().having(
          (failure) => failure.code,
          'code',
          AiGatewayFailureCode.groqMalformedResponse,
        ),
      ),
    );
  });

  test(
    'completed stream with no usable content is a typed Groq response failure',
    () async {
      final client = _clientForSse(
        _sse(<Map<String, Object?>>[
          <String, Object?>{'type': 'started', 'requestId': 'request_12345'},
          <String, Object?>{'type': 'completed', 'requestId': 'request_12345'},
        ]),
      );

      await expectLater(
        client
            .streamRequest(
              '/v1/ai/general-chat',
              _generalRequest(),
              egressGuard: testAiProviderEgressGuard,
            )
            .toList(),
        throwsA(
          isA<AiGatewayException>().having(
            (failure) => failure.code,
            'code',
            AiGatewayFailureCode.groqMalformedResponse,
          ),
        ),
      );
    },
  );

  test('unknown or malformed event is a typed Groq response failure', () async {
    final client = _clientForSse(
      'event: cashpilot\n'
      'data: {"type":"mystery","requestId":"request_12345"}\n\n',
    );

    await expectLater(
      client
          .streamRequest(
            '/v1/ai/general-chat',
            _generalRequest(),
            egressGuard: testAiProviderEgressGuard,
          )
          .toList(),
      throwsA(
        isA<AiGatewayException>().having(
          (failure) => failure.code,
          'code',
          AiGatewayFailureCode.groqMalformedResponse,
        ),
      ),
    );
  });

  test(
    'model unavailable HTTP response maps without raw body exposure',
    () async {
      final client = GroqGatewayClient(
        config: AiGatewayRuntimeConfig.resolve(
          baseUrl: 'https://gateway.example',
        ),
        tokenProvider: const _TokenProvider(),
        httpClient: _ChunkedClient(
          statusCode: 503,
          chunks: <List<int>>[
            utf8.encode(
              jsonEncode(<String, Object?>{
                'failure': <String, Object?>{
                  'code': 'providerUnavailable',
                  'message': 'discarded',
                },
              }),
            ),
          ],
        ),
      );

      await expectLater(
        client
            .streamRequest(
              '/v1/ai/general-chat',
              _generalRequest(),
              egressGuard: testAiProviderEgressGuard,
            )
            .toList(),
        throwsA(
          isA<AiGatewayException>().having(
            (failure) => failure.code,
            'code',
            AiGatewayFailureCode.providerUnavailable,
          ),
        ),
      );
    },
  );

  for (final entry in <(int, String, AiGatewayFailureCode)>[
    (429, 'rateLimited', AiGatewayFailureCode.rateLimited),
    (503, 'providerQuotaExceeded', AiGatewayFailureCode.providerQuotaExceeded),
  ]) {
    test('${entry.$2} HTTP mapping remains distinct', () async {
      final client = GroqGatewayClient(
        config: AiGatewayRuntimeConfig.resolve(
          baseUrl: 'https://gateway.example',
        ),
        tokenProvider: const _TokenProvider(),
        httpClient: _ChunkedClient(
          statusCode: entry.$1,
          chunks: <List<int>>[
            utf8.encode(
              jsonEncode(<String, Object?>{
                'failure': <String, Object?>{'code': entry.$2},
              }),
            ),
          ],
        ),
      );

      await expectLater(
        client
            .streamRequest(
              '/v1/ai/general-chat',
              _generalRequest(),
              egressGuard: testAiProviderEgressGuard,
            )
            .toList(),
        throwsA(
          isA<AiGatewayException>().having(
            (failure) => failure.code,
            'code',
            entry.$3,
          ),
        ),
      );
    });
  }

  for (final entry in <(int, AiGatewayFailureCode)>[
    (400, AiGatewayFailureCode.gatewayRequestInvalid),
    (401, AiGatewayFailureCode.gatewayAuthenticationRequired),
    (403, AiGatewayFailureCode.appCheckRejected),
    (429, AiGatewayFailureCode.groqRateLimited),
    (503, AiGatewayFailureCode.groqUpstreamUnavailable),
  ]) {
    test('HTTP ${entry.$1} has a typed gateway failure', () async {
      final client = GroqGatewayClient(
        config: AiGatewayRuntimeConfig.resolve(
          baseUrl: 'https://gateway.example',
        ),
        tokenProvider: const _TokenProvider(),
        httpClient: _ChunkedClient(
          statusCode: entry.$1,
          chunks: const <List<int>>[],
        ),
      );

      await expectLater(
        client
            .streamRequest(
              '/v1/ai/general-chat',
              _generalRequest(),
              egressGuard: testAiProviderEgressGuard,
            )
            .toList(),
        throwsA(
          isA<AiGatewayException>().having(
            (failure) => failure.code,
            'code',
            entry.$2,
          ),
        ),
      );
    });
  }

  test('HTTP 403 reports one rejection and never loops transport', () async {
    final tokens = _RejectionAwareTokenProvider();
    final transport = _ChunkedClient(
      statusCode: 403,
      chunks: const <List<int>>[],
    );
    final client = GroqGatewayClient(
      config: AiGatewayRuntimeConfig.resolve(
        baseUrl: 'https://gateway.example',
      ),
      tokenProvider: tokens,
      httpClient: transport,
    );

    await expectLater(
      client
          .streamRequest(
            '/v1/ai/general-chat',
            _generalRequest(),
            egressGuard: testAiProviderEgressGuard,
          )
          .toList(),
      throwsA(
        isA<AiGatewayException>().having(
          (failure) => failure.code,
          'code',
          AiGatewayFailureCode.appCheckRejected,
        ),
      ),
    );

    expect(tokens.tokenCalls, 1);
    expect(tokens.rejectionReports, 1);
    expect(transport.calls, 1);
  });

  test('HTTP 401 typed App Check failure is a confirmed rejection', () async {
    final tokens = _RejectionAwareTokenProvider();
    final transport = _ChunkedClient(
      statusCode: 401,
      chunks: <List<int>>[
        utf8.encode(
          jsonEncode(<String, Object?>{
            'failure': <String, Object?>{'code': 'gatewayAppCheckRequired'},
          }),
        ),
      ],
    );
    final client = GroqGatewayClient(
      config: AiGatewayRuntimeConfig.resolve(
        baseUrl: 'https://gateway.example',
      ),
      tokenProvider: tokens,
      httpClient: transport,
    );

    await expectLater(
      client
          .streamRequest(
            '/v1/ai/general-chat',
            _generalRequest(),
            egressGuard: testAiProviderEgressGuard,
          )
          .toList(),
      throwsA(
        isA<AiGatewayException>().having(
          (failure) => failure.code,
          'code',
          AiGatewayFailureCode.appCheckRejected,
        ),
      ),
    );
    expect(tokens.tokenCalls, 1);
    expect(tokens.rejectionReports, 1);
    expect(transport.calls, 1);
  });

  test('general data source makes one transport attempt per message', () async {
    final transport = _ChunkedClient(
      statusCode: 503,
      chunks: const <List<int>>[],
    );
    final dataSource = GroqGatewayDataSource(
      GroqGatewayClient(
        config: AiGatewayRuntimeConfig.resolve(
          baseUrl: 'https://gateway.example',
        ),
        tokenProvider: const _TokenProvider(),
        httpClient: transport,
      ),
    );

    await expectLater(
      dataSource
          .streamGeneralConversation(
            _generalRequest(),
            egressGuard: testAiProviderEgressGuard,
          )
          .toList(),
      throwsA(
        isA<AiGatewayException>().having(
          (failure) => failure.code,
          'code',
          AiGatewayFailureCode.groqUpstreamUnavailable,
        ),
      ),
    );
    expect(transport.calls, 1);
  });

  test('request ID is propagated in secret-safe parser diagnostics', () async {
    final diagnostics = <String>[];
    final privateRequest = const AiGatewayRequest(
      requestId: 'request_12345',
      mode: AiGatewayMode.generalConversation,
      locale: 'en',
      sanitizedMessages: <AiGatewayMessage>[
        AiGatewayMessage(role: 'user', content: 'PRIVATE_PROMPT_MARKER'),
      ],
      timeoutClass: AiGatewayTimeoutClass.interactive,
      clientVersion: 'test',
    );
    final client = GroqGatewayClient(
      config: AiGatewayRuntimeConfig.resolve(
        baseUrl: 'https://gateway.example',
      ),
      tokenProvider: const _TokenProvider(),
      httpClient: _ChunkedClient(
        headers: const <String, String>{
          'x-request-id': 'request_12345',
          'content-type': 'text/event-stream',
        },
        chunks: <List<int>>[
          utf8.encode(
            _sse(<Map<String, Object?>>[
              <String, Object?>{
                'type': 'started',
                'requestId': 'request_12345',
              },
              <String, Object?>{
                'type': 'textDelta',
                'requestId': 'request_12345',
                'delta': 'PRIVATE_RESPONSE_MARKER',
              },
              <String, Object?>{
                'type': 'completed',
                'requestId': 'request_12345',
              },
            ]),
          ),
        ],
      ),
      safeDiagnosticLog: diagnostics.add,
    );

    await client
        .streamRequest(
          '/v1/ai/general-chat',
          privateRequest,
          egressGuard: testAiProviderEgressGuard,
        )
        .toList();

    expect(diagnostics, hasLength(1));
    expect(diagnostics.single, contains('"requestId":"request_12345"'));
    expect(diagnostics.single, contains('"gatewayRequestId":"request_12345"'));
    expect(diagnostics.single, contains('"parserResult":"completed"'));
    expect(diagnostics.single, isNot(contains('PRIVATE_PROMPT_MARKER')));
    expect(diagnostics.single, isNot(contains('PRIVATE_RESPONSE_MARKER')));
    expect(diagnostics.single, isNot(contains('id-token-test')));
    expect(diagnostics.single, isNot(contains('app-check-test')));
  });
}

GroqGatewayClient _clientForSse(String body) => GroqGatewayClient(
  config: AiGatewayRuntimeConfig.resolve(baseUrl: 'https://gateway.example'),
  tokenProvider: const _TokenProvider(),
  httpClient: _ChunkedClient(chunks: <List<int>>[utf8.encode(body)]),
);

String _sse(List<Map<String, Object?>> events) => events
    .map((event) => 'event: cashpilot\ndata: ${jsonEncode(event)}\n\n')
    .join();

AiGatewayRequest _generalRequest() => const AiGatewayRequest(
  requestId: 'request_12345',
  mode: AiGatewayMode.generalConversation,
  locale: 'en',
  sanitizedMessages: <AiGatewayMessage>[
    AiGatewayMessage(role: 'user', content: 'Hello'),
  ],
  timeoutClass: AiGatewayTimeoutClass.interactive,
  clientVersion: 'test',
);

class _TokenProvider implements AiGatewayTokenProvider {
  const _TokenProvider();

  @override
  Future<AiGatewayTokens> freshTokens({
    required AiProviderEgressGuard egressGuard,
  }) async => const AiGatewayTokens(
    firebaseIdToken: 'id-token-test',
    appCheckToken: 'app-check-test',
  );
}

class _CountingTokenProvider implements AiGatewayTokenProvider {
  int calls = 0;

  @override
  Future<AiGatewayTokens> freshTokens({
    required AiProviderEgressGuard egressGuard,
  }) async {
    calls += 1;
    return const AiGatewayTokens(
      firebaseIdToken: 'id-token-test',
      appCheckToken: 'app-check-test',
    );
  }
}

class _PendingTokenProvider implements AiGatewayTokenProvider {
  final started = Completer<void>();
  final _tokens = Completer<AiGatewayTokens>();
  int calls = 0;

  void complete() {
    _tokens.complete(
      const AiGatewayTokens(
        firebaseIdToken: 'id-token-test',
        appCheckToken: 'app-check-test',
      ),
    );
  }

  @override
  Future<AiGatewayTokens> freshTokens({
    required AiProviderEgressGuard egressGuard,
  }) {
    calls += 1;
    if (!started.isCompleted) started.complete();
    return _tokens.future;
  }
}

class _RejectionAwareTokenProvider
    implements AiGatewayTokenProvider, AiGatewayAppCheckRejectionReporter {
  int tokenCalls = 0;
  int rejectionReports = 0;

  @override
  Future<AiGatewayTokens> freshTokens({
    required AiProviderEgressGuard egressGuard,
  }) async {
    tokenCalls += 1;
    return const AiGatewayTokens(
      firebaseIdToken: 'id-token-test',
      appCheckToken: 'app-check-test',
    );
  }

  @override
  void reportAppCheckRejected() {
    rejectionReports += 1;
  }
}

class _ChunkedClient extends http.BaseClient {
  _ChunkedClient({
    required this.chunks,
    this.statusCode = 200,
    this.headers = const <String, String>{
      'x-request-id': 'request_12345',
      'content-type': 'text/event-stream',
    },
  });

  final List<List<int>> chunks;
  final int statusCode;
  final Map<String, String> headers;
  int calls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls += 1;
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable(chunks),
      statusCode,
      request: request,
      headers: headers,
    );
  }
}
