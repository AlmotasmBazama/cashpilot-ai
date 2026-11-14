import 'dart:convert';

import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/account_auth_deletion_data_source.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/account_deletion_session_proof_store.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/cloud_user_data_deletion_data_source.dart';
import 'package:cashpilot_ai/features/data_deletion/domain/entities/data_deletion_operation_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const proofValue = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

  test(
    'recursive deletion retries once with the exact same secret proof',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (requests.length == 1) {
          throw http.ClientException('synthetic response loss');
        }
        return http.Response(
          jsonEncode(<String, Object>{
            'operationId': _operationId,
            'status': 'completed',
            'verifiedEmpty': true,
            'deletedDocuments': 7,
          }),
          200,
        );
      });
      final proofStore = _ProofStore(proofValue);
      final source = HttpRecursiveCloudUserDataDeletionDataSource(
        config: _config,
        tokenProvider: _TokenProvider(proofStore),
        httpClient: client,
      );

      final receipt = await source.deleteUserData(_context);

      expect(receipt.deletedDocuments, 7);
      expect(requests, hasLength(2));
      expect(proofStore.required, 1);
      expect(
        _header(requests[0], accountDeletionSessionProofHeader),
        proofValue,
      );
      expect(requests[1].headers, requests[0].headers);
      expect(requests[1].body, requests[0].body);
      expect(_decodedBody(requests[0]), <String, Object>{
        'operationId': _operationId,
        'targetOwnerScope': _context.identity.ownerScope.id.value,
      });
    },
  );

  test(
    'recursive and Auth-last requests reuse the same operation proof',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/recursive')) {
          return http.Response(
            jsonEncode(<String, Object>{
              'operationId': _operationId,
              'status': 'completed',
              'verifiedEmpty': true,
              'deletedDocuments': 0,
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode(<String, Object>{
            'operationId': _operationId,
            'status': 'completed',
            'authDeleted': true,
            'alreadyDeleted': false,
          }),
          200,
        );
      });
      final proofStore = _ProofStore(proofValue);
      final tokens = _TokenProvider(proofStore);
      final recursive = HttpRecursiveCloudUserDataDeletionDataSource(
        config: _config,
        tokenProvider: tokens,
        httpClient: client,
      );
      final auth = HttpAccountAuthDeletionDataSource(
        config: _config,
        tokenProvider: tokens,
        httpClient: client,
      );

      await recursive.deleteUserData(_context);
      await auth.deleteAuthAccount(_preferencesDeletedContext);

      expect(requests, hasLength(2));
      expect(
        requests.map(
          (request) => _header(request, accountDeletionSessionProofHeader),
        ),
        everyElement(proofValue),
      );
      expect(proofStore.required, 2);
    },
  );

  test('missing secure proof fails before a remote request', () async {
    var requests = 0;
    final source = HttpRecursiveCloudUserDataDeletionDataSource(
      config: _config,
      tokenProvider: _TokenProvider(_ProofStore.missing()),
      httpClient: MockClient((_) async {
        requests += 1;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      source.deleteUserData(_context),
      throwsA(isA<AccountDeletionSessionProofUnavailableException>()),
    );
    expect(requests, 0);
  });

  test('recursive deletion preserves a safe typed gateway failure', () async {
    final source = HttpRecursiveCloudUserDataDeletionDataSource(
      config: _config,
      tokenProvider: _TokenProvider(_ProofStore(proofValue)),
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode(<String, Object>{
            'failure': <String, Object>{
              'code': 'gatewayRequestInvalid',
              'message': 'The requested gateway route does not exist.',
            },
            'requestId': 'must-not-cross-the-client-boundary',
          }),
          404,
        ),
      ),
    );

    await expectLater(
      source.deleteUserData(_context),
      throwsA(
        isA<AccountDeletionGatewayFailure>()
            .having(
              (failure) => failure.failureCode,
              'failureCode',
              'gatewayRequestInvalid',
            )
            .having((failure) => failure.statusCode, 'statusCode', 404)
            .having((failure) => failure.retryable, 'retryable', isFalse)
            .having(
              (failure) => failure.toString(),
              'safe representation',
              isNot(contains('must-not-cross-the-client-boundary')),
            ),
      ),
    );
  });

  test(
    'Auth-last recovery can attest without an obsolete Auth token',
    () async {
      late http.Request captured;
      final proofStore = _ProofStore(proofValue);
      final tokens = _TokenProvider(proofStore, authToken: null);
      final source = HttpAccountAuthDeletionDataSource(
        config: _config,
        tokenProvider: tokens,
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode(<String, Object>{
              'operationId': _operationId,
              'status': 'completed',
              'authDeleted': true,
              'alreadyDeleted': true,
            }),
            200,
          );
        }),
      );

      final receipt = await source.deleteAuthAccount(
        _preferencesDeletedContext,
        finalizationRecovery: true,
      );

      expect(receipt.alreadyDeleted, isTrue);
      expect(_header(captured, 'Authorization'), isNull);
      expect(_header(captured, 'X-Firebase-AppCheck'), 'app-check-token');
      expect(_header(captured, accountDeletionSessionProofHeader), proofValue);
      expect(tokens.sessionAssertions, 0);
    },
  );

  test(
    'only the typed continuation response requests reauthentication',
    () async {
      var requests = 0;
      final source = HttpAccountAuthDeletionDataSource(
        config: _config,
        tokenProvider: _TokenProvider(_ProofStore(proofValue)),
        httpClient: MockClient((request) async {
          requests += 1;
          return http.Response(
            jsonEncode(<String, Object>{
              'failure': <String, Object>{
                'code': 'deletionReauthenticationRequired',
                'message':
                    'Fresh authentication is required to continue account deletion.',
              },
              'requestId': 'synthetic-request-id',
            }),
            401,
          );
        }),
      );

      await expectLater(
        source.deleteAuthAccount(
          _preferencesDeletedContext,
          finalizationRecovery: true,
        ),
        throwsA(isA<AccountDeletionReauthenticationRequiredException>()),
      );
      expect(requests, 1);
    },
  );
}

