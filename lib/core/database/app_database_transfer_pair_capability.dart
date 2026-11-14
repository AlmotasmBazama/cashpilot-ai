part of 'app_database.dart';

/// Owns the connection-local capability for creating, transitioning, deleting,
/// and validating authoritative transfer pairs.
///
/// [AppDatabase] keeps the public entry points for source compatibility. This
/// extension preserves validation timing, transaction boundaries, statement
/// order, permit lifetime, and exception values without allocating a delegate.
extension _AppDatabaseTransferPairCapability on AppDatabase {
  Future<void> _insertTransferPair({
    required String ownerScopeId,
    required String payloadFingerprint,
    required TransactionsCompanion outgoing,
    required TransactionsCompanion incoming,
  }) {
    final transferGroupId = _requiredNullableStringValue(
      outgoing.transferGroupId,
      'outgoing.transferGroupId',
    );
    final incomingGroupId = _requiredNullableStringValue(
      incoming.transferGroupId,
      'incoming.transferGroupId',
    );
    final outgoingId = _requiredStringValue(outgoing.id, 'outgoing.id');
    final incomingId = _requiredStringValue(incoming.id, 'incoming.id');
    if (transferGroupId != incomingGroupId ||
        !_isCanonicalTransferIdentifier(transferGroupId) ||
        !_isCanonicalTransferIdentifier(outgoingId) ||
        !_isCanonicalTransferIdentifier(incomingId) ||
        outgoingId == incomingId ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(payloadFingerprint) ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(ownerScopeId)) {
      throw ArgumentError('A canonical transfer pair is required.');
    }

    return transaction(() async {
      await _requireTransferScopeIntegrity(ownerScopeId);
      final existing = await customSelect(
        '''SELECT COUNT(*) AS value FROM transactions
           WHERE transfer_group_id = ?''',
        variables: <Variable<Object>>[Variable<String>(transferGroupId)],
      ).getSingle();
      if (existing.read<int>('value') != 0) {
        throw StateError('transfer_group_exists');
      }

      await _installTransferPairPermit(
        ownerScopeId: ownerScopeId,
        transferGroupId: transferGroupId,
        outgoingTransactionId: outgoingId,
        incomingTransactionId: incomingId,
        operation: 'create',
      );
      try {
        await into(transactions).insert(
          outgoing.copyWith(
            ownerScopeId: Value(ownerScopeId),
            transferPayloadFingerprint: Value(payloadFingerprint),
          ),
        );
        await into(transactions).insert(
          incoming.copyWith(
            ownerScopeId: Value(ownerScopeId),
            transferPayloadFingerprint: Value(payloadFingerprint),
          ),
        );
        await _verifyTransferPermitConsumed(
          ownerScopeId: ownerScopeId,
          transferGroupId: transferGroupId,
        );
        await _verifyStoredTransferPair(
          ownerScopeId: ownerScopeId,
          transferGroupId: transferGroupId,
          outgoingTransactionId: outgoingId,
          incomingTransactionId: incomingId,
          payloadFingerprint: payloadFingerprint,
        );
      } finally {
        await _clearTransferPairPermit(
          ownerScopeId: ownerScopeId,
          transferGroupId: transferGroupId,
        );
      }
    });
  }

