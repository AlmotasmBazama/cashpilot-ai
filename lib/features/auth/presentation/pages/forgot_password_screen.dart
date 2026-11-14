import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_route_paths.dart';
import '../../../../core/error/failure.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../application/providers/auth_providers.dart';
import '../widgets/auth_screen_scaffold.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  var _sent = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (mounted) {
        ref.invalidate(authControllerProvider);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(authControllerProvider);
    final isLoading = state.isLoading;

    return AuthScreenScaffold(
      title: l10n.forgotPasswordTitle,
      subtitle: l10n.forgotPasswordSubtitle,
      child: AuthLoadingOverlay(
        visible: isLoading,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_sent) ...[
              Icon(
                Icons.mark_email_read_outlined,
                size: 54,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: CPSpacing.md),
              Text(
                l10n.resetLinkSent,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: CPSpacing.xl),
            ],
            if (_errorMessage(state, l10n.dashboardErrorMessage)
                case final message?) ...[
              AuthErrorBanner(message: message),
              const SizedBox(height: CPSpacing.lg),
            ],
            CPTextField(
              controller: _emailController,
              labelText: l10n.email,
              prefix: const Icon(Icons.mail_outline_rounded),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: CPSpacing.lg),
            CPButton(
              label: l10n.sendResetLink,
              icon: Icons.mail_outline_rounded,
              size: CPButtonSize.large,
              fullWidth: true,
              isLoading: isLoading,
              onPressed: isLoading ? null : _submit,
            ),
            const SizedBox(height: CPSpacing.md),
            CPButton(
              label: l10n.backToLogin,
              variant: CPButtonVariant.ghost,
              fullWidth: true,
              onPressed: isLoading
                  ? null
                  : () {
                      ref.invalidate(authControllerProvider);
                      context.go(AppRoutePaths.login);
                    },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_emailController.text.trim().contains('@')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.authInvalidForm)));
      return;
    }

    final ok = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordResetEmail(_emailController.text);
    if (ok && mounted) {
      setState(() => _sent = true);
    }
  }
}

String? _errorMessage(AsyncValue<void> state, String fallbackMessage) {
  final error = state.error;
  if (error is Failure) {
    return error.message;
  }

  return error == null ? null : fallbackMessage;
}
