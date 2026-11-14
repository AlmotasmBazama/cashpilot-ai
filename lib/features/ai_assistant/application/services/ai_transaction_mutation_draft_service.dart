import 'package:decimal/decimal.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/result.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/domain/enums/category_type.dart';
import '../../../payees/domain/entities/payee.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/domain/enums/transaction_source.dart';
import '../../../transactions/domain/enums/transaction_status.dart';
import '../../../transactions/domain/enums/transaction_type.dart';
import '../../../transactions/domain/repositories/transactions_repository.dart';
import '../../../transactions/domain/services/transaction_status_transition_policy.dart';
import '../../../transactions/domain/services/transaction_content_comparator.dart';
import '../../domain/app_agent/app_agent_contracts.dart';
import '../../domain/app_agent/app_agent_models.dart';
import '../../domain/app_agent/app_agent_reconciliation.dart';
import '../../domain/entities/ai_action.dart';
import '../../domain/entities/ai_action_draft.dart';
import '../../domain/entities/ai_intent.dart';
import '../../domain/entities/ai_transaction_mutation_command.dart';
import '../../domain/repositories/ai_transaction_mutation_draft_repository.dart';
import '../../domain/services/ai_transaction_mutation_parser.dart';
import '../../domain/services/transaction_target_resolver.dart';