  Future<void> _updateTransferPair({
    required String ownerScopeId,
    required String transferGroupId,
    required String outgoingTransactionId,
    required String incomingTransactionId,
    required String targetStatus,
    required TransactionsCompanion outgoing,
    required TransactionsCompanion incoming,
  }) {
    return transaction(() async {
      await _requireTransferScopeIntegrity(ownerScopeId);
      final currentStatus = await _verifyStoredTransferPair(
        ownerScopeId: ownerScopeId,
        transferGroupId: transferGroupId,
        outgoingTransactionId: outgoingTransactionId,
        incomingTransactionId: incomingTransactionId,
      );
      final allowed =
          (currentStatus == 'pending' &&
              (targetStatus == 'posted' || targetStatus == 'cancelled')) ||
          (currentStatus == 'posted' && targetStatus == 'cancelled');
      if (!allowed) {
        throw StateError('invalid_transfer_status_transition');
      }
      await _installTransferPairPermit(
        ownerScopeId: ownerScopeId,
        transferGroupId: transferGroupId,
        outgoingTransactionId: outgoingTransactionId,
        incomingTransactionId: incomingTransactionId,
        operation: 'update',
        targetStatus: targetStatus,
      );
      try {
        final outgoingCount =
            await (update(transactions)..where(
                  (row) =>
                      row.ownerScopeId.equals(ownerScopeId) &
                      row.id.equals(outgoingTransactionId),
                ))
                .write(outgoing.copyWith(ownerScopeId: Value(ownerScopeId)));
        final incomingCount =
            await (update(transactions)..where(
                  (row) =>
                      row.ownerScopeId.equals(ownerScopeId) &
                      row.id.equals(incomingTransactionId),
                ))
                .write(incoming.copyWith(ownerScopeId: Value(ownerScopeId)));
        if (outgoingCount != 1 || incomingCount != 1) {
          throw StateError('transfer_pair_changed');
        }
        await _verifyTransferPermitConsumed(
          ownerScopeId: ownerScopeId,
          transferGroupId: transferGroupId,
        );
        await _verifyStoredTransferPair(
          ownerScopeId: ownerScopeId,
          transferGroupId: transferGroupId,
          outgoingTransactionId: outgoingTransactionId,
          incomingTransactionId: incomingTransactionId,
          expectedStatus: targetStatus,
        );
      } finally {
        await _clearTransferPairPermit(
          ownerScopeId: ownerScopeId,
          transferGroupId: transferGroupId,
        );
      }
    });
  }

  Future<void> _deleteTransferPair({
    required String ownerScopeId,
    required String transferGroupId,
    required String outgoingTransactionId,
    required String incomingTransactionId,
  }) {
    return transaction(() async {
      await _requireTransferScopeIntegrity(ownerScopeId);
      final currentStatus = await _verifyStoredTransferPair(
        ownerScopeId: ownerScopeId,
        transferGroupId: transferGroupId,
        outgoingTransactionId: outgoingTransactionId,
        incomingTransactionId: incomingTransactionId,
      );
      if (currentStatus != 'pending') {
        throw StateError('transfer_hard_delete_not_allowed');
      }
      await _installTransferPairPermit(
        ownerScopeId: ownerScopeId,
        transferGroupId: transferGroupId,
        outgoingTransactionId: outgoingTransactionId,
        incomingTransactionId: incomingTransactionId,
        operation: 'delete',
      );
      try {
        final deleted =
            await (delete(transactions)..where(
                  (row) =>
                      row.ownerScopeId.equals(ownerScopeId) &
                      (row.id.equals(outgoingTransactionId) |
                          row.id.equals(incomingTransactionId)),
                ))
                .go();
        if (deleted != 2) {
          throw StateError('transfer_pair_changed');
        }
        await _verifyTransferPermitConsumed(
          ownerScopeId: ownerScopeId,
          transferGroupId: transferGroupId,
        );
      } finally {
        await _clearTransferPairPermit(
          ownerScopeId: ownerScopeId,
          transferGroupId: transferGroupId,
        );
      }
    });
  }

