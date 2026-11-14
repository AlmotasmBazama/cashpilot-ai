import '../../../../shared/domain/currency/currency_catalog.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../payees/domain/entities/payee.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/domain/enums/transaction_type.dart';
import '../entities/ai_transaction_mutation_command.dart';
import 'ai_transaction_mutation_parser.dart';

sealed class TransactionTargetResolution {
  const TransactionTargetResolution();
}

final class TransactionTargetResolved extends TransactionTargetResolution {
  const TransactionTargetResolved(this.snapshot);

  final AiTransactionTargetSnapshot snapshot;
}

final class TransactionTargetNotFound extends TransactionTargetResolution {
  const TransactionTargetNotFound(this.message);

  final String message;
}

final class TransactionTargetAmbiguous extends TransactionTargetResolution {
  TransactionTargetAmbiguous({
    required this.message,
    required List<AiTransactionTargetSnapshot> choices,
  }) : choices = List<AiTransactionTargetSnapshot>.unmodifiable(choices);

  final String message;
  final List<AiTransactionTargetSnapshot> choices;
}

/// Resolves only from an already owner-scoped, bounded candidate set.
class TransactionTargetResolver {
  const TransactionTargetResolver({this.maxChoices = 3});

  final int maxChoices;

  TransactionTargetResolution resolve({
    required AiTransactionTargetQuery query,
    required List<Transaction> ownerScopedCandidates,
    required List<Account> accounts,
    required List<Category> categories,
    required List<Payee> payees,
    required bool usesArabic,
  }) {
    final accountById = {for (final item in accounts) item.id: item};
    final categoryById = {for (final item in categories) item.id: item};
    final payeeById = {for (final item in payees) item.id: item};
    final subjectHints = query.subjectHints
        .map(_semanticText)
        .where((hint) => hint.isNotEmpty)
        .toSet();
    final filtered =
        ownerScopedCandidates
            .where((transaction) {
              if (query.transferRequested && !transaction.isTransfer) {
                return false;
              }
              if (query.type != null && transaction.type != query.type) {
                return false;
              }
              if (query.previousAmount != null &&
                  transaction.amount.amount != query.previousAmount) {
                return false;
              }
              if (query.accountId != null &&
                  transaction.accountId != query.accountId) {
                return false;
              }
              if (query.categoryId != null &&
                  transaction.categoryId != query.categoryId) {
                return false;
              }
              if (query.payeeId != null &&
                  transaction.payeeId != query.payeeId) {
                return false;
              }
              if (query.status != null && transaction.status != query.status) {
                return false;
              }
              if (query.day != null) {
                final start = query.day!.toUtc();
                final end = start.add(const Duration(days: 1));
                final date = transaction.transactionDate.toUtc();
                if (date.isBefore(start) || !date.isBefore(end)) return false;
              }
              if (subjectHints.isNotEmpty) {
                final searchable = <String>[
                  transaction.note ?? '',
                  transaction.location ?? '',
                  categoryById[transaction.categoryId]?.name ?? '',
                  payeeById[transaction.payeeId]?.name ?? '',
                ].map(_semanticText).join(' ');
                if (!subjectHints.any(searchable.contains)) return false;
              }
              return true;
            })
            .toList(growable: false)
          ..sort(_stableOrder);

    final logical = <Transaction>[];
    final seenTransfers = <String>{};
    for (final transaction in filtered) {
      final groupId = transaction.transferGroupId;
      if (groupId == null) {
        logical.add(transaction);
      } else if (seenTransfers.add(groupId)) {
        final outgoing = filtered
            .where(
              (item) =>
                  item.transferGroupId == groupId &&
                  item.type == TransactionType.transferOut,
            )
            .firstOrNull;
        logical.add(outgoing ?? transaction);
      }
    }

    if (logical.isEmpty) {
      return TransactionTargetNotFound(
        usesArabic
            ? 'ما لقيتش عملية مطابقة، وما تغير شي.'
            : 'No matching transaction was found. Nothing changed.',
      );
    }

    if (query.latest) {
      return TransactionTargetResolved(
        _snapshot(logical.first, accountById, categoryById, payeeById),
      );
    }
    if (logical.length == 1) {
      return TransactionTargetResolved(
        _snapshot(logical.single, accountById, categoryById, payeeById),
      );
    }

    final choices = logical
        .take(maxChoices)
        .map((item) => _snapshot(item, accountById, categoryById, payeeById))
        .toList(growable: false);
    final lines = <String>[
      usesArabic
          ? 'لقيت ${choices.length} عمليات محتملات:'
          : 'I found ${choices.length} possible transactions:',
      for (var index = 0; index < choices.length; index++)
        '${index + 1}. ${_choiceLabel(choices[index], usesArabic)}',
      usesArabic ? 'أي وحدة تقصد؟' : 'Which one do you mean?',
    ];
    return TransactionTargetAmbiguous(
      message: lines.join('\n'),
      choices: choices,
    );
  }

  AiTransactionTargetSnapshot _snapshot(
    Transaction transaction,
    Map<String, Account> accounts,
    Map<String, Category> categories,
    Map<String?, Payee> payees,
  ) {
    return AiTransactionTargetSnapshot(
      transaction: transaction,
      accountName: accounts[transaction.accountId]?.name ?? '—',
      categoryName: categories[transaction.categoryId]?.name ?? '—',
      payeeName: payees[transaction.payeeId]?.name,
    );
  }

  String _choiceLabel(AiTransactionTargetSnapshot snapshot, bool usesArabic) {
    final transaction = snapshot.transaction;
    final subject = transaction.note?.trim().isNotEmpty == true
        ? transaction.note!.trim()
        : snapshot.payeeName ?? snapshot.categoryName;
    final localDate = transaction.transactionDate.toUtc().add(
      const Duration(hours: 2),
    );
    final date =
        '${localDate.year.toString().padLeft(4, '0')}-'
        '${localDate.month.toString().padLeft(2, '0')}-'
        '${localDate.day.toString().padLeft(2, '0')}';
    final currency = transaction.amount.currencyCode.toUpperCase() == 'LYD'
        ? (usesArabic ? 'د.ل' : 'LYD')
        : transaction.amount.currencyCode.toUpperCase();
    return '$subject — ${transaction.amount.amount} $currency — '
        '$date — ${snapshot.accountName}';
  }

  int _stableOrder(Transaction left, Transaction right) {
    final date = right.transactionDate.toUtc().compareTo(
      left.transactionDate.toUtc(),
    );
    if (date != 0) return date;
    final created = right.createdAt.toUtc().compareTo(left.createdAt.toUtc());
    if (created != 0) return created;
    return left.id.compareTo(right.id);
  }

  String _semanticText(String value) => CurrencyCatalog.normalizeText(value)
      .split(' ')
      .map(
        (token) => token.startsWith('ال') && token.length > 4
            ? token.substring(2)
            : token,
      )
      .map(_canonicalSubjectToken)
      .join(' ');

  String _canonicalSubjectToken(String token) => switch (token) {
    'coffee' || 'coffees' || 'قهوه' => 'coffee',
    'transport' || 'transportation' || 'مواصلات' || 'نقل' => 'transport',
    _ => token,
  };
}
