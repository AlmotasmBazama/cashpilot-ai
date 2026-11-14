import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_route_paths.dart';
import '../../../../core/error/failure.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/accessibility/acceptance_semantics.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../application/providers/auth_providers.dart';
import '../widgets/auth_screen_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _obscurePassword = true;
  var _acceptanceInvalidForm = false;

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
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(authControllerProvider);
    final rememberMe = ref.watch(rememberMeProvider);
    final isLoading = state.isLoading;

    return AuthScreenScaffold(
      title: l10n.loginHeadline,
      subtitle: l10n.loginSubtitle,
      child: cashPilotForceStopAcceptanceSemantics(
        identifier: _acceptanceLoginStateIdentifier(state),
        child: AuthLoadingOverlay(
          visible: isLoading,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_errorMessage(state, l10n.dashboardErrorMessage)
                    case final message?) ...[
                  AuthErrorBanner(message: message),
                  const SizedBox(height: CPSpacing.lg),
                ],
                CPTextField(
                  semanticsIdentifier: cashPilotForceStopAcceptanceIdentifier(
                    'cashpilot_acceptance_login_email',
                  ),
                  controller: _emailController,
                  labelText: l10n.email,
                  prefix: const Icon(Icons.mail_outline_rounded),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onChanged: cashPilotForceStopAcceptanceSemanticsEnabled
                      ? _onAcceptanceCredentialChanged
                      : null,
                ),
                const SizedBox(height: CPSpacing.md),
                CPTextField(
                  semanticsIdentifier: cashPilotForceStopAcceptanceIdentifier(
                    'cashpilot_acceptance_login_password',
                  ),
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
                  textInputAction: TextInputAction.done,
                  onChanged: cashPilotForceStopAcceptanceSemanticsEnabled
                      ? _onAcceptanceCredentialChanged
                      : null,
                ),
                const SizedBox(height: CPSpacing.sm),
                Row(
                  children: [
                    Checkbox(
                      value: rememberMe,
                      onChanged: isLoading
                          ? null
                          : (value) {
                              ref.read(rememberMeProvider.notifier).state =
                                  value ?? false;
                            },
                    ),
                    Expanded(child: Text(l10n.rememberMe)),
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () => _goClearingAuthError(
                              AppRoutePaths.forgotPassword,
                            ),
                      child: Text(l10n.forgotPassword),
                    ),
                  ],
                ),
                const SizedBox(height: CPSpacing.lg),
                CPButton(
                  label: l10n.login,
                  semanticsIdentifier: cashPilotForceStopAcceptanceIdentifier(
                    'cashpilot_acceptance_login_submit',
                  ),
                  icon: Icons.login_rounded,
                  size: CPButtonSize.large,
                  fullWidth: true,
                  isLoading: isLoading,
                  onPressed: isLoading ? null : _submit,
                ),
                const SizedBox(height: CPSpacing.lg),
                AuthProviderButton(
                  label: l10n.continueWithGoogle,
                  icon: Icons.g_mobiledata_rounded,
                  isLoading: isLoading,
                  onPressed: isLoading ? null : _google,
                ),
                const SizedBox(height: CPSpacing.md),
                AuthProviderButton(
                  label: l10n.continueWithApple,
                  icon: Icons.apple_rounded,
                  isLoading: isLoading,
                  onPressed: isLoading ? null : _apple,
                ),
                const SizedBox(height: CPSpacing.md),
                CPButton(
                  label: l10n.continueAsGuest,
                  icon: Icons.visibility_outlined,
                  variant: CPButtonVariant.ghost,
                  fullWidth: true,
                  onPressed: isLoading
                      ? null
                      : () => context.go(AppRoutePaths.guestInfo),
                ),
                const Divider(height: CPSpacing.xxl),
                CPButton(
                  label: l10n.createAccount,
                  icon: Icons.person_add_alt_rounded,
                  variant: CPButtonVariant.tonal,
                  fullWidth: true,
                  onPressed: isLoading
                      ? null
                      : () => _goClearingAuthError(AppRoutePaths.register),
                ),
                const SizedBox(height: CPSpacing.lg),
                const AuthTermsText(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_validateEmailAndPassword()) {
      return;
    }

    final ok = await ref
        .read(authControllerProvider.notifier)
        .signIn(
          email: _emailController.text,
          password: _passwordController.text,
          rememberMe: ref.read(rememberMeProvider),
        );

    if (ok && mounted) {
      context.go(AppRoutePaths.dashboard);
    }
  }

  Future<void> _google() async {
    final ok = await ref
        .read(authControllerProvider.notifier)
        .signInWithGoogle(rememberMe: ref.read(rememberMeProvider));
    if (ok && mounted) {
      context.go(AppRoutePaths.dashboard);
    }
  }

  Future<void> _apple() async {
    final ok = await ref
        .read(authControllerProvider.notifier)
        .signInWithApple(rememberMe: ref.read(rememberMeProvider));
    if (ok && mounted) {
      context.go(AppRoutePaths.dashboard);
    }
  }

  void _goClearingAuthError(String location) {
    ref.invalidate(authControllerProvider);
    context.go(location);
  }

  bool _validateEmailAndPassword() {
    final l10n = AppLocalizations.of(context);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!email.contains('@') || password.length < 6) {
      if (cashPilotForceStopAcceptanceSemanticsEnabled &&
          !_acceptanceInvalidForm) {
        setState(() => _acceptanceInvalidForm = true);
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.authInvalidForm)));
      return false;
    }

    return true;
  }

  void _onAcceptanceCredentialChanged(String _) {
    if (!cashPilotForceStopAcceptanceSemanticsEnabled) {
      return;
    }
    setState(() => _acceptanceInvalidForm = false);
  }

  String _acceptanceLoginStateIdentifier(AsyncValue<void> state) {
    if (state.isLoading) {
      return 'cashpilot_acceptance_login_state_submitting';
    }
    if (_acceptanceInvalidForm) {
      return 'cashpilot_acceptance_login_state_failure_invalid_form';
    }
    if (state.error case final error?) {
      return 'cashpilot_acceptance_login_state_failure_${_acceptanceLoginFailureKind(error)}';
    }
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.contains('@') && password.length >= 6) {
      return 'cashpilot_acceptance_login_state_ready';
    }
    return 'cashpilot_acceptance_login_state_idle';
  }
}

String _acceptanceLoginFailureKind(Object error) {
  final code = error is Failure ? error.code : null;
  return switch (code) {
    'invalid-credential' ||
    'wrong-password' ||
    'invalid-email' ||
    'user-not-found' => 'invalid_credentials',
    'network-request-failed' || 'unavailable' => 'network',
    'permission-denied' => 'permission_denied',
    'unauthenticated' => 'unauthenticated',
    'auth-session-changed' => 'session_changed',
    'too-many-requests' => 'rate_limited',
    'operation-not-allowed' ||
    'admin-restricted-operation' => 'provider_disabled',
    'user-disabled' => 'user_disabled',
    _ => 'unknown',
  };
}

String? _errorMessage(AsyncValue<void> state, String fallbackMessage) {
  final error = state.error;
  if (error is Failure) {
    return error.message;
  }

  return error == null ? null : fallbackMessage;
}
