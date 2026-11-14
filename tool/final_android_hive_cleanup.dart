import 'dart:io';

import 'package:hive/hive.dart';

import 'package:cashpilot_ai/core/storage/owner_scoped_storage_keys.dart';
import 'package:cashpilot_ai/core/storage/settings_keys.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('cleanup_argument_invalid');
    exitCode = 2;
    return;
  }

  Hive.init(arguments.single);
  final box = await Hive.openBox<dynamic>('settings');
  try {
    final stringKeys = box.keys.whereType<String>().toList(growable: false);
    final operationKeys = stringKeys
        .where(
          (key) =>
              key.startsWith(SettingsKeys.dataDeletionOperationStatePrefix),
        )
        .toList(growable: false);
    final quarantineKeys = stringKeys
        .where(
          (key) => key.startsWith(SettingsKeys.ownerDeletionQuarantinePrefix),
        )
        .toList(growable: false);

    if (operationKeys.length != 1 || quarantineKeys.length != 1) {
      throw StateError('cleanup_scope_not_unique');
    }

    final ownerScope = quarantineKeys.single.substring(
      SettingsKeys.ownerDeletionQuarantinePrefix.length,
    );
    final ownerKeys = OwnerScopedStorageKeys.fromCanonicalOwnerScopeValue(
      ownerScope,
    );
    final scopedPreferenceKeys = <String>{
      '${SettingsKeys.backupEnabled}_$ownerScope',
      '${SettingsKeys.lastBackupAt}_$ownerScope',
      '${SettingsKeys.backupConsentGeneration}_$ownerScope',
      '${SettingsKeys.backupInitialSnapshotComplete}_$ownerScope',
      ...ownerKeys.values,
    };
    final receiptJournalKeys = stringKeys
        .where(
          (key) =>
              key.startsWith(SettingsKeys.receiptFileDeletionJournalPrefix),
        )
        .toList(growable: false);
    if (receiptJournalKeys.length > 1) {
      throw StateError('cleanup_receipt_journal_not_unique');
    }

    final targets = <String>{
      ...operationKeys,
      ...quarantineKeys,
      ...receiptJournalKeys,
      ...scopedPreferenceKeys.where(box.containsKey),
    };
    await box.deleteAll(targets);
    await box.flush();

    final remains = targets.where(box.containsKey).length;
    stdout.writeln('operationKeysRemoved=${operationKeys.length}');
    stdout.writeln('quarantineKeysRemoved=${quarantineKeys.length}');
    stdout.writeln('receiptJournalKeysRemoved=${receiptJournalKeys.length}');
    stdout.writeln(
      'ownedPreferenceKeysRemoved=${targets.length - operationKeys.length - quarantineKeys.length - receiptJournalKeys.length}',
    );
    stdout.writeln('targetKeysRemaining=$remains');
    if (remains != 0) {
      exitCode = 1;
    }
  } finally {
    await box.close();
  }
}