final _config = AccountDeletionGatewayConfig(
  baseUri: Uri.parse('https://gateway.example.test'),
);
const _operationId = '01900000-0000-7000-8000-000000000099';

final _context = DataDeletionOperationContext.captured(
  operationId: _operationId,
  identity: TrustedDeletionIdentity(
    authSessionId: 'auth-session',
    authStateGeneration: 1,
    userId: 'owner-a',
    isAnonymous: false,
    ownerScope: OwnerScopeDerivation.fromConfirmedFirebaseUid('owner-a'),
  ),
  startedAtUtc: DateTime.utc(2026),
);

final _preferencesDeletedContext = _advanceTo(
  _context,
  DataDeletionStage.preferencesDeleted,
);

DataDeletionOperationContext _advanceTo(
  DataDeletionOperationContext context,
  DataDeletionStage target,
) {
  var current = context;
  for (final stage in DataDeletionStage.values.skip(1)) {
    current = current.advance(stage);
    if (stage == target) {
      return current;
    }
  }
  throw StateError('Unreachable test stage.');
}

Map<String, dynamic> _decodedBody(http.Request request) =>
    jsonDecode(request.body) as Map<String, dynamic>;

String? _header(http.Request request, String name) {
  final normalized = name.toLowerCase();
  for (final entry in request.headers.entries) {
    if (entry.key.toLowerCase() == normalized) {
      return entry.value;
    }
  }
  return null;
}

final class _ProofStore implements AccountDeletionSessionProofStore {
  _ProofStore(String value) : _proof = AccountDeletionSessionProof.parse(value);

  _ProofStore.missing() : _proof = null;

  final AccountDeletionSessionProof? _proof;
  int required = 0;

  @override
  Future<void> clear(DataDeletionOperationContext context) async {}

  @override
  Future<void> clearRecovery(AccountDeletionRecoveryTarget target) async {}

  @override
  Future<AccountDeletionSessionProof> createAfterReauthentication(
    DataDeletionOperationContext context,
  ) async => _require();

  @override
  Future<AccountDeletionSessionProof> requireExisting(
    DataDeletionOperationContext context,
  ) async {
    required += 1;
    return _require();
  }

  @override
  Future<AccountDeletionSessionProof> requireExistingForRecovery(
    AccountDeletionRecoveryTarget target,
  ) async {
    required += 1;
    return _require();
  }

  @override
  Future<void> markAbandonedBeforeRemote(
    DataDeletionOperationContext context,
  ) async {}

  @override
  Future<void> markServerConfirmed(
    DataDeletionOperationContext context,
  ) async {}

  @override
  Future<void> markServerConfirmedForRecovery(
    AccountDeletionRecoveryTarget target,
  ) async {}

  @override
  Future<AccountDeletionSecureOperationStatus> recoveryStatus(
    AccountDeletionRecoveryTarget target,
  ) async => AccountDeletionSecureOperationStatus.active;

  @override
  Future<List<AccountDeletionRecoveryTarget>> recoveryTargets() async =>
      const <AccountDeletionRecoveryTarget>[];

  AccountDeletionSessionProof _require() {
    final proof = _proof;
    if (proof == null) {
      throw const AccountDeletionSessionProofUnavailableException();
    }
    return proof;
  }
}

final class _TokenProvider implements AccountDeletionGatewayTokenProvider {
  _TokenProvider(this._proofStore, {this.authToken = 'auth-token'});

  final AccountDeletionSessionProofStore _proofStore;
  final String? authToken;
  int sessionAssertions = 0;

  @override
  void assertSessionCurrent(DataDeletionOperationContext context) {
    sessionAssertions += 1;
  }

  @override
  Future<AccountDeletionGatewayTokens> finalizationRecoveryTokens(
    DataDeletionOperationContext context,
  ) async => AccountDeletionGatewayTokens(
    authToken: authToken,
    appCheckToken: 'app-check-token',
    deletionSessionProof: await _proofStore.requireExisting(context),
  );

  @override
  Future<AccountDeletionGatewayTokens> freshTokens(
    DataDeletionOperationContext context,
  ) async => AccountDeletionGatewayTokens(
    authToken: authToken,
    appCheckToken: 'app-check-token',
    deletionSessionProof: await _proofStore.requireExisting(context),
  );
}
