import 'dart:async';
import 'dart:convert';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'account_deletion_auth_data_source.dart';
import 'account_deletion_session_proof_store.dart';
import '../../domain/entities/data_deletion_operation_context.dart';

final class CloudDeletionReceipt {
  const CloudDeletionReceipt({
    required this.operationId,
    required this.deletedDocuments,
    required this.verifiedEmpty,
  });

  final String operationId;
  final int deletedDocuments;
  final bool verifiedEmpty;
}

/// Privacy-safe, typed transport failure returned by the trusted deletion
/// gateway. Server messages and request identifiers are intentionally not
/// retained; only an allowlisted closed code and HTTP status cross this
/// boundary.
final class AccountDeletionGatewayFailure extends StateError {
  AccountDeletionGatewayFailure({
    required this.failureCode,
    required this.statusCode,
    required this.retryable,
  }) : super('Account deletion gateway request failed ($failureCode).');

  final String failureCode;
  final int statusCode;
  final bool retryable;
}

abstract interface class CloudUserDataDeletionDataSource {
  Future<CloudDeletionReceipt> deleteUserData(
    DataDeletionOperationContext context,
  );
}

final class AccountDeletionGatewayConfig {
  const AccountDeletionGatewayConfig({
    required this.baseUri,
    this.timeout = const Duration(seconds: 30),
  });

  factory AccountDeletionGatewayConfig.current() {
    const dedicated = String.fromEnvironment(
      'CASH_PILOT_ACCOUNT_DELETION_GATEWAY_BASE_URL',
    );
    return AccountDeletionGatewayConfig(
      baseUri: dedicated.trim().isEmpty ? Uri() : Uri.parse(dedicated),
    );
  }

  final Uri baseUri;
  final Duration timeout;

  Uri get recursiveDeletionEndpoint {
    final debugLoopback =
        kDebugMode &&
        baseUri.scheme == 'http' &&
        const {'localhost', '127.0.0.1', '::1'}.contains(baseUri.host);
    if (!baseUri.hasScheme ||
        (baseUri.scheme != 'https' && !debugLoopback) ||
        baseUri.host.isEmpty) {
      throw StateError('The account-deletion gateway is not configured.');
    }
    return baseUri.resolve('/v1/account-deletion/recursive');
  }

  Uri get authDeletionEndpoint {
    recursiveDeletionEndpoint;
    return baseUri.resolve('/v1/account-deletion/auth');
  }
}

final class AccountDeletionGatewayTokens {
  const AccountDeletionGatewayTokens({
    required this.authToken,
    required this.appCheckToken,
    required this.deletionSessionProof,
  });

  /// Null is permitted only for the Auth-last, read-only recovery path after
  /// Firebase Auth has already removed the user.
  final String? authToken;
  final String appCheckToken;
  final AccountDeletionSessionProof deletionSessionProof;
}

abstract interface class AccountDeletionGatewayTokenProvider {
  Future<AccountDeletionGatewayTokens> freshTokens(
    DataDeletionOperationContext context,
  );

  Future<AccountDeletionGatewayTokens> finalizationRecoveryTokens(
    DataDeletionOperationContext context,
  );

  /// Must synchronously reject a stale captured Auth session. The HTTP data
  /// source invokes this with no asynchronous gap before dispatch.
  void assertSessionCurrent(DataDeletionOperationContext context);
}

final class FirebaseAccountDeletionGatewayTokenProvider
    implements AccountDeletionGatewayTokenProvider {
  const FirebaseAccountDeletionGatewayTokenProvider({
    required AccountDeletionAuthDataSource authDataSource,
    required FirebaseAppCheck appCheck,
    required AccountDeletionSessionProofStore sessionProofStore,
  }) : _authDataSource = authDataSource,
       _appCheck = appCheck,
       _sessionProofStore = sessionProofStore;

  final AccountDeletionAuthDataSource _authDataSource;
  final FirebaseAppCheck _appCheck;
  final AccountDeletionSessionProofStore _sessionProofStore;

  @override
  Future<AccountDeletionGatewayTokens> freshTokens(
    DataDeletionOperationContext context,
  ) async {
    final deletionSessionProof = await _sessionProofStore.requireExisting(
      context,
    );
    final authToken = await _authDataSource.freshIdToken(context);
    _authDataSource.assertSessionCurrent(context);
    final appCheckToken = await _appCheck.getToken(true);
    _authDataSource.assertSessionCurrent(context);
    if (authToken.trim().isEmpty ||
        appCheckToken == null ||
        appCheckToken.trim().isEmpty) {
      throw StateError('Fresh deletion authorization is unavailable.');
    }
    return AccountDeletionGatewayTokens(
      authToken: authToken,
      appCheckToken: appCheckToken,
      deletionSessionProof: deletionSessionProof,
    );
  }

  @override
  Future<AccountDeletionGatewayTokens> finalizationRecoveryTokens(
    DataDeletionOperationContext context,
  ) async {
    if (context.stage != DataDeletionStage.preferencesDeleted) {
      throw StateError(
        'Attestation recovery is available only after local deletion.',
      );
    }
    final deletionSessionProof = await _sessionProofStore.requireExisting(
      context,
    );
    String? authToken;
    try {
      final candidate = await _authDataSource.cachedIdTokenForFinalization(
        context,
      );
      _authDataSource.assertSessionCurrent(context);
      if (candidate.trim().isNotEmpty) {
        authToken = candidate;
      }
    } on Object {
      // After an Auth-last response is lost, Firebase may already have removed
      // the user and invalidated every cached token. The server's App Check +
      // proof path is read-only and refuses to delete an existing Auth user.
      authToken = null;
    }
    final appCheckToken = await _appCheck.getToken(true);
    if (authToken != null) {
      _authDataSource.assertSessionCurrent(context);
    }
    if (appCheckToken == null || appCheckToken.trim().isEmpty) {
      throw StateError('Deletion recovery attestation is unavailable.');
    }
    return AccountDeletionGatewayTokens(
      authToken: authToken,
      appCheckToken: appCheckToken,
      deletionSessionProof: deletionSessionProof,
    );
  }

  @override
  void assertSessionCurrent(DataDeletionOperationContext context) =>
      _authDataSource.assertSessionCurrent(context);
}

