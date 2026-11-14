import 'transaction.dart';

enum TransactionHistoryFilter { all, income, expense, transfer, pending }

enum TransactionHistorySort { newest, oldest, amountHigh }

typedef TransactionHistoryRequest = ({
  String query,
  TransactionHistoryFilter filter,
  TransactionHistorySort sort,
  int limit,
});

final class TransactionHistoryPage {
  TransactionHistoryPage({
    required Iterable<Transaction> transactions,
    required this.totalCount,
  }) : transactions = List<Transaction>.unmodifiable(transactions),
       assert(totalCount >= 0);

  final List<Transaction> transactions;
  final int totalCount;

  bool get hasMore => transactions.length < totalCount;
}
