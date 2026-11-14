import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_route_paths.dart';
import '../../../../core/error/failure.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../application/providers/auth_providers.dart';
import '../widgets/auth_screen_scaffold.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  var _acceptedTerms = false;
  var _obscurePassword = true;

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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(authControllerProvider);
    final isLoading = state.isLoading;

    return AuthScreenScaffold(
      title: l10n.registerHeadline,
      subtitle: l10n.registerSubtitle,
      child: AuthLoadingOverlay(
        visible: isLoading,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_errorMessage(state, l10n.dashboardErrorMessage)
                case final message?) ...[
              AuthErrorBanner(message: message),
              const SizedBox(height: CPSpacing.lg),
            ],
            CPTextField(
              controller: _nameController,
              labelText: l10n.name,
              prefix: const Icon(Icons.person_outline_rounded),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: CPSpacing.md),
            CPTextField(
              controller: _emailController,
              labelText: l10n.email,
              prefix: const Icon(Icons.mail_outline_rounded),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: CPSpacing.md),
            CPTextField(
              controller: _passwordController,
              labelText: l10n.password,
              prefix: const Icon(Icons.lock_outline_rounded),
              obscureText: _obscurePassword,
              suffix: IconButton(
                tooltip: _obscurePassword
                    ? l10n.showPassword
                    : l10n.hidePassword,
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: CPSpacing.md),
            CPTextField(
              controller: _confirmPasswordController,
              labelText: l10n.confirmPassword,
              prefix: const Icon(Icons.lock_reset_rounded),
              obscureText: true,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: CPSpacing.sm),
            CheckboxListTile(
              value: _acceptedTerms,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(l10n.acceptTerms),
              onChanged: isLoading
                  ? null
                  : (value) => setState(() => _acceptedTerms = value ?? false),
            ),
            const SizedBox(height: CPSpacing.lg),
            CPButton(
              label: l10n.createAccount,
              icon: Icons.person_add_alt_rounded,
              size: CPButtonSize.large,
              fullWidth: true,
              isLoading: isLoading,
              onPressed: isLoading ? null : _submit,
            ),
            const SizedBox(height: CPSpacing.md),
            CPButton(
              label: l10n.login,
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
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty ||
        !email.contains('@') ||
        password.length < 6 ||
        password != _confirmPasswordController.text ||
        !_acceptedTerms) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.authInvalidForm)));
      return;
    }

    final ok = await ref
        .read(authControllerProvider.notifier)
        .signUp(name: name, email: email, password: password);

    if (ok && mounted) {
      context.go(AppRoutePaths.emailVerification);
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