/// Calls the trusted server recursive-delete endpoint and fails closed unless
/// the server proves the whole user document tree is empty.
final class HttpRecursiveCloudUserDataDeletionDataSource
    implements CloudUserDataDeletionDataSource {
  const HttpRecursiveCloudUserDataDeletionDataSource({
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
  Future<CloudDeletionReceipt> deleteUserData(
    DataDeletionOperationContext context,
  ) async {
    final tokens = await _tokenProvider.freshTokens(context);
    final authToken = tokens.authToken;
    if (authToken == null || authToken.trim().isEmpty) {
      throw StateError('Fresh deletion authorization is unavailable.');
    }
    final endpoint = _config.recursiveDeletionEndpoint;
    final headers = <String, String>{
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
      _tokenProvider.assertSessionCurrent(context);
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
      if (response.statusCode != 200 || response.body.length > 16 * 1024) {
        throw accountDeletionGatewayFailureFromResponse(response);
      }
      break;
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Recursive deletion returned an invalid receipt.');
    }
    final operationId = decoded['operationId'];
    final status = decoded['status'];
    final verifiedEmpty = decoded['verifiedEmpty'];
    final deletedDocuments = decoded['deletedDocuments'];
    if (operationId != context.operationId ||
        status != 'completed' ||
        verifiedEmpty != true ||
        deletedDocuments is! int ||
        deletedDocuments < 0) {
      throw StateError('Recursive cloud deletion could not be verified.');
    }
    return CloudDeletionReceipt(
      operationId: operationId as String,
      deletedDocuments: deletedDocuments,
      verifiedEmpty: true,
    );
  }
}

AccountDeletionGatewayFailure accountDeletionGatewayFailureFromResponse(
  http.Response response,
) {
  var failureCode = response.body.length > 16 * 1024
      ? 'invalidResponse'
      : 'unknownTemporaryFailure';
  if (response.body.length <= 16 * 1024) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final failure = decoded['failure'];
        if (failure is Map<String, dynamic>) {
          final candidate = failure['code'];
          if (candidate is String &&
              _accountDeletionGatewayFailureCodes.contains(candidate)) {
            failureCode = candidate;
          }
        }
      }
    } on Object {
      failureCode = 'invalidResponse';
    }
  }
  final retryable =
      response.statusCode == 429 ||
      response.statusCode >= 500 ||
      const <String>{
        'rateLimited',
        'providerUnavailable',
        'timeout',
        'cloudDeleteTimedOut',
        'cloudDeletePartial',
        'cloudVerificationFailed',
        'networkFailure',
        'unknownTemporaryFailure',
      }.contains(failureCode);
  return AccountDeletionGatewayFailure(
    failureCode: failureCode,
    statusCode: response.statusCode,
    retryable: retryable,
  );
}

const _accountDeletionGatewayFailureCodes = <String>{
  'unauthenticated',
  'authenticationRequired',
  'deletionReauthenticationRequired',
  'appCheckRejected',
  'appCheckUnavailable',
  'deletionProofInvalid',
  'permissionDenied',
  'rateLimited',
  'providerUnavailable',
  'timeout',
  'cloudDeleteTimedOut',
  'cloudDeletePartial',
  'cloudVerificationFailed',
  'invalidResponse',
  'networkFailure',
  'configurationFailure',
  'operationConflict',
  'deletionNotReady',
  'gatewayRequestInvalid',
  'unknownTemporaryFailure',
};
