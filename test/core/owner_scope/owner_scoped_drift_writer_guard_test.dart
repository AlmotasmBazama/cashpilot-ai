import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy claim cannot assign every legacy sync row to active owner', () {
    final source = File(
      'lib/core/owner_scope/application/legacy_data_claim_service.dart',
    ).readAsStringSync();

    expect(
      source,
      isNot(
        matches(
          RegExp(
            r'UPDATE\s+sync_queue\s+SET\s+owner_scope_id\s*=\s*\?\s+'
            r'WHERE\s+owner_scope_id\s+IS\s+NULL',
            caseSensitive: false,
            multiLine: true,
          ),
        ),
      ),
    );
    expect(source, isNot(matches(RegExp(r'''["']sync_queue["']\s*:'''))));
  });

  test('financial database capabilities have only authoritative callers', () {
    expect(_productionFilesContaining('.updateAccountBalanceProjection('), {
      'lib/features/transactions/data/adapters/'
          'drift_account_balance_repository.dart',
    });
    expect(_productionFilesContaining('.deleteAccountsForOwnerDataDeletion('), {
      'lib/features/data_deletion/data/datasources/'
          'account_deletion_scope_recovery_finalizer.dart',
      'lib/features/data_deletion/data/datasources/'
          'local_user_data_deletion_data_source.dart',
    });
  });

  test('all production owner-scoped Drift writer files are declared', () {
    final discovered = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) {
          final source = file.readAsStringSync();
          return source.contains('ScopedAppDatabaseSession') &&
              (_driftMutation.hasMatch(source) ||
                  _sessionTransaction.hasMatch(source));
        })
        .map((file) => file.path.replaceAll('\\', '/'))
        .toSet();

    // Detach is a terminal-state cleanup after the old session is revoked. It
    // only cancels/deletes durable AI state and cannot recreate owner data.
    discovered.remove(
      'lib/core/owner_scope/application/owner_scope_providers.dart',
    );
    final detachSource = File(
      'lib/core/owner_scope/application/owner_scope_providers.dart',
    ).readAsStringSync();
    expect(detachSource, contains('fenceAndDrainForOwnerTransition'));

    expect(discovered, equals(_guardedBoundaries.keys.toSet()));
  });

  test(
    'every declared production mutation boundary acquires a writer guard',
    () {
      for (final entry in _guardedBoundaries.entries) {
        final source = File(entry.key).readAsStringSync();
        for (final boundary in entry.value.entries) {
          final bodies = _declaredMethodBodies(source, boundary.key);
          expect(
            bodies,
            hasLength(boundary.value),
            reason: '${entry.key}:${boundary.key} declaration count changed.',
          );
          for (final body in bodies) {
            expect(
              body.contains('runGuardedWrite') ||
                  body.contains('runInTransaction'),
              isTrue,
              reason:
                  '${entry.key}:${boundary.key} can mutate owner data '
                  'without a BackupOperationFence writer lease.',
            );
          }
        }
      }
    },
  );
}

final RegExp _driftMutation = RegExp(
  r'_database\s*\.\s*(?:transaction|batch|into|customUpdate|update|delete|updateAccountBalanceProjection)\s*\(',
  multiLine: true,
);
final RegExp _sessionTransaction = RegExp(
  r'_session\s*\.\s*database\s*\.\s*transaction\s*\(',
  multiLine: true,
);

