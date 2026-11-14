import '../../../accounts/domain/entities/account.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../payees/domain/entities/payee.dart';
import '../entities/ai_action_draft.dart';

abstract interface class AiTransactionMutationDraftRepository {
  /// Returns null when [input] is not a supported mutation request.
  Future<AiActionDraft?> resolve({
    required String input,
    required List<Account> accounts,
    required List<Category> categories,
    required List<Payee> payees,
  });
}
