import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/features/data_deletion/application/account_deletion_authenticated_continuation.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/account_deletion_auth_data_source.dart';
import 'package:cashpilot_ai/features/data_deletion/domain/entities/data_deletion_operation_context.dart';
import 'package:cashpilot_ai/features/data_deletion/domain/entities/data_deletion_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'matching A authorization resumes only the exact recovery target',
    () async {
      final auth = _ContinuationAuthDataSource(
        _lease(_targetA.ownerScopeValue),
      );
      DataDeletionRequest? capturedRequest;
      final continuation = AccountDeletionAuthenticatedContinuation(
        authDataSource: auth,
        deleteAll: (request) async {
          capturedRequest = request;
          return AppResult<DataDeletionReport>.success(
            DataDeletionReport(
              cloudDocumentsDeleted: 1,
              localRowsDeleted: 2,
              completionProof: DataDeletionCompletionProof(
                operationId: _targetA.operationId,
                targetOwnerScopeValue: _targetA.ownerScopeValue,
                authStateGeneration: 9,
                authDeletionCompleted: true,
              ),
            ),
          );
        },
      );

      final authorization = await continuation.authorize(
        <AccountDeletionRecoveryTarget>[_targetA],
      );
      final result = await continuation.complete(
        authorization!,
        email: 'owner@example.test',
        password: 'not-a-real-secret',
      );

      expect(result, isA<AppSuccess<DataDeletionReport>>());
      expect(
        capturedRequest?.expectedRecoveryTarget?.operationId,
        _targetA.operationId,
      );
      expect(
        capturedRequest?.expectedRecoveryTarget?.ownerScopeValue,
        _targetA.ownerScopeValue,
      );
      expect(capturedRequest?.confirmationLease.authSessionGeneration, 9);
    },
  );

  test('B cannot authorize, read, or invoke A continuation', () async {
    final auth = _ContinuationAuthDataSource(_lease(_targetB.ownerScopeValue));
    var deletionCalls = 0;
    final continuation = AccountDeletionAuthenticatedContinuation(
      authDataSource: auth,
      deleteAll: (_) async {
        deletionCalls += 1;
        throw StateError('B must never reach deletion');
      },
    );

    final authorization = await continuation.authorize(
      <AccountDeletionRecoveryTarget>[_targetA],
    );

    expect(authorization, isNull);
    expect(auth.releaseCalls, 1);
    expect(deletionCalls, 0);
  });
}

final _targetA = AccountDeletionRecoveryTarget(
  operationId: '01900000-0000-7000-8000-000000000111',
  ownerScopeValue:
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
);
final _targetB = AccountDeletionRecoveryTarget(
  operationId: '01900000-0000-7000-8000-000000000222',
  ownerScopeValue:
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
);

AccountDeletionConfirmationLease _lease(String ownerScopeValue) =>
    AccountDeletionConfirmationLease(
      opaqueToken: 'opaque-test-lease',
      isAnonymous: false,
      email: 'owner@example.test',
      ownerScopeValue: ownerScopeValue,
      authSessionGeneration: 9,
    );

final class _ContinuationAuthDataSource
    implements AccountDeletionAuthDataSource {
  _ContinuationAuthDataSource(this.lease);

  final AccountDeletionConfirmationLease lease;
  var releaseCalls = 0;

  @override
  Future<AccountDeletionConfirmationLease> issueConfirmationLease() async =>
      lease;

  @override
  void releaseConfirmationLease(AccountDeletionConfirmationLease lease) {
    releaseCalls += 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