const Map<String, Map<String, int>> _guardedBoundaries = {
  'lib/core/owner_scope/application/legacy_data_claim_service.dart': {
    'claim': 1,
  },
  'lib/core/sync/data/sync_queue_repository.dart': {
    'enqueue': 1,
    'reconcileDirtyState': 1,
    'purgeAll': 1,
    'markAttempt': 1,
    'markCompleted': 1,
    'markFailed': 1,
    'retryFailed': 1,
  },
  'lib/features/accounts/data/datasources/local/accounts_local_data_source.dart':
      {
        'createAccount': 1,
        'deleteAccount': 1,
        'updateAccount': 1,
        'runInTransaction': 1,
      },
  'lib/features/ai_assistant/data/app_agent/drift_app_agent_stores.dart': {
    'saveCommand': 1,
    'saveTrustedLocalCommand': 1,
    'savePreview': 1,
    'transition': 1,
    'clearScope': 3,
    'saveProof': 1,
    'consumeProof': 1,
    'append': 1,
    'claim': 1,
    'complete': 1,
    'acknowledgeUiDelivery': 1,
    'persistReconciliation': 1,
  },
  'lib/features/budgets/data/datasources/local/budgets_local_data_source.dart':
      {'createBudget': 1, 'updateBudget': 1},
  'lib/features/categories/data/datasources/local/categories_local_data_source.dart':
      {
        'createCategory': 1,
        'deleteCategory': 1,
        'updateCategory': 1,
        '_seedDefaultCategoriesIfNeeded': 1,
      },
  'lib/features/exchange_rates/data/datasources/local/exchange_rates_local_data_source.dart':
      {'runInTransaction': 1, 'createRate': 1, 'updateRate': 1},
  'lib/features/goals/data/datasources/local/goals_local_data_source.dart': {
    'createGoal': 1,
    'updateGoal': 1,
    'addContribution': 1,
    'reverseContribution': 1,
  },
  'lib/features/payees/data/datasources/local/payees_local_data_source.dart': {
    'runInTransaction': 1,
    'createPayee': 1,
    'updatePayee': 1,
  },
  'lib/features/receipts/data/repositories/receipt_repository_impl.dart': {
    'createAnalysisDraft': 1,
    'updateAnalysisDraft': 1,
    'deleteDraft': 1,
    'saveLineItems': 1,
    'saveSplits': 1,
    'storeLocalImage': 1,
    'deleteLocalImage': 1,
    'reserveTransactionId': 1,
    'finalizeReceiptTransaction': 1,
  },
  'lib/features/transactions/data/adapters/drift_account_balance_repository.dart':
      {'save': 1},
  'lib/features/transactions/data/adapters/drift_finance_transaction_manager.dart':
      {'runInTransaction': 1},
  'lib/features/transactions/data/datasources/local/transactions_local_data_source.dart':
      {
        'createTransaction': 1,
        'deleteTransaction': 1,
        'runInTransaction': 1,
        'updateTransaction': 1,
      },
};

Set<String> _productionFilesContaining(String token) {
  return Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .where((file) => file.readAsStringSync().contains(token))
      .map((file) => file.path.replaceAll('\\', '/'))
      .where((path) => path != 'lib/core/database/app_database.dart')
      .toSet();
}

List<String> _declaredMethodBodies(String source, String methodName) {
  final declarations = <String>[];
  final namePattern = RegExp(
    '\\b${RegExp.escape(methodName)}(?:<[^>{}()]+>)?\\s*\\(',
  );
  for (final match in namePattern.allMatches(source)) {
    final openParenthesis = source.indexOf('(', match.start);
    final closeParenthesis = _matchingDelimiter(
      source,
      openParenthesis,
      '(',
      ')',
    );
    if (closeParenthesis == -1) continue;

    var cursor = _skipWhitespace(source, closeParenthesis + 1);
    if (source.startsWith('async', cursor)) {
      cursor = _skipWhitespace(source, cursor + 'async'.length);
    }
    if (source.startsWith('=>', cursor)) {
      final end = source.indexOf(';', cursor + 2);
      if (end != -1) declarations.add(source.substring(match.start, end + 1));
      continue;
    }
    if (cursor >= source.length || source[cursor] != '{') continue;
    final closeBrace = _matchingDelimiter(source, cursor, '{', '}');
    if (closeBrace != -1) {
      declarations.add(source.substring(match.start, closeBrace + 1));
    }
  }
  return declarations;
}

int _skipWhitespace(String source, int start) {
  var cursor = start;
  while (cursor < source.length &&
      const {' ', '\t', '\r', '\n'}.contains(source[cursor])) {
    cursor++;
  }
  return cursor;
}

int _matchingDelimiter(
  String source,
  int openIndex,
  String opening,
  String closing,
) {
  var depth = 0;
  for (var index = openIndex; index < source.length; index++) {
    if (source[index] == opening) depth++;
    if (source[index] == closing) {
      depth--;
      if (depth == 0) return index;
    }
  }
  return -1;
}