  Future<int> _claimLegacyTransactions({required String ownerScopeId}) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(ownerScopeId)) {
      throw ArgumentError('A canonical owner scope is required.');
    }
    return transaction(() async {
      await _requireTransferScopeIntegrity(ownerScopeId);
      await _validateLegacyTransferRowsForClaim(ownerScopeId);
      if (_enforceFinancialIntegrityGuards) {
        await customStatement(
          '''INSERT INTO cashpilot_transfer_legacy_claim_permits
               (target_owner_scope_id) VALUES (?)''',
          <Object?>[ownerScopeId],
        );
      }
      try {
        final claimed = await customUpdate(
          '''UPDATE transactions SET owner_scope_id = ?
             WHERE owner_scope_id IS NULL''',
          variables: <Variable<Object>>[Variable<String>(ownerScopeId)],
          updates: <TableInfo<Table, Object?>>{transactions},
        );
        final remains = await customSelect(
          '''SELECT COUNT(*) AS value FROM transactions
             WHERE owner_scope_id IS NULL''',
        ).getSingle();
        if (remains.read<int>('value') != 0) {
          throw StateError('legacy_transaction_claim_incomplete');
        }
        return claimed;
      } finally {
        if (_enforceFinancialIntegrityGuards) {
          await customStatement(
            '''DELETE FROM cashpilot_transfer_legacy_claim_permits
               WHERE target_owner_scope_id = ?''',
            <Object?>[ownerScopeId],
          );
        }
      }
    });
  }

  Future<bool> _hasMalformedTransferGroupsForOwner(String ownerScopeId) async {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(ownerScopeId)) {
      return true;
    }
    final candidateRows =
        await (select(transactions)..where(
              (row) =>
                  row.ownerScopeId.equals(ownerScopeId) &
                  (row.type.isIn(const <String>['transferOut', 'transferIn']) |
                      row.transferGroupId.isNotNull()),
            ))
            .get();
    final groups = <String>{};
    for (final row in candidateRows) {
      final isTransfer = row.type == 'transferOut' || row.type == 'transferIn';
      final group = row.transferGroupId;
      if (!isTransfer ||
          group == null ||
          !_isCanonicalTransferIdentifier(group)) {
        return true;
      }
      groups.add(group);
    }
    for (final group in groups) {
      final rows = await (select(
        transactions,
      )..where((row) => row.transferGroupId.equals(group))).get();
      final outgoing = rows.where((row) => row.type == 'transferOut').toList();
      final incoming = rows.where((row) => row.type == 'transferIn').toList();
      if (rows.length != 2 || outgoing.length != 1 || incoming.length != 1) {
        return true;
      }
      try {
        await _verifyStoredTransferPair(
          ownerScopeId: ownerScopeId,
          transferGroupId: group,
          outgoingTransactionId: outgoing.single.id,
          incomingTransactionId: incoming.single.id,
        );
      } on Object {
        return true;
      }
    }
    return false;
  }

  Future<void> _requireTransferScopeIntegrity(String ownerScopeId) async {
    if (await hasMalformedTransferGroupsForOwner(ownerScopeId)) {
      throw const AppException.validation(
        message:
            'Transfer history requires manual review before financial changes.',
        code: 'transfer_scope_integrity_quarantined',
      );
    }
  }

  Future<void> _validateLegacyTransferRowsForClaim(String ownerScopeId) async {
    final rows = await (select(
      transactions,
    )..where((row) => row.ownerScopeId.isNull())).get();
    final grouped = <String, List<TransactionRow>>{};
    for (final row in rows) {
      final isTransfer = row.type == 'transferOut' || row.type == 'transferIn';
      final group = row.transferGroupId;
      if (!isTransfer && group == null) {
        continue;
      }
      if (!isTransfer ||
          group == null ||
          !_isCanonicalTransferIdentifier(group)) {
        throw StateError('legacy_transfer_group_malformed');
      }
      grouped.putIfAbsent(group, () => <TransactionRow>[]).add(row);
    }
    for (final entry in grouped.entries) {
      final collision = await customSelect(
        '''SELECT COUNT(*) AS value FROM transactions
           WHERE transfer_group_id = ? AND owner_scope_id IS NOT NULL''',
        variables: <Variable<Object>>[Variable<String>(entry.key)],
      ).getSingle();
      if (collision.read<int>('value') != 0) {
        throw StateError('legacy_transfer_group_collision');
      }
      final pair = entry.value;
      final outgoing = pair.where((row) => row.type == 'transferOut').toList();
      final incoming = pair.where((row) => row.type == 'transferIn').toList();
      if (pair.length != 2 || outgoing.length != 1 || incoming.length != 1) {
        throw StateError('legacy_transfer_group_malformed');
      }
      final out = outgoing.single;
      final incomingRow = incoming.single;
      Decimal outAmount;
      Decimal inAmount;
      Decimal outRate;
      Decimal inRate;
      try {
        outAmount = Decimal.parse(out.amount);
        inAmount = Decimal.parse(incomingRow.amount);
        outRate = Decimal.parse(out.exchangeRate ?? '');
        inRate = Decimal.parse(incomingRow.exchangeRate ?? '');
      } on Object {
        throw StateError('legacy_transfer_group_malformed');
      }
      final fingerprints = <String?>[
        out.transferPayloadFingerprint,
        incomingRow.transferPayloadFingerprint,
      ];
      // A v17 fingerprint is owner-bound and can only be minted while the
      // pair is already scoped. Legacy NULL-owner rows have no replay
      // authority, even if two raw values happen to match.
      final fingerprintValid = fingerprints.every(
        (fingerprint) => fingerprint == null,
      );
      final legacyTermsValid = _transferTermsAreValid(
        outgoingCurrencyCode: out.currencyCode,
        incomingCurrencyCode: incomingRow.currencyCode,
        outgoingAmount: outAmount,
        incomingAmount: inAmount,
        exchangeRate: outRate,
        allowInformationalCrossCurrencyRate: false,
      );
      final accountsValid = await _transferAccountsMatchOwnerAndCurrency(
        ownerScopeId: ownerScopeId,
        outgoing: out,
        incoming: incomingRow,
      );
      final valid =
          _isCanonicalTransferIdentifier(out.id) &&
          _isCanonicalTransferIdentifier(incomingRow.id) &&
          out.id != incomingRow.id &&
          out.accountId != incomingRow.accountId &&
          outAmount > Decimal.zero &&
          inAmount > Decimal.zero &&
          outRate > Decimal.zero &&
          inRate == outRate &&
          const <String>{
            'pending',
            'posted',
            'cancelled',
            'failed',
          }.contains(out.status) &&
          out.status == incomingRow.status &&
          const <String>{
            'manual',
            'imported',
            'recurring',
            'aiGenerated',
            'cloudSync',
            'system',
          }.contains(out.source) &&
          out.source == incomingRow.source &&
          out.categoryId == incomingRow.categoryId &&
          out.note == incomingRow.note &&
          out.transactionDate.toUtc() == incomingRow.transactionDate.toUtc() &&
          out.paymentMethod == 'bankTransfer' &&
          incomingRow.paymentMethod == 'bankTransfer' &&
          out.exchangeRateFromCurrencyCode?.toUpperCase() ==
              out.currencyCode.toUpperCase() &&
          out.exchangeRateToCurrencyCode?.toUpperCase() ==
              incomingRow.currencyCode.toUpperCase() &&
          out.exchangeRateFromCurrencyCode ==
              incomingRow.exchangeRateFromCurrencyCode &&
          out.exchangeRateToCurrencyCode ==
              incomingRow.exchangeRateToCurrencyCode &&
          out.exchangeRateAsOf?.toUtc() ==
              incomingRow.exchangeRateAsOf?.toUtc() &&
          out.payeeId == null &&
          incomingRow.payeeId == null &&
          out.incomeSourceType == null &&
          incomingRow.incomeSourceType == null &&
          out.location == null &&
          incomingRow.location == null &&
          out.attachmentCount == 0 &&
          incomingRow.attachmentCount == 0 &&
          out.aiConfidence == null &&
          incomingRow.aiConfidence == null &&
          !out.needsReview &&
          !incomingRow.needsReview &&
          accountsValid &&
          legacyTermsValid &&
          fingerprintValid;
      if (!valid) {
        throw StateError('legacy_transfer_group_malformed');
      }
    }
  }

  Future<bool> _transferAccountsMatchOwnerAndCurrency({
    required String ownerScopeId,
    required TransactionRow outgoing,
    required TransactionRow incoming,
  }) async {
    final referencedAccounts =
        await (select(accounts)..where(
              (account) =>
                  account.ownerScopeId.equals(ownerScopeId) &
                  (account.id.equals(outgoing.accountId) |
                      account.id.equals(incoming.accountId)),
            ))
            .get();
    if (referencedAccounts.length != 2) {
      return false;
    }
    final currencyByAccount = <String, String>{
      for (final account in referencedAccounts)
        account.id: account.currencyCode.toUpperCase(),
    };
    return currencyByAccount[outgoing.accountId] ==
            outgoing.currencyCode.toUpperCase() &&
        currencyByAccount[incoming.accountId] ==
            incoming.currencyCode.toUpperCase();
  }

  Future<void> _installTransferPairPermit({
    required String ownerScopeId,
    required String transferGroupId,
    required String outgoingTransactionId,
    required String incomingTransactionId,
    required String operation,
    String? targetStatus,
  }) async {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(ownerScopeId) ||
        !_isCanonicalTransferIdentifier(transferGroupId) ||
        !_isCanonicalTransferIdentifier(outgoingTransactionId) ||
        !_isCanonicalTransferIdentifier(incomingTransactionId) ||
        outgoingTransactionId == incomingTransactionId ||
        !const <String>{'create', 'update', 'delete'}.contains(operation) ||
        (operation == 'update' &&
            !const <String>{'posted', 'cancelled'}.contains(targetStatus))) {
      throw ArgumentError('A canonical transfer capability is required.');
    }
    if (!_enforceFinancialIntegrityGuards) {
      return;
    }
    await customStatement(
      '''INSERT INTO cashpilot_transfer_pair_permits (
           owner_scope_id, transfer_group_id, outgoing_transaction_id,
           incoming_transaction_id, operation, target_status
         ) VALUES (?, ?, ?, ?, ?, ?)''',
      <Object?>[
        ownerScopeId,
        transferGroupId,
        outgoingTransactionId,
        incomingTransactionId,
        operation,
        targetStatus,
      ],
    );
  }

  Future<void> _verifyTransferPermitConsumed({
    required String ownerScopeId,
    required String transferGroupId,
  }) async {
    if (!_enforceFinancialIntegrityGuards) {
      return;
    }
    final row = await customSelect(
      '''SELECT outgoing_done, incoming_done
         FROM cashpilot_transfer_pair_permits
         WHERE owner_scope_id = ? AND transfer_group_id = ?''',
      variables: <Variable<Object>>[
        Variable<String>(ownerScopeId),
        Variable<String>(transferGroupId),
      ],
    ).getSingle();
    if (row.read<int>('outgoing_done') != 1 ||
        row.read<int>('incoming_done') != 1) {
      throw StateError('transfer_pair_permit_not_consumed');
    }
  }

  Future<void> _clearTransferPairPermit({
    required String ownerScopeId,
    required String transferGroupId,
  }) async {
    if (!_enforceFinancialIntegrityGuards) {
      return;
    }
    await customStatement(
      '''DELETE FROM cashpilot_transfer_pair_permits
         WHERE owner_scope_id = ? AND transfer_group_id = ?''',
      <Object?>[ownerScopeId, transferGroupId],
    );
  }

  Future<String> _verifyStoredTransferPair({
    required String ownerScopeId,
    required String transferGroupId,
    required String outgoingTransactionId,
    required String incomingTransactionId,
    String? payloadFingerprint,
    String? expectedStatus,
  }) async {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(ownerScopeId) ||
        !_isCanonicalTransferIdentifier(transferGroupId) ||
        !_isCanonicalTransferIdentifier(outgoingTransactionId) ||
        !_isCanonicalTransferIdentifier(incomingTransactionId) ||
        outgoingTransactionId == incomingTransactionId) {
      throw StateError('transfer_group_malformed');
    }
    final rows = await (select(
      transactions,
    )..where((row) => row.transferGroupId.equals(transferGroupId))).get();
    if (rows.length != 2 ||
        rows.any((row) => row.ownerScopeId != ownerScopeId)) {
      throw StateError('transfer_group_malformed');
    }
    final outgoing = rows.where((row) => row.type == 'transferOut').toList();
    final incoming = rows.where((row) => row.type == 'transferIn').toList();
    if (outgoing.length != 1 || incoming.length != 1) {
      throw StateError('transfer_group_malformed');
    }
    final out = outgoing.single;
    final incomingRow = incoming.single;
    Decimal outAmount;
    Decimal inAmount;
    Decimal outRate;
    Decimal inRate;
    try {
      outAmount = Decimal.parse(out.amount);
      inAmount = Decimal.parse(incomingRow.amount);
      outRate = Decimal.parse(out.exchangeRate ?? '');
      inRate = Decimal.parse(incomingRow.exchangeRate ?? '');
    } on Object {
      throw StateError('transfer_group_malformed');
    }
    final fingerprints = rows
        .map((row) => row.transferPayloadFingerprint)
        .toList(growable: false);
    final fingerprintsValid =
        fingerprints[0] == fingerprints[1] &&
        (fingerprints[0] == null ||
            RegExp(r'^[0-9a-f]{64}$').hasMatch(fingerprints[0]!));
    final transferTermsValid = _transferTermsAreValid(
      outgoingCurrencyCode: out.currencyCode,
      incomingCurrencyCode: incomingRow.currencyCode,
      outgoingAmount: outAmount,
      incomingAmount: inAmount,
      exchangeRate: outRate,
      allowInformationalCrossCurrencyRate: fingerprints.every(
        (fingerprint) => fingerprint != null,
      ),
    );
    final accountsValid = await _transferAccountsMatchOwnerAndCurrency(
      ownerScopeId: ownerScopeId,
      outgoing: out,
      incoming: incomingRow,
    );
    final statuses = rows.map((row) => row.status).toList(growable: false);
    final structurallyValid =
        out.id == outgoingTransactionId &&
        incomingRow.id == incomingTransactionId &&
        out.id != incomingRow.id &&
        out.accountId != incomingRow.accountId &&
        outAmount > Decimal.zero &&
        inAmount > Decimal.zero &&
        outRate > Decimal.zero &&
        inRate == outRate &&
        out.status == incomingRow.status &&
        out.categoryId == incomingRow.categoryId &&
        out.source == incomingRow.source &&
        out.note == incomingRow.note &&
        out.transactionDate.toUtc() == incomingRow.transactionDate.toUtc() &&
        out.paymentMethod == 'bankTransfer' &&
        incomingRow.paymentMethod == 'bankTransfer' &&
        out.exchangeRateFromCurrencyCode?.toUpperCase() ==
            out.currencyCode.toUpperCase() &&
        out.exchangeRateToCurrencyCode?.toUpperCase() ==
            incomingRow.currencyCode.toUpperCase() &&
        out.exchangeRateFromCurrencyCode ==
            incomingRow.exchangeRateFromCurrencyCode &&
        out.exchangeRateToCurrencyCode ==
            incomingRow.exchangeRateToCurrencyCode &&
        out.exchangeRateAsOf?.toUtc() ==
            incomingRow.exchangeRateAsOf?.toUtc() &&
        out.payeeId == null &&
        incomingRow.payeeId == null &&
        out.incomeSourceType == null &&
        incomingRow.incomeSourceType == null &&
        out.location == null &&
        incomingRow.location == null &&
        out.attachmentCount == 0 &&
        incomingRow.attachmentCount == 0 &&
        out.aiConfidence == null &&
        incomingRow.aiConfidence == null &&
        !out.needsReview &&
        !incomingRow.needsReview &&
        accountsValid &&
        const <String>{
          'manual',
          'imported',
          'recurring',
          'aiGenerated',
          'cloudSync',
          'system',
        }.contains(out.source);
    if (!structurallyValid ||
        !fingerprintsValid ||
        !transferTermsValid ||
        statuses[0] != statuses[1] ||
        !const <String>{
          'pending',
          'posted',
          'cancelled',
          'failed',
        }.contains(statuses[0]) ||
        (expectedStatus != null &&
            rows.any((row) => row.status != expectedStatus)) ||
        (payloadFingerprint != null &&
            rows.any(
              (row) => row.transferPayloadFingerprint != payloadFingerprint,
            ))) {
      throw StateError('transfer_group_malformed');
    }
    return statuses[0];
  }
}

String _requiredStringValue(Value<String> value, String name) {
  if (!value.present || !_isCanonicalTransferIdentifier(value.value)) {
    throw ArgumentError('Missing canonical $name.');
  }
  return value.value;
}

String _requiredNullableStringValue(Value<String?> value, String name) {
  final resolved = value.present ? value.value : null;
  if (resolved == null || !_isCanonicalTransferIdentifier(resolved)) {
    throw ArgumentError('Missing canonical $name.');
  }
  return resolved;
}

bool _isCanonicalTransferIdentifier(String value) =>
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$').hasMatch(value);

bool _transferTermsAreValid({
  required String outgoingCurrencyCode,
  required String incomingCurrencyCode,
  required Decimal outgoingAmount,
  required Decimal incomingAmount,
  required Decimal exchangeRate,
  required bool allowInformationalCrossCurrencyRate,
}) {
  final isSameCurrency =
      outgoingCurrencyCode.toUpperCase() == incomingCurrencyCode.toUpperCase();
  if (isSameCurrency) {
    return exchangeRate == Decimal.one && incomingAmount == outgoingAmount;
  }
  return allowInformationalCrossCurrencyRate ||
      incomingAmount == outgoingAmount * exchangeRate;
}
