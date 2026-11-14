import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/owner_scope/domain/owner_scope.dart';
import '../../../auth/application/providers/auth_providers.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../domain/entities/data_deletion_request.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';

typedef AccountDeletionCredentials = ({String? email, String? password});

class DeleteAllUserDataDialog extends ConsumerStatefulWidget {
  const DeleteAllUserDataDialog({required this.confirmationLease, super.key});

  final AccountDeletionConfirmationLease confirmationLease;

  @override
  ConsumerState<DeleteAllUserDataDialog> createState() =>
      _DeleteAllUserDataDialogState();
}

class _DeleteAllUserDataDialogState
    extends ConsumerState<DeleteAllUserDataDialog> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  ProviderSubscription<AsyncValue<AuthSessionIdentity?>>? _sessionSubscription;
  var _confirmationAccepted = false;
  var _dismissScheduled = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(
      text: widget.confirmationLease.email ?? '',
    );
    _passwordController = TextEditingController();
    _sessionSubscription = ref.listenManual<AsyncValue<AuthSessionIdentity?>>(
      nativeAuthSessionIdentityProvider,
      _handleNativeSession,
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _sessionSubscription?.close();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.deleteAccountTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.accountDataDeletionMessage),
            if (!widget.confirmationLease.isAnonymous) ...[
              const SizedBox(height: CPSpacing.md),
              Text(
                l10n.passwordForEmailAccounts,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: CPSpacing.md),
              TextField(
                key: const ValueKey('account-deletion-email'),
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: l10n.email),
              ),
              const SizedBox(height: CPSpacing.md),
              TextField(
                key: const ValueKey('account-deletion-password'),
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(labelText: l10n.password),
              ),
            ],
            const SizedBox(height: CPSpacing.md),
            CheckboxListTile(
              key: const ValueKey('confirm-account-data-deletion'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _confirmationAccepted,
              title: Text(l10n.confirmFullDataDeletion),
              onChanged: (value) {
                setState(() => _confirmationAccepted = value ?? false);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton.icon(
          key: const ValueKey('delete-all-user-data'),
          onPressed: _confirmationAccepted ? _submit : null,
          icon: const Icon(Icons.delete_forever_outlined),
          label: Text(l10n.delete),
        ),
      ],
    );
  }

  void _submit() {
    Navigator.of(context).pop<AccountDeletionCredentials>((
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      password: _passwordController.text.isEmpty
          ? null
          : _passwordController.text,
    ));
  }

  bool _leaseMatches(AuthSessionIdentity? session) {
    final expectedScope = widget.confirmationLease.ownerScopeValue;
    final expectedGeneration = widget.confirmationLease.authSessionGeneration;
    if (session == null ||
        expectedScope == null ||
        expectedGeneration == null ||
        session.tenantId != null ||
        session.isAnonymous != widget.confirmationLease.isAnonymous ||
        session.authSessionGeneration != expectedGeneration) {
      return false;
    }
    try {
      return OwnerScopeDerivation.fromConfirmedFirebaseUid(
            session.uid,
          ).id.value ==
          expectedScope;
    } on Object {
      return false;
    }
  }

  void _handleNativeSession(
    AsyncValue<AuthSessionIdentity?>? previous,
    AsyncValue<AuthSessionIdentity?> next,
  ) {
    final invalid = switch (next) {
      AsyncData<AuthSessionIdentity?>(:final value) => !_leaseMatches(value),
      AsyncError<AuthSessionIdentity?>() => true,
      _ => false,
    };
    if (!invalid) {
      return;
    }
    _clearCredentials();
    _scheduleIdentityChangedDismissal();
  }

  void _clearCredentials() {
    _emailController.clear();
    _passwordController.clear();
    _confirmationAccepted = false;
  }

  void _scheduleIdentityChangedDismissal() {
    if (_dismissScheduled) {
      return;
    }
    _dismissScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop<AccountDeletionCredentials>();
      }
    });
  }
}
