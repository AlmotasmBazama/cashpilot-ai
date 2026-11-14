import 'dart:async';
import 'dart:convert';

import 'package:cashpilot_ai/features/data_deletion/application/account_deletion_startup_recovery_coordinator.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/account_deletion_session_proof_store.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/account_deletion_startup_recovery_gateway.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/cloud_user_data_deletion_data_source.dart';
import 'package:cashpilot_ai/features/data_deletion/domain/entities/data_deletion_operation_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'startup recovery sends AppCheck and proof with no Auth identity',
    () async {
      final requests = <http.Request>[];
      final gateway = HttpAccountDeletionStartupRecoveryGateway(
        config: _config,
        attestationProvider: const _AttestationProvider(),
        httpClient: MockClient((request) async {
          requests.add(request);
          if (requests.length == 1) {
            throw http.ClientException('synthetic response loss');
          }
          return http.Response(
            jsonEncode(<String, Object>{
              'operationId': _target.operationId,
              'status': 'completed',
              'authDeleted': true,
              'alreadyDeleted': true,
            }),
            200,
          );
        }),
      );

      final disposition = await gateway.confirmAlreadyDeleted(
        target: _target,
        proof: _proof,
      );

      expect(
        disposition,
        AccountDeletionStartupRecoveryDisposition.alreadyDeleted,
      );
      expect(requests, hasLength(2));
      for (final request in requests) {
        expect(_header(request, 'Authorization'), isNull);
        expect(_header(request, 'X-Firebase-AppCheck'), 'app-check-token');
        expect(
          _header(request, accountDeletionSessionProofHeader),
          _proof.headerValue,
        );
        expect(jsonDecode(request.body), <String, Object>{
          'operationId': _target.operationId,
          'targetOwnerScope': _target.ownerScopeValue,
        });
      }
      expect(requests[1].headers, requests[0].headers);
      expect(requests[1].body, requests[0].body);
    },
  );

  test('startup recovery requires an exact already-deleted receipt', () async {
    for (final response in <http.Response>[
      http.Response('{}', 200),
      http.Response(
        jsonEncode(<String, Object>{
          'operationId': _target.operationId,
          'status': 'completed',
          'authDeleted': true,
          'alreadyDeleted': false,
        }),
        200,
      ),
      http.Response(
        jsonEncode(<String, Object>{
          'operationId': _target.operationId,
          'status': 'completed',
          'authDeleted': true,
          'alreadyDeleted': true,
        }),
        401,
      ),
    ]) {
      final gateway = HttpAccountDeletionStartupRecoveryGateway(
        config: _config,
        attestationProvider: const _AttestationProvider(),
        httpClient: MockClient((_) async => response),
      );

      await expectLater(
        gateway.confirmAlreadyDeleted(target: _target, proof: _proof),
        throwsA(isA<AccountDeletionStartupRecoveryServerException>()),
      );
    }
  });

  test('startup recovery exception never contains the proof', () {
    const error = AccountDeletionStartupRecoveryServerException();
    expect(error.toString(), isNot(contains(_proof.headerValue)));
  });

  test('startup recovery preserves a safe typed provider failure', () async {
    final gateway = HttpAccountDeletionStartupRecoveryGateway(
      config: _config,
      attestationProvider: const _AttestationProvider(),
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode(<String, Object>{
            'failure': <String, Object>{
              'code': 'providerUnavailable',
              'message': 'must-not-cross-the-client-boundary',
            },
            'requestId': 'must-not-cross-the-client-boundary',
          }),
          503,
        ),
      ),
    );

    await expectLater(
      gateway.confirmAlreadyDeleted(target: _target, proof: _proof),
      throwsA(
        isA<AccountDeletionStartupRecoveryServerException>()
            .having(
              (failure) => failure.safeFailureCode,
              'safeFailureCode',
              'providerUnavailable',
            )
            .having((failure) => failure.statusCode, 'statusCode', 503)
            .having(
              (failure) => failure.toString(),
              'safe representation',
              isNot(contains('must-not-cross-the-client-boundary')),
            ),
      ),
    );
  });

  test('hung App Check attestation times out before any request', () async {
    var requests = 0;
    final gateway = HttpAccountDeletionStartupRecoveryGateway(
      config: AccountDeletionGatewayConfig(
        baseUri: _config.baseUri,
        timeout: const Duration(milliseconds: 10),
      ),
      attestationProvider: _PendingAttestationProvider(),
      httpClient: MockClient((_) async {
        requests += 1;
        return http.Response('{}', 500);
      }),
    );

    await expectLater(
      gateway.confirmAlreadyDeleted(target: _target, proof: _proof),
      throwsA(isA<AccountDeletionStartupRecoveryServerException>()),
    );
    expect(requests, 0);
  });

  test(
    'typed deletion-not-ready response requires authenticated continuation',
    () async {
      final gateway = HttpAccountDeletionStartupRecoveryGateway(
        config: _config,
        attestationProvider: const _AttestationProvider(),
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode(<String, Object>{
              'failure': <String, Object>{
                'code': 'deletionNotReady',
                'message': 'safe server message',
              },
            }),
            409,
          ),
        ),
      );

      final disposition = await gateway.confirmAlreadyDeleted(
        target: _target,
        proof: _proof,
      );

      expect(
        disposition,
        AccountDeletionStartupRecoveryDisposition
            .authenticatedContinuationRequired,
      );
    },
  );
}

final _config = AccountDeletionGatewayConfig(
  baseUri: Uri.parse('https://gateway.example.test'),
);
final _target = AccountDeletionRecoveryTarget(
  operationId: '01900000-0000-7000-8000-000000000111',
  ownerScopeValue:
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
);
final _proof = AccountDeletionSessionProof.parse(
  'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
);

final class _AttestationProvider
    implements AccountDeletionRecoveryAttestationProvider {
  const _AttestationProvider();

  @override
  Future<String> freshAppCheckToken() async => 'app-check-token';
}

final class _PendingAttestationProvider
    implements AccountDeletionRecoveryAttestationProvider {
  final _pending = Completer<String>();

  @override
  Future<String> freshAppCheckToken() => _pending.future;
}

String? _header(http.Request request, String name) {
  final normalized = name.toLowerCase();
  for (final entry in request.headers.entries) {
    if (entry.key.toLowerCase() == normalized) {
      return entry.value;
    }
  }
  return null;
}
