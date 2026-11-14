import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/design_system/design_system.dart';
import '../../auth/auth_composition.dart';
import '../../auth/domain/entities/auth_user.dart';
import '../application/account_deletion_authenticated_continuation.dart';
import '../application/account_deletion_restricted_auth.dart';
import '../application/data_deletion_providers.dart';
import '../data_deletion_presentation.dart'
    show AccountDeletionCredentials, DeleteAllUserDataDialog;
import '../domain/entities/data_deletion_operation_context.dart';

/// A deliberately route-free shell for an authenticated, pre-cloud deletion
/// continuation. It cannot navigate to profile, finance, sync, or AI screens.
class AccountDeletionContinuationApp extends StatelessWidget {
  const AccountDeletionContinuationApp({required this.targets, super.key});

  final List<AccountDeletionRecoveryTarget> targets;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CashPilot AI',
      theme: CPTheme.light(),
      darkTheme: CPTheme.dark(),
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _AccountDeletionContinuationPage(targets: targets),
    );
  }
}

class _AccountDeletionContinuationPage extends ConsumerStatefulWidget {
  const _AccountDeletionContinuationPage({required this.targets});

  final List<AccountDeletionRecoveryTarget> targets;

  @override
  ConsumerState<_AccountDeletionContinuationPage> createState() =>
      _AccountDeletionContinuationPageState();
}

