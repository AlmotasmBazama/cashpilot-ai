import '../../../accounts/domain/entities/account.dart';
import '../../../categories/domain/entities/category.dart';
import '../entities/ai_transaction_draft.dart';
import '../services/financial_command_parser.dart';

class ParseFinancialCommand {
  const ParseFinancialCommand(this._parser);

  final FinancialCommandParser _parser;

  AiTransactionParseResult call({
    required String input,
    required List<Account> accounts,
    required List<Category> categories,
    required String baseCurrencyCode,
    required String paymentMethodClarificationMessage,
  }) {
    return _parser.parse(
      input: input,
      accounts: accounts,
      categories: categories,
      baseCurrencyCode: baseCurrencyCode,
      paymentMethodClarificationMessage: paymentMethodClarificationMessage,
    );
  }
}
