import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/result.dart';
import '../../features/accounts/application/providers/accounts_providers.dart';
import '../../features/accounts/domain/entities/account.dart';
import '../../features/goals/application/models/goal_linked_account_option.dart';

/// App-shell adaptation from the Accounts read model to the exact projection
/// consumed by Goals presentation.
final goalLinkedAccountOptionsProvider =
    FutureProvider<AppResult<List<GoalLinkedAccountOption>>>((ref) async {
      final result = await ref.watch(accountsProvider.future);
      return switch (result) {
        AppSuccess<List<Account>>(:final data) => AppResult.success(
          data
              .map(
                (account) => GoalLinkedAccountOption(
                  id: account.id,
                  name: account.name,
                  isArchived: account.isArchived,
                ),
              )
              .toList(growable: false),
        ),
        AppFailure<List<Account>>(:final failure) => AppResult.failure(failure),
      };
    }, name: 'goalLinkedAccountOptionsProvider');