class _AccountDeletionContinuationPageState
    extends ConsumerState<_AccountDeletionContinuationPage> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  ProviderSubscription<AsyncValue<AuthSessionIdentity?>>? _sessionSubscription;
  AuthSessionIdentity? _currentSession;
  AuthSessionIdentity? _freshRestrictedSession;
  var _sessionResolved = false;
  var _requiresRestrictedAuth = true;
  var _busy = false;
  var _authBusy = false;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
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
    return Scaffold(
      key: const Key('account-deletion-continuation'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(CPSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.delete_forever_outlined,
                    size: 56,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: CPSpacing.lg),
                  Text(
                    l10n.deleteAccountTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: CPSpacing.sm),
                  Text(
                    l10n.accountDataDeletionMessage,
                    textAlign: TextAlign.center,
                  ),
                  if (_failed) ...[
                    const SizedBox(height: CPSpacing.md),
                    Text(
                      l10n.dataDeletionReauthFailed,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: CPSpacing.xl),
                  if (!_sessionResolved)
                    const CircularProgressIndicator(
                      key: Key('account-deletion-native-auth-loading'),
                    )
                  else if (_canContinue)
                    FilledButton.icon(
                      key: const Key('continue-account-deletion'),
                      onPressed: _busy ? null : _continueDeletion,
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_outline_rounded),
                      label: Text(l10n.deleteAccountTitle),
                    )
                  else ...[
                    Text(
                      l10n.loginHeadline,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: CPSpacing.xs),
                    Text(l10n.loginSubtitle, textAlign: TextAlign.center),
                    const SizedBox(height: CPSpacing.md),
                    TextField(
                      key: const Key('account-deletion-continuation-email'),
                      controller: _emailController,
                      enabled: !_authBusy,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(labelText: l10n.email),
                    ),
                    const SizedBox(height: CPSpacing.md),
                    TextField(
                      key: const Key('account-deletion-continuation-password'),
                      controller: _passwordController,
                      enabled: !_authBusy,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _signInWithEmail(),
                      decoration: InputDecoration(labelText: l10n.password),
                    ),
                    const SizedBox(height: CPSpacing.md),
                    FilledButton.icon(
                      key: const Key('account-deletion-recovery-login'),
                      onPressed: _authBusy ? null : _signInWithEmail,
                      icon: _authBusy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login_rounded),
                      label: Text(l10n.login),
                    ),
                    const SizedBox(height: CPSpacing.sm),
                    OutlinedButton.icon(
                      key: const Key('account-deletion-recovery-google'),
                      onPressed: _authBusy ? null : _signInWithGoogle,
                      icon: const Icon(Icons.g_mobiledata_rounded),
                      label: Text(l10n.continueWithGoogle),
                    ),
                    const SizedBox(height: CPSpacing.sm),
                    OutlinedButton.icon(
                      key: const Key('account-deletion-recovery-apple'),
                      onPressed: _authBusy ? null : _signInWithApple,
                      icon: const Icon(Icons.apple_rounded),
                      label: Text(l10n.continueWithApple),
                    ),
                  ],
                  const SizedBox(height: CPSpacing.sm),
                  TextButton(
                    onPressed: _busy || _authBusy
                        ? null
                        : _retryStartupRecovery,
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _continueDeletion() async {
    final expectedSession = _currentSession;
    final expectedTarget = matchAccountDeletionRecoveryTarget(
      expectedSession,
      widget.targets,
    );
    if (!_canContinue || expectedSession == null || expectedTarget == null) {
      if (mounted) {
        setState(() => _failed = true);
      }
      return;
    }
    setState(() {
      _busy = true;
      _failed = false;
    });
    final continuation = ref.read(
      accountDeletionAuthenticatedContinuationProvider,
    );
    AccountDeletionContinuationAuthorization? authorization;
    try {
      authorization = await continuation.authorize(widget.targets);
      if (!mounted) {
        if (authorization != null) {
          continuation.release(authorization);
        }
        return;
      }
      if (authorization == null ||
          _currentSession != expectedSession ||
          !_canContinue ||
          !_authorizationMatches(
            authorization,
            expectedSession,
            expectedTarget,
          )) {
        if (authorization != null) {
          continuation.release(authorization);
          authorization = null;
        }
        setState(() => _failed = true);
        return;
      }
      final credentials = await showDialog<AccountDeletionCredentials>(
        context: context,
        barrierDismissible: false,
        builder: (_) => DeleteAllUserDataDialog(
          confirmationLease: authorization!.confirmationLease,
        ),
      );
      if (credentials == null) {
        continuation.release(authorization);
        authorization = null;
        return;
      }
      if (!_authorizationMatches(
        authorization,
        _currentSession,
        expectedTarget,
      )) {
        continuation.release(authorization);
        authorization = null;
        return;
      }
      final result = await continuation.complete(
        authorization,
        email: credentials.email,
        password: credentials.password,
      );
      if (result case AppSuccess()) {
        await _retryStartupRecovery();
      } else if (mounted) {
        setState(() => _failed = true);
      }
    } on Object {
      if (authorization != null) {
        continuation.release(authorization);
      }
      if (mounted) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!email.contains('@') || password.length < 6) {
      setState(() => _failed = true);
      return;
    }
    await _runRestrictedAuth(
      (auth) => auth.signInWithEmail(
        email: email,
        password: password,
        targets: widget.targets,
      ),
    );
  }

  Future<void> _signInWithGoogle() => _runRestrictedAuth(
    (auth) => auth.signInWithGoogle(targets: widget.targets),
  );

  Future<void> _signInWithApple() => _runRestrictedAuth(
    (auth) => auth.signInWithApple(targets: widget.targets),
  );

  Future<void> _runRestrictedAuth(
    Future<AuthSessionIdentity?> Function(AccountDeletionRestrictedAuth auth)
    operation,
  ) async {
    if (_authBusy || _busy) {
      return;
    }
    setState(() {
      _authBusy = true;
      _failed = false;
    });
    try {
      final result = await operation(
        ref.read(accountDeletionRestrictedAuthProvider),
      );
      if (!mounted) {
        return;
      }
      if (result == null ||
          matchAccountDeletionRecoveryTarget(result, widget.targets) == null) {
        setState(() => _failed = true);
        return;
      }
      setState(() {
        _freshRestrictedSession = result;
        _requiresRestrictedAuth = _currentSession != result;
        _failed = false;
        _passwordController.clear();
      });
    } on Object {
      if (mounted) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _authBusy = false;
          _passwordController.clear();
        });
      }
    }
  }

  void _handleNativeSession(
    AsyncValue<AuthSessionIdentity?>? previous,
    AsyncValue<AuthSessionIdentity?> next,
  ) {
    switch (next) {
      case AsyncData<AuthSessionIdentity?>(:final value):
        final wasResolved = _sessionResolved;
        final previousSession = _currentSession;
        final matchingTarget = matchAccountDeletionRecoveryTarget(
          value,
          widget.targets,
        );
        final identityChanged = wasResolved && previousSession != value;
        if (!mounted) {
          return;
        }
        setState(() {
          _sessionResolved = true;
          _currentSession = value;
          if (matchingTarget == null) {
            _requiresRestrictedAuth = true;
            _freshRestrictedSession = null;
            _passwordController.clear();
          } else if (!wasResolved) {
            // A cached exact owner can request a lease; the destructive flow
            // still performs its own mandatory reauthentication.
            _requiresRestrictedAuth = false;
          } else if (_freshRestrictedSession == value) {
            _requiresRestrictedAuth = false;
          } else if (identityChanged) {
            // An externally installed exact UID/generation is not the result
            // of this restricted sign-in intent and cannot mint a lease.
            _requiresRestrictedAuth = true;
          }
        });
      case AsyncError<AuthSessionIdentity?>():
        if (!mounted) {
          return;
        }
        setState(() {
          _sessionResolved = true;
          _currentSession = null;
          _freshRestrictedSession = null;
          _requiresRestrictedAuth = true;
          _failed = true;
          _passwordController.clear();
        });
      case AsyncLoading<AuthSessionIdentity?>():
        return;
    }
  }

  bool get _canContinue {
    final session = _currentSession;
    if (!_sessionResolved ||
        session == null ||
        matchAccountDeletionRecoveryTarget(session, widget.targets) == null) {
      return false;
    }
    return !_requiresRestrictedAuth || _freshRestrictedSession == session;
  }

  bool _authorizationMatches(
    AccountDeletionContinuationAuthorization authorization,
    AuthSessionIdentity? session,
    AccountDeletionRecoveryTarget expectedTarget,
  ) {
    final authorizedTarget = authorization.target;
    if (session == null ||
        matchAccountDeletionRecoveryTarget(session, widget.targets) !=
            expectedTarget ||
        authorizedTarget.operationId != expectedTarget.operationId ||
        authorizedTarget.ownerScopeValue != expectedTarget.ownerScopeValue) {
      return false;
    }
    final lease = authorization.confirmationLease;
    return lease.ownerScopeValue == expectedTarget.ownerScopeValue &&
        lease.authSessionGeneration == session.authSessionGeneration &&
        lease.isAnonymous == session.isAnonymous;
  }

  Future<void> _retryStartupRecovery() async {
    ref.invalidate(accountDeletionStartupRecoveryProvider);
    try {
      await ref.read(accountDeletionStartupRecoveryProvider.future);
    } on Object {
      // The parent app remains locked and exposes the same safe retry surface.
    }
  }
}
