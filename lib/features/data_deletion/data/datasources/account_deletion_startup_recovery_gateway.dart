import 'dart:convert';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:http/http.dart' as http;

import '../../application/account_deletion_startup_recovery_coordinator.dart';
import '../../domain/entities/data_deletion_operation_context.dart';
import 'account_deletion_session_proof_store.dart';
import 'cloud_user_data_deletion_data_source.dart';

abstract interface class AccountDeletionRecoveryAttestationProvider {
  Future<String> freshAppCheckToken();
}

final class FirebaseAccountDeletionRecoveryAttestationProvider
    implements AccountDeletionRecoveryAttestationProvider {
  const FirebaseAccountDeletionRecoveryAttestationProvider(
    FirebaseAppCheck appCheck,
  ) : _appCheck = appCheck;

  final FirebaseAppCheck _appCheck;

  @override
  Future<String> freshAppCheckToken() async {
    final token = await _appCheck.getToken(true);
    if (token == null || token.trim().isEmpty) {
      throw const AccountDeletionStartupRecoveryServerException(
        safeFailureCode: 'appCheckUnavailable',
      );
    }
    return token;
  }
}

final class AccountDeletionStartupRecoveryServerException
    implements Exception, AccountDeletionStartupRecoveryFailure {
  const AccountDeletionStartupRecoveryServerException({
    this.safeFailureCode = 'unknownTemporaryFailure',
    this.statusCode,
  });

  @override
  final String safeFailureCode;
  final int? statusCode;

  @override
  String toString() =>
      'Account deletion recovery could not be confirmed '
      '(code=$safeFailureCode, status=${statusCode ?? 0}).';
}

/// AppCheck + proof-only client for the server's read-only Auth recovery path.
/// An Authorization header is intentionally impossible to supply.
final class HttpAccountDeletionStartupRecoveryGateway
    implements AccountDeletionStartupRecoveryGateway {
  const HttpAccountDeletionStartupRecoveryGateway({
    required AccountDeletionGatewayConfig config,
    required AccountDeletionRecoveryAttestationProvider attestationProvider,
    required http.Client httpClient,
  }) : _config = config,
       _attestationProvider = attestationProvider,
       _httpClient = httpClient;

  final AccountDeletionGatewayConfig _config;
  final AccountDeletionRecoveryAttestationProvider _attestationProvider;
  final http.Client _httpClient;

  @override
  Future<AccountDeletionStartupRecoveryDisposition> confirmAlreadyDeleted({
    required AccountDeletionRecoveryTarget target,
    required AccountDeletionSessionProof proof,
  }) async {
    late final String appCheckToken;
    try {
      appCheckToken = (await _attestationProvider.freshAppCheckToken().timeout(
        _config.timeout,
      )).trim();
    } on Object {
      throw const AccountDeletionStartupRecoveryServerException(
        safeFailureCode: 'appCheckUnavailable',
      );
    }
    if (appCheckToken.isEmpty) {
      throw const AccountDeletionStartupRecoveryServerException(
        safeFailureCode: 'appCheckUnavailable',
      );
    }
    final headers = <String, String>{
      'X-Firebase-AppCheck': appCheckToken,
      accountDeletionSessionProofHeader: proof.headerValue,
      'X-Request-ID': target.operationId,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final body = jsonEncode(<String, String>{
      'operationId': target.operationId,
      'targetOwnerScope': target.ownerScopeValue,
    });
    late http.Response response;
    try {
      for (var attempt = 0; attempt < 2; attempt += 1) {
        try {
          response = await _httpClient
              .post(_config.authDeletionEndpoint, headers: headers, body: body)
              .timeout(_config.timeout);
          break;
        } on Object {
          if (attempt == 1) {
            rethrow;
          }
        }
      }
    } on Object {
      throw const AccountDeletionStartupRecoveryServerException(
        safeFailureCode: 'networkFailure',
      );
    }
    if (response.body.length > 16 * 1024) {
      throw const AccountDeletionStartupRecoveryServerException(
        safeFailureCode: 'invalidResponse',
      );
    }
    if (_requiresAuthenticatedContinuation(response)) {
      return AccountDeletionStartupRecoveryDisposition
          .authenticatedContinuationRequired;
    }
    if (response.statusCode != 200) {
      final failure = accountDeletionGatewayFailureFromResponse(response);
      throw AccountDeletionStartupRecoveryServerException(
        safeFailureCode: failure.failureCode,
        statusCode: failure.statusCode,
      );
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> ||
          decoded.length != 4 ||
          decoded['operationId'] != target.operationId ||
          decoded['status'] != 'completed' ||
          decoded['authDeleted'] != true ||
          decoded['alreadyDeleted'] != true) {
        throw const AccountDeletionStartupRecoveryServerException(
          safeFailureCode: 'invalidResponse',
        );
      }
      return AccountDeletionStartupRecoveryDisposition.alreadyDeleted;
    } on AccountDeletionStartupRecoveryServerException {
      rethrow;
    } on Object {
      throw const AccountDeletionStartupRecoveryServerException(
        safeFailureCode: 'invalidResponse',
      );
    }
  }

  bool _requiresAuthenticatedContinuation(http.Response response) {
    if (response.statusCode != 409 && response.statusCode != 401) {
      return false;
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return false;
      }
      final failure = decoded['failure'];
      if (failure is! Map<String, dynamic>) {
        return false;
      }
      final code = failure['code'];
      return code == 'deletionNotReady' ||
          code == 'deletionReauthenticationRequired';
    } on Object {
      return false;
    }
  }
}