class AiTransactionMutationDraftService
    implements AiTransactionMutationDraftRepository {
  AiTransactionMutationDraftService({
    required TransactionsRepository transactions,
    required AppAgentCommandStore commandStore,
    required AppAgentDurableExecutionStore executionStore,
    required String? Function() currentScope,
    String? Function()? currentTimeZone,
    AiTransactionMutationParser parser = const AiTransactionMutationParser(),
    TransactionTargetResolver targetResolver =
        const TransactionTargetResolver(),
    DateTime Function()? clock,
  }) : _transactions = transactions,
       _commandStore = commandStore,
       _executionStore = executionStore,
       _currentScope = currentScope,
       _currentTimeZone = currentTimeZone ?? _defaultTimeZone,
       _parser = parser,
       _targetResolver = targetResolver,
       _clock = clock ?? _utcNow;

  static const candidateLimit = 20;
  static const undoWindow = Duration(hours: 24);

  final TransactionsRepository _transactions;
  final AppAgentCommandStore _commandStore;
  final AppAgentDurableExecutionStore _executionStore;
  final String? Function() _currentScope;
  final String? Function() _currentTimeZone;
  final AiTransactionMutationParser _parser;
  final TransactionTargetResolver _targetResolver;
  final DateTime Function() _clock;
  final Map<String, _PendingMutationSelection> _pendingSelections =
      <String, _PendingMutationSelection>{};

  @override
  Future<AiActionDraft?> resolve({
    required String input,
    required List<Account> accounts,
    required List<Category> categories,
    required List<Payee> payees,
  }) async {
    final scope = _currentScope();
    if (scope == null) return null;
    final selection = _selectionIndex(input);
    final pending = _pendingSelections[scope];
    if (selection != null && pending != null) {
      if (selection < 0 || selection >= pending.choices.length) {
        return AiActionDraft.create(
          action: ClarificationRequiredAction(
            message: pending.parsed.usesArabic
                ? 'اختار رقم من الخيارات الظاهرة.'
                : 'Choose one of the displayed option numbers.',
          ),
        );
      }
      final id = pending.choices[selection].transaction.id;
      final current = await _transaction(id);
      if (current == null) {
        _pendingSelections.remove(scope);
        return AiActionDraft.create(
          action: ClarificationRequiredAction(
            message: pending.parsed.usesArabic
                ? 'العملية تغيرت أو ما عادتش موجودة. جرب طلبك من جديد.'
                : 'That transaction changed or no longer exists. Try again.',
          ),
        );
      }
      final target = _snapshot(current, accounts, categories, payees);
      if (pending.parsed.intent == AiIntent.updateTransaction &&
          pending.parsed.changes.isEmpty) {
        _pendingSelections[scope] = _PendingMutationSelection(
          parsed: pending.parsed,
          choices: <AiTransactionTargetSnapshot>[target],
          awaitingChanges: true,
        );
        return AiActionDraft.create(
          action: ClarificationRequiredAction(
            message: pending.parsed.usesArabic
                ? 'شن التغيير اللي تبيه في العملية؟'
                : 'What would you like to change in that transaction?',
          ),
        );
      }
      _pendingSelections.remove(scope);
      return _buildResolvedDraft(
        parsed: pending.parsed,
        target: target,
        accounts: accounts,
        categories: categories,
        payees: payees,
      );
    }

    final parsed = _parser.parse(
      input: input,
      accounts: accounts,
      categories: categories,
      payees: payees,
      nowUtc: _clock(),
      timeZoneName: _currentTimeZone() ?? 'Africa/Tripoli',
    );
    if (parsed == null) {
      _pendingSelections.remove(scope);
      return null;
    }
    if (pending?.awaitingChanges == true &&
        parsed.intent == AiIntent.updateTransaction &&
        !parsed.changes.isEmpty) {
      _pendingSelections.remove(scope);
      final id = pending!.choices.single.transaction.id;
      final current = await _transaction(id);
      if (current == null) {
        return AiActionDraft.create(
          action: ClarificationRequiredAction(
            message: pending.parsed.usesArabic
                ? 'العملية تغيرت أو ما عادتش موجودة. جرب طلبك من جديد.'
                : 'That transaction changed or no longer exists. Try again.',
          ),
        );
      }
      return _buildResolvedDraft(
        parsed: parsed,
        target: _snapshot(current, accounts, categories, payees),
        accounts: accounts,
        categories: categories,
        payees: payees,
      );
    }
    if (parsed.intent == AiIntent.undoAction) {
      _pendingSelections.remove(scope);
      if (parsed.undoTransferCancellationRequested) {
        return AiActionDraft.create(
          action: ClarificationRequiredAction(
            message: parsed.usesArabic
                ? 'التراجع عن إلغاء تحويل قائم غير مدعوم بأمان، وما تغير شي.'
                : 'Undoing an existing transfer cancellation is not safely supported. Nothing changed.',
          ),
        );
      }
      return _undoDraft(
        usesArabic: parsed.usesArabic,
        accounts: accounts,
        categories: categories,
        payees: payees,
      );
    }

    final candidates = switch (await _transactions.searchTransactions(
      '',
      limit: candidateLimit,
    )) {
      AppSuccess<List<Transaction>>(:final data) => data,
      AppFailure<List<Transaction>>() => const <Transaction>[],
    };
    final resolution = _targetResolver.resolve(
      query: parsed.query,
      ownerScopedCandidates: candidates
          .where(
            (transaction) =>
                transaction.status == TransactionStatus.pending ||
                transaction.status == TransactionStatus.posted,
          )
          .toList(growable: false),
      accounts: accounts,
      categories: categories,
      payees: payees,
      usesArabic: parsed.usesArabic,
    );
    return switch (resolution) {
      TransactionTargetNotFound(:final message) => AiActionDraft.create(
        action: ClarificationRequiredAction(message: message),
      ),
      TransactionTargetAmbiguous(:final message, :final choices) => () {
        _pendingSelections[scope] = _PendingMutationSelection(
          parsed: parsed,
          choices: choices,
        );
        return AiActionDraft.create(
          action: ClarificationRequiredAction(message: message),
        );
      }(),
      TransactionTargetResolved(:final snapshot) => _buildResolvedDraft(
        parsed: parsed,
        target: snapshot,
        accounts: accounts,
        categories: categories,
        payees: payees,
      ),
    };
  }

  Future<AiActionDraft> _buildResolvedDraft({
    required AiParsedTransactionMutation parsed,
    required AiTransactionTargetSnapshot target,
    required List<Account> accounts,
    required List<Category> categories,
    required List<Payee> payees,
  }) async {
    if (parsed.intent == AiIntent.updateTransaction) {
      return _updateDraft(
        parsed: parsed,
        target: target,
        accounts: accounts,
        categories: categories,
        payees: payees,
      );
    }
    return _deleteDraft(
      parsed: parsed,
      target: target,
      accounts: accounts,
      categories: categories,
      payees: payees,
    );
  }

  AiActionDraft _updateDraft({
    required AiParsedTransactionMutation parsed,
    required AiTransactionTargetSnapshot target,
    required List<Account> accounts,
    required List<Category> categories,
    required List<Payee> payees,
  }) {
    final original = target.transaction;
    if (original.isTransfer || original.transferGroupId != null) {
      return AiActionDraft.create(
        action: ClarificationRequiredAction(
          message: parsed.usesArabic
              ? 'تعديل التحويل غير متاح بأمان. نقدر نعرض إلغاء التحويل كزوج كامل.'
              : 'Transfer editing is not safely supported. I can cancel the complete transfer pair.',
        ),
      );
    }
    final changes = parsed.changes;
    if (changes.isEmpty) {
      return AiActionDraft.create(
        action: ClarificationRequiredAction(
          message: parsed.usesArabic
              ? 'شن التغيير اللي تبيه في العملية؟'
              : 'What should I change in the transaction?',
        ),
      );
    }
    final accountById = {for (final item in accounts) item.id: item};
    final categoryById = {for (final item in categories) item.id: item};
    final payeeById = {for (final item in payees) item.id: item};
    final nextAccount = accountById[changes.accountId ?? original.accountId];
    final nextCategory =
        categoryById[changes.categoryId ?? original.categoryId];
    final nextPayeeId = changes.payeeId ?? original.payeeId;
    final nextPayee = nextPayeeId == null ? null : payeeById[nextPayeeId];
    final nextAmount = changes.amount ?? original.amount.amount;
    final expectedCategoryType = original.type == TransactionType.income
        ? CategoryType.income
        : CategoryType.expense;
    if (nextAccount == null ||
        nextAccount.isArchived ||
        nextCategory == null ||
        nextCategory.isArchived ||
        nextCategory.type != expectedCategoryType ||
        (nextPayeeId != null && (nextPayee == null || nextPayee.isArchived)) ||
        nextAmount <= Decimal.zero ||
        !_validCurrencyScale(nextAmount, original.amount.currencyCode) ||
        nextAccount.currencyCode.toUpperCase() !=
            original.amount.currencyCode.toUpperCase()) {
      return AiActionDraft.create(
        action: ClarificationRequiredAction(
          message: parsed.usesArabic
              ? 'التغيير المطلوب غير صالح للحساب أو العملة أو التصنيف.'
              : 'The requested account, currency, category, or amount is invalid.',
        ),
      );
    }
    final nextStatus = changes.status ?? original.status;
    try {
      validateTransactionStatusTransition(original.status, nextStatus);
    } on Object {
      return AiActionDraft.create(
        action: ClarificationRequiredAction(
          message: parsed.usesArabic
              ? 'تغيير حالة العملية بالطريقة هذي غير مسموح.'
              : 'That transaction status change is not allowed.',
        ),
      );
    }
    final now = _clock().toUtc();
    final updated = original.copyWith(
      accountId: nextAccount.id,
      categoryId: nextCategory.id,
      payeeId: nextPayeeId,
      amount: original.amount.copyWith(amount: nextAmount),
      paymentMethod: changes.paymentMethod ?? original.paymentMethod,
      status: nextStatus,
      incomeSourceType: changes.incomeSourceType ?? original.incomeSourceType,
      note: changes.note ?? original.note,
      transactionDate: changes.transactionDate ?? original.transactionDate,
      location: changes.location ?? original.location,
      updatedAt: now,
    );
    if (_sameTransaction(original, updated, ignoreUpdatedAt: true)) {
      return AiActionDraft.create(
        action: ClarificationRequiredAction(
          message: parsed.usesArabic
              ? 'العملية عندها نفس القيم بالفعل.'
              : 'The transaction already has those values.',
        ),
      );
    }
    final updatedSnapshot = AiTransactionTargetSnapshot(
      transaction: updated,
      accountName: nextAccount.name,
      categoryName: nextCategory.name,
      payeeName: nextPayee?.name,
    );
    final commandId = const Uuid().v7();
    final command = UpdateTransactionCommand(
      commandId: commandId,
      original: target,
      updated: updatedSnapshot,
      operationRevision: 0,
      previewFingerprint: aiTransactionSnapshotFingerprint([
        target,
        updatedSnapshot,
      ]),
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 15)),
    );
    return AiActionDraft.create(
      id: commandId,
      createdAt: now,
      action: UpdateTransactionDraft(command: command),
    );
  }

  Future<AiActionDraft> _deleteDraft({
    required AiParsedTransactionMutation parsed,
    required AiTransactionTargetSnapshot target,
    required List<Account> accounts,
    required List<Category> categories,
    required List<Payee> payees,
  }) async {
    final transaction = target.transaction;
    var targets = <AiTransactionTargetSnapshot>[target];
    final AiTransactionDeleteMode mode;
    if (transaction.isTransfer || transaction.transferGroupId != null) {
      final groupId = transaction.transferGroupId;
      final pair = groupId == null
          ? const <Transaction>[]
          : switch (await _transactions.getTransactions(
              transferGroupId: groupId,
            )) {
              AppSuccess<List<Transaction>>(:final data) => data,
              AppFailure<List<Transaction>>() => const <Transaction>[],
            };
      if (pair.length != 2 ||
          pair.any(
            (item) =>
                item.transferGroupId != groupId ||
                item.status != transaction.status,
          )) {
        return AiActionDraft.create(
          action: ClarificationRequiredAction(
            message: parsed.usesArabic
                ? 'ما قدرتش نثبت سلامة زوج التحويل، لذلك ما تغير شي.'
                : 'The transfer pair could not be verified, so nothing changed.',
          ),
        );
      }
      final sorted = pair.toList(growable: false)
        ..sort(
          (left, right) => left.type == TransactionType.transferOut ? -1 : 1,
        );
      targets = sorted
          .map((item) => _snapshot(item, accounts, categories, payees))
          .toList(growable: false);
      if (transaction.status == TransactionStatus.pending) {
        mode = AiTransactionDeleteMode.deletePendingTransferPair;
      } else if (transaction.status == TransactionStatus.posted) {
        mode = AiTransactionDeleteMode.cancelPostedTransferPair;
      } else {
        return AiActionDraft.create(
          action: ClarificationRequiredAction(
            message: parsed.usesArabic
                ? 'التحويل في حالة نهائية وما نقدرش نلغوه مرة ثانية.'
                : 'The transfer is already terminal and cannot be cancelled again.',
          ),
        );
      }
    } else if (transaction.status == TransactionStatus.pending) {
      mode = AiTransactionDeleteMode.deletePending;
    } else if (transaction.status == TransactionStatus.posted) {
      mode = AiTransactionDeleteMode.reverseAndDeletePosted;
    } else {
      return AiActionDraft.create(
        action: ClarificationRequiredAction(
          message: parsed.usesArabic
              ? 'العملية في حالة نهائية وما نقدرش نحذفها مرة ثانية.'
              : 'The transaction is already terminal and cannot be deleted again.',
        ),
      );
    }
    final now = _clock().toUtc();
    final commandId = const Uuid().v7();
    final command = DeleteTransactionCommand(
      commandId: commandId,
      targets: targets,
      mode: mode,
      operationRevision: 0,
      previewFingerprint: aiTransactionSnapshotFingerprint(targets),
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 15)),
    );
    return AiActionDraft.create(
      id: commandId,
      createdAt: now,
      action: DeleteTransactionDraft(command: command),
    );
  }

  Future<AiActionDraft> _undoDraft({
    required bool usesArabic,
    required List<Account> accounts,
    required List<Category> categories,
    required List<Payee> payees,
  }) async {
    final scope = _currentScope();
    if (scope == null) return _undoUnavailable(usesArabic);
    final now = _clock().toUtc();
    final commands = await _commandStore.readCommandsForScope(scope);
    final consumedSourceIds = commands
        .where(
          (command) =>
              command.toolId == 'undoAiAction' &&
              (command.status == AppAgentCommandStatus.confirmed ||
                  command.status == AppAgentCommandStatus.executing ||
                  command.status == AppAgentCommandStatus.succeeded),
        )
        .map((command) => command.normalizedArguments['sourceCommandId'])
        .whereType<String>()
        .toSet();
    for (final source in commands) {
      if (!_undoSourceTools.contains(source.toolId) ||
          source.status != AppAgentCommandStatus.succeeded ||
          consumedSourceIds.contains(source.commandId)) {
        continue;
      }
      final result = await _executionStore.readVerifiedResult(source.commandId);
      if (result == null ||
          !result.verified ||
          !result.undoAvailable ||
          now.difference(result.completedAt.toUtc()) > undoWindow) {
        continue;
      }
      final payload = await _undoPayload(
        source,
        accounts: accounts,
        categories: categories,
        payees: payees,
      );
      if (payload == null) continue;
      final commandId = const Uuid().v7();
      final command = UndoAiActionCommand(
        commandId: commandId,
        sourceCommandId: source.commandId,
        sourceToolId: source.toolId,
        operationType: payload.operationType,
        before: payload.before,
        after: payload.after,
        sourceOperationRevision: source.revision,
        operationRevision: 0,
        previewFingerprint: aiTransactionSnapshotFingerprint([
          ...payload.before,
          ...payload.after,
        ]),
        createdAt: now,
        expiresAt: now.add(const Duration(minutes: 15)),
      );
      return AiActionDraft.create(
        id: commandId,
        createdAt: now,
        action: UndoAiActionDraft(command: command),
      );
    }
    return _undoUnavailable(usesArabic);
  }

  Future<_UndoPayload?> _undoPayload(
    AppAgentCommand source, {
    required List<Account> accounts,
    required List<Category> categories,
    required List<Payee> payees,
  }) async {
    if (source.toolId == 'updateTransactionDraft') {
      final command = UpdateTransactionCommand.fromArguments(
        source.normalizedArguments,
      );
      if (command == null) return null;
      final current = await _transaction(command.updated.transaction.id);
      if (current == null ||
          !_sameTransaction(current, command.updated.transaction)) {
        return null;
      }
      return _UndoPayload(
        operationType: AiUndoOperationType.undoUpdateTransaction,
        before: <AiTransactionTargetSnapshot>[command.original],
        after: <AiTransactionTargetSnapshot>[command.updated],
      );
    }
    if (source.toolId == 'deleteTransactionDraft') {
      final command = DeleteTransactionCommand.fromArguments(
        source.normalizedArguments,
      );
      if (command == null ||
          command.targets.any((target) => target.transaction.isTransfer)) {
        return null;
      }
      if (await _transaction(command.targets.single.transaction.id) != null) {
        return null;
      }
      return _UndoPayload(
        operationType: AiUndoOperationType.undoDeleteTransaction,
        before: command.targets,
        after: const <AiTransactionTargetSnapshot>[],
      );
    }
    if (source.toolId == 'createExpenseDraft' ||
        source.toolId == 'createIncomeDraft') {
      final id = AppAgentBusinessIdentifiers.transactionId(source);
      final current = await _transaction(id);
      if (current == null || !_matchesCreatedTransaction(source, current)) {
        return null;
      }
      return _UndoPayload(
        operationType: AiUndoOperationType.undoCreateTransaction,
        before: const <AiTransactionTargetSnapshot>[],
        after: <AiTransactionTargetSnapshot>[
          _snapshot(current, accounts, categories, payees),
        ],
      );
    }
    if (source.toolId == 'createTransferDraft') {
      final ids = <String>[
        AppAgentBusinessIdentifiers.transferOutgoingId(source),
        AppAgentBusinessIdentifiers.transferIncomingId(source),
      ];
      final current = <Transaction>[];
      for (final id in ids) {
        final transaction = await _transaction(id);
        if (transaction == null ||
            transaction.status != TransactionStatus.posted) {
          return null;
        }
        current.add(transaction);
      }
      if (current.any(
        (item) =>
            item.transferGroupId !=
            AppAgentBusinessIdentifiers.transferGroupId(source),
      )) {
        return null;
      }
      return _UndoPayload(
        operationType: AiUndoOperationType.undoCreateTransfer,
        before: const <AiTransactionTargetSnapshot>[],
        after: current
            .map((item) => _snapshot(item, accounts, categories, payees))
            .toList(growable: false),
      );
    }
    return null;
  }

  AiActionDraft _undoUnavailable(bool usesArabic) => AiActionDraft.create(
    action: ClarificationRequiredAction(
      message: usesArabic
          ? 'ما فيش آخر إجراء مؤهل للتراجع، أو العملية تغيرت بعده.'
          : 'There is no eligible action to undo, or the transaction changed afterward.',
    ),
  );

  Future<Transaction?> _transaction(String id) async {
    return switch (await _transactions.getTransaction(id)) {
      AppSuccess<Transaction?>(:final data) => data,
      AppFailure<Transaction?>() => null,
    };
  }

  AiTransactionTargetSnapshot _snapshot(
    Transaction transaction,
    List<Account> accounts,
    List<Category> categories,
    List<Payee> payees,
  ) {
    final account = accounts
        .where((item) => item.id == transaction.accountId)
        .firstOrNull;
    final category = categories
        .where((item) => item.id == transaction.categoryId)
        .firstOrNull;
    final payee = payees
        .where((item) => item.id == transaction.payeeId)
        .firstOrNull;
    return AiTransactionTargetSnapshot(
      transaction: transaction,
      accountName: account?.name ?? '—',
      categoryName: category?.name ?? '—',
      payeeName: payee?.name,
    );
  }

  bool _matchesCreatedTransaction(
    AppAgentCommand command,
    Transaction transaction,
  ) {
    final args = command.normalizedArguments;
    return transaction.id ==
            AppAgentBusinessIdentifiers.transactionId(command) &&
        transaction.accountId == args['accountId'] &&
        transaction.categoryId == args['categoryId'] &&
        transaction.payeeId == args['payeeId'] &&
        transaction.amount.amount.toString() == args['amount'] &&
        transaction.amount.currencyCode == args['currency'] &&
        transaction.type.name == args['transactionType'] &&
        transaction.paymentMethod.name == args['paymentMethod'] &&
        transaction.status.name == args['status'] &&
        transaction.source == TransactionSource.aiGenerated &&
        transaction.note == args['note'];
  }

  bool _sameTransaction(
    Transaction left,
    Transaction right, {
    bool ignoreUpdatedAt = false,
  }) => transactionContentEquals(left, right, ignoreUpdatedAt: ignoreUpdatedAt);

  bool _validCurrencyScale(Decimal amount, String currencyCode) {
    if (currencyCode.toUpperCase() != 'LYD') return true;
    final text = amount.toString();
    final dot = text.indexOf('.');
    return dot < 0 || text.length - dot - 1 <= 3;
  }

  int? _selectionIndex(String input) {
    final normalized = input.trim().toLowerCase();
    const ordinals = <String, int>{
      '1': 0,
      '١': 0,
      'الأولى': 0,
      'الاولى': 0,
      'first': 0,
      '2': 1,
      '٢': 1,
      'الثانية': 1,
      'الثانيه': 1,
      'second': 1,
      '3': 2,
      '٣': 2,
      'الثالثة': 2,
      'الثالثه': 2,
      'third': 2,
    };
    return ordinals[normalized];
  }
}

class _PendingMutationSelection {
  const _PendingMutationSelection({
    required this.parsed,
    required this.choices,
    this.awaitingChanges = false,
  });

  final AiParsedTransactionMutation parsed;
  final List<AiTransactionTargetSnapshot> choices;
  final bool awaitingChanges;
}

class _UndoPayload {
  const _UndoPayload({
    required this.operationType,
    required this.before,
    required this.after,
  });

  final AiUndoOperationType operationType;
  final List<AiTransactionTargetSnapshot> before;
  final List<AiTransactionTargetSnapshot> after;
}

const _undoSourceTools = <String>{
  'createExpenseDraft',
  'createIncomeDraft',
  'createTransferDraft',
  'updateTransactionDraft',
  'deleteTransactionDraft',
};

DateTime _utcNow() => DateTime.now().toUtc();

String _defaultTimeZone() => 'Africa/Tripoli';
