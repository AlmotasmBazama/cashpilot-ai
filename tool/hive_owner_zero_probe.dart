import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    exitCode = 64;
    return;
  }
  final ownerScope = stdin.readLineSync()?.trim() ?? '';
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(ownerScope)) {
    exitCode = 65;
    return;
  }

  final assistantScopeHash = sha256.convert(utf8.encode(ownerScope)).toString();
  final completedKey = 'completed_account_deletion_v1_$ownerScope';
  Hive.init(arguments.single);
  final box = await Hive.openBox<dynamic>('settings');
  var userDataEntries = 0;
  var terminalTombstones = 0;
  var liveOwnerReferences = 0;
  try {
    for (final key in box.keys) {
      final keyText = key is String ? key : '';
      final value = box.get(key);
      final valueText = value is String ? value : jsonEncode(value);
      final referencesOwner =
          keyText.contains(ownerScope) ||
          keyText.contains(assistantScopeHash) ||
          valueText.contains(ownerScope) ||
          valueText.contains(assistantScopeHash);
      if (!referencesOwner) {
        continue;
      }
      liveOwnerReferences += 1;
      if (keyText == completedKey) {
        terminalTombstones += 1;
      } else {
        userDataEntries += 1;
      }
    }
  } finally {
    await box.close();
  }
  stdout.write(
    jsonEncode(<String, int>{
      'userDataEntries': userDataEntries,
      'terminalTombstones': terminalTombstones,
      'liveOwnerReferences': liveOwnerReferences,
    }),
  );
}
