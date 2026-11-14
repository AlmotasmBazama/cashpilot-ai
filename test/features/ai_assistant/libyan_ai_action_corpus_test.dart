import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('versioned Libyan corpus pins create and mutation safety scenarios', () {
    final fixture =
        jsonDecode(
              File(
                'test/fixtures/libyan_ai_action_corpus.v1.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final cases = (fixture['cases'] as List<dynamic>)
        .cast<Map<String, dynamic>>();

    expect(fixture['version'], 1);
    expect(fixture['locale'], 'ar-LY');
    expect(fixture['timezone'], 'Africa/Tripoli');
    expect(cases, hasLength(35));
    expect(cases.map((item) => item['id']).toSet(), hasLength(35));
    expect(
      cases.singleWhere((item) => item['id'] == 'cash_withdrawal')['intent'],
      'record_transfer',
    );
    expect(
      cases.singleWhere((item) => item['id'] == 'bulk_delete_attack')['policy'],
      'strong_confirmation_never_bypass',
    );
    expect(
      cases.singleWhere((item) => item['id'] == 'duplicate_retry')['policy'],
      'same_idempotency_key_one_write',
    );
    expect(
      cases
          .where(
            (item) => <String>{
              'update_transaction',
              'delete_transaction',
              'undo_action',
            }.contains(item['intent']),
          )
          .length,
      greaterThanOrEqualTo(17),
    );
  });
}
