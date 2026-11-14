import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/data_deletion_operation_context.dart';
import 'account_deletion_session_proof_store.dart';
import 'cloud_user_data_deletion_data_source.dart';

final class AccountDeletionReauthenticationRequiredException
    implements Exception {
  const AccountDeletionReauthenticationRequiredException();

  @override
  String toString() =>
      'Fresh authentication is required to continue account deletion.';
}

final class AccountAuthDeletionReceipt {
  const AccountAuthDeletionReceipt({
    required this.operationId,
    required this.authDeleted,
    required this.alreadyDeleted,
  });

  final String operationId;
  final bool authDeleted;
  final bool alreadyDeleted;
}

abstract interface class AccountAuthDeletionDataSource {
  Future<AccountAuthDeletionReceipt> deleteAuthAccount(
    DataDeletionOperationContext context, {
    bool finalizationRecovery = false,
  });
}

/// Deletes Firebase Auth through the trusted gateway. The immutable target is
/// an opaque owner-scope commitment; a Firebase UID is never accepted in the
/// request body. The server must recompute the commitment from the verified
/// bearer principal before performing any mutation.
final class HttpAccountAuthDeletionDataSource
    implements AccountAuthDeletionDataSource {
  const HttpAccountAuthDeletionDataSource({
    required AccountDeletionGatewayConfig config,
    required AccountDeletionGatewayTokenProvider tokenProvider,
    required http.Client httpClient,
  }) : _config = config,
       _tokenProvider = tokenProvider,
       _httpClient = httpClient;

  final AccountDeletionGatewayConfig _config;
  final AccountDeletionGatewayTokenProvider _tokenProvider;
  final http.Client _httpClient;

  @override
  Future<AccountAuthDeletionReceipt> deleteAuthAccount(
    DataDeletionOperationContext context, {
    bool finalizationRecovery = false,
  }) async {
    final tokens = finalizationRecovery
        ? await _tokenProvider.finalizationRecoveryTokens(context)
        : await _tokenProvider.freshTokens(context);
    final endpoint = _config.authDeletionEndpoint;
    final headers = <String, String>{
      if (tokens.authToken case final authToken?)
        'Authorization': 'Bearer $authToken',
      'X-Firebase-AppCheck': tokens.appCheckToken,
      accountDeletionSessionProofHeader:
          tokens.deletionSessionProof.headerValue,
      'X-Request-ID': context.operationId,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final body = jsonEncode(<String, String>{
      'operationId': context.operationId,
      'targetOwnerScope': context.identity.ownerScope.id.value,
    });
    late http.Response response;
    for (var attempt = 0; attempt < 2; attempt += 1) {
      if (tokens.authToken != null) {
        _tokenProvider.assertSessionCurrent(context);
      }
      try {
        response = await _httpClient
            .post(endpoint, headers: headers, body: body)
            .timeout(_config.timeout);
      } on Object {
        if (attempt == 0) {
          continue;
        }
        throw AccountDeletionGatewayFailure(
          failureCode: 'networkFailure',
          statusCode: 0,
          retryable: true,
        );
      }
      if (response.statusCode == 401 &&
          response.body.length <= 16 * 1024 &&
          _failureCode(response.body) == 'deletionReauthenticationRequired') {
        throw const AccountDeletionReauthenticationRequiredException();
      }
      if (response.statusCode == 200 && response.body.length <= 16 * 1024) {
        break;
      }
      if (attempt == 1) {
        throw accountDeletionGatewayFailureFromResponse(response);
      }
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Authentication deletion returned an invalid receipt.');
    }
    final operationId = decoded['operationId'];
    final status = decoded['status'];
    final authDeleted = decoded['authDeleted'];
    final alreadyDeleted = decoded['alreadyDeleted'];
    if (operationId != context.operationId ||
        status != 'completed' ||
        authDeleted != true ||
        alreadyDeleted is! bool) {
      throw StateError('Authentication deletion could not be verified.');
    }
    return AccountAuthDeletionReceipt(
      operationId: operationId as String,
      authDeleted: true,
      alreadyDeleted: alreadyDeleted,
    );
  }

  String? _failureCode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final failure = decoded['failure'];
      if (failure is! Map<String, dynamic>) {
        return null;
      }
      final code = failure['code'];
      return code is String ? code : null;
    } on Object {
      return null;
    }
  }
}
