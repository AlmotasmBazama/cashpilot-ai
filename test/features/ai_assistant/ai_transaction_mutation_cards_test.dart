import 'package:cashpilot_ai/features/ai_assistant/application/services/ai_assistant_conversation_workflow_controller.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_action.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_action_draft.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_transaction_mutation_command.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/ai_action_validator.dart';
import 'package:cashpilot_ai/features/ai_assistant/presentation/widgets/ai_action_confirmation_card.dart';
import 'package:cashpilot_ai/features/ai_assistant/presentation/widgets/ai_verified_action_card.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/money.dart';
import 'package:cashpilot_ai/features/payment_methods/payment_methods.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/transaction.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_source.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_status.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_type.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:cashpilot_ai/shared/design_system/design_system.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('update preview is complete and usable at 320px RTL large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final before = _snapshot(_transaction('tx', amount: '30'));
    final after = _snapshot(
      before.transaction.copyWith(
        amount: _money('50.125'),
        note: 'قهوة واجتماع',
        updatedAt: DateTime.utc(2026, 8, 19, 11),
      ),
    );
    final action = UpdateTransactionDraft(
      command: UpdateTransactionCommand(
        commandId: 'update-card',
        original: before,
        updated: after,
        operationRevision: 0,
        previewFingerprint: 'preview',
        createdAt: DateTime.utc(2026, 8, 19, 11),
        expiresAt: DateTime.utc(2026, 8, 19, 11, 15),
      ),
    );

    await _pumpCard(
      tester,
      locale: const Locale('ar'),
      child: AiActionConfirmationCard(
        draft: AiActionDraft.create(action: action),
        validation: const AiActionValidator().validate(action),
        onConfirm: () {},
        onEdit: () {},
        onCancel: () {},
      ),
    );

    expect(find.text('تعديل عملية'), findsOneWidget);
    expect(find.text('المبلغ'), findsOneWidget);
    expect(find.text('الحساب'), findsOneWidget);
    expect(find.text('المحفظة النقدية'), findsOneWidget);
    expect(find.text('الحالة'), findsOneWidget);
    expect(find.text('posted'), findsOneWidget);
    expect(find.text('الملاحظة'), findsOneWidget);
    expect(find.text('الأثر المتوقع على الرصيد'), findsOneWidget);
    expect(find.text('صافي الأثر الإضافي: -20.125 LYD.'), findsOneWidget);
    expect(find.text('تنبيه مالي'), findsOneWidget);
    expect(find.text('تأكيد'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pending to posted preview shows amount account status and exact effect',
    (tester) async {
      final before = _snapshot(
        _transaction(
          'pending',
          amount: '20',
          status: TransactionStatus.pending,
        ),
      );
      final after = _snapshot(
        before.transaction.copyWith(
          status: TransactionStatus.posted,
          updatedAt: DateTime.utc(2026, 8, 19, 11),
        ),
      );
      final action = UpdateTransactionDraft(
        command: UpdateTransactionCommand(
          commandId: 'pending-posted-card',
          original: before,
          updated: after,
          operationRevision: 0,
          previewFingerprint: 'preview',
          createdAt: DateTime.utc(2026, 8, 19, 11),
          expiresAt: DateTime.utc(2026, 8, 19, 11, 15),
        ),
      );

      await _pumpCard(
        tester,
        locale: const Locale('ar'),
        child: AiActionConfirmationCard(
          draft: AiActionDraft.create(action: action),
          validation: const AiActionValidator().validate(action),
          onConfirm: () {},
          onEdit: () {},
          onCancel: () {},
        ),
      );

      expect(find.text('20 LYD'), findsWidgets);
      expect(find.text('المحفظة النقدية'), findsOneWidget);
      expect(find.text('pending  →  posted'), findsOneWidget);
      expect(find.text('صافي الأثر الإضافي: -20 LYD.'), findsOneWidget);
      expect(
        find.text('سيتم تطبيق الأثر المنشور الجديد مرة واحدة.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('posted transfer delete preview shows both legs at 360px', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final outgoing = _snapshot(
      _transaction(
        'out',
        amount: '100',
        type: TransactionType.transferOut,
        transferGroupId: 'pair',
      ),
      accountName: 'Cash wallet',
    );
    final incoming = _snapshot(
      _transaction(
        'in',
        amount: '100',
        type: TransactionType.transferIn,
        transferGroupId: 'pair',
      ),
      accountName: 'Savings account',
    );
    final action = DeleteTransactionDraft(
      command: DeleteTransactionCommand(
        commandId: 'delete-transfer-card',
        targets: <AiTransactionTargetSnapshot>[outgoing, incoming],
        mode: AiTransactionDeleteMode.cancelPostedTransferPair,
        operationRevision: 0,
        previewFingerprint: 'preview',
        createdAt: DateTime.utc(2026, 8, 19, 11),
        expiresAt: DateTime.utc(2026, 8, 19, 11, 15),
      ),
    );

    await _pumpCard(
      tester,
      locale: const Locale('en'),
      child: AiActionConfirmationCard(
        draft: AiActionDraft.create(action: action),
        validation: const AiActionValidator().validate(action),
        onConfirm: () {},
        onEdit: () {},
        onCancel: () {},
      ),
    );

    expect(find.text('Transfer leg 1'), findsOneWidget);
    expect(find.text('Transfer leg 2'), findsOneWidget);
    expect(find.text('Balance change'), findsOneWidget);
    expect(find.text('Undo availability'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('verified update exposes one explicit Arabic undo control', (
    tester,
  ) async {
    var undoCalls = 0;
    final before = _snapshot(_transaction('verified', amount: '30'));
    final after = _snapshot(
      before.transaction.copyWith(
        amount: _money('50'),
        updatedAt: DateTime.utc(2026, 8, 19, 11),
      ),
    );
    final action = UpdateTransactionDraft(
      command: UpdateTransactionCommand(
        commandId: 'verified-update',
        original: before,
        updated: after,
        operationRevision: 1,
        previewFingerprint: 'verified',
        createdAt: DateTime.utc(2026, 8, 19, 11),
        expiresAt: DateTime.utc(2026, 8, 19, 11, 15),
      ),
    );
    final verified = AiAssistantVerifiedAction(
      action: action,
      result: AppAgentExecutionResult(
        commandId: 'verified-update',
        status: AppAgentCommandStatus.succeeded,
        verified: true,
        entityType: 'transaction',
        affectedCount: 1,
        completedAt: DateTime.utc(2026, 8, 19, 11),
        undoAvailable: true,
        undoToken: 'verified-update',
      ),
    );

    await _pumpCard(
      tester,
      locale: const Locale('ar'),
      child: AiVerifiedActionCard(
        verifiedAction: verified,
        onUndo: () => undoCalls += 1,
      ),
    );

    expect(find.text('تم تعديل العملية'), findsOneWidget);
    expect(find.text('قبل'), findsOneWidget);
    expect(find.text('بعد'), findsOneWidget);
    expect(find.text('تراجع'), findsOneWidget);
    await tester.tap(find.text('تراجع'));
    expect(undoCalls, 1);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required Locale locale,
  required Widget child,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: CPTheme.light(),
      builder: (context, widget) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(1.35)),
        child: widget!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

AiTransactionTargetSnapshot _snapshot(
  Transaction transaction, {
  String accountName = 'المحفظة النقدية',
}) => AiTransactionTargetSnapshot(
  transaction: transaction,
  accountName: accountName,
  categoryName: 'قهوة',
);

Transaction _transaction(
  String id, {
  required String amount,
  TransactionType type = TransactionType.expense,
  TransactionStatus status = TransactionStatus.posted,
  String? transferGroupId,
}) => Transaction.create(
  id: id,
  accountId: 'cash',
  categoryId: 'coffee',
  amount: _money(amount),
  type: type,
  paymentMethod: PaymentMethod.cash,
  source: TransactionSource.aiGenerated,
  status: status,
  transferGroupId: transferGroupId,
  note: 'قهوة',
  transactionDate: DateTime.utc(2026, 8, 19, 8),
  createdAt: DateTime.utc(2026, 8, 19, 8),
  updatedAt: DateTime.utc(2026, 8, 19, 8),
);

Money _money(String amount) =>
    Money(amount: Decimal.parse(amount), currencyCode: 'LYD');
