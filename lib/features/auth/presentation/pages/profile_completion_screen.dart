import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_route_paths.dart';
import '../../../../core/error/failure.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/domain/currency/currency_catalog.dart';
import '../../application/providers/auth_providers.dart';
import '../../domain/entities/auth_user.dart';
import '../widgets/auth_screen_scaffold.dart';

class ProfileCompletionScreen extends ConsumerStatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  ConsumerState<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState
    extends ConsumerState<ProfileCompletionScreen> {
  final _nameController = TextEditingController();
  final _countryController = TextEditingController();
  final _timezoneController = TextEditingController(
    text: DateTime.now().timeZoneName,
  );
  var _currency = CurrencyCatalog.defaultCurrencyCode;
  var _language = 'en';
  AuthSessionIdentity? _initializedSession;

  @override
  void dispose() {
    _nameController.dispose();
    _countryController.dispose();
    _timezoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authStateProvider);
    final user = auth.hasValue && !auth.hasError && !auth.isLoading
        ? auth.value
        : null;
    final state = ref.watch(authControllerProvider);
    final isLoading = state.isLoading;

    _initializeForSession(user);

    if (user == null) {
      return AuthScreenScaffold(
        title: l10n.profileCompletionTitle,
        subtitle: l10n.profileCompletionSubtitle,
        child: const Center(
          child: CircularProgressIndicator(
            key: ValueKey('profile-auth-hydration-pending'),
          ),
        ),
      );
    }

    return AuthScreenScaffold(
      title: l10n.profileCompletionTitle,
      subtitle: l10n.profileCompletionSubtitle,
      child: AuthLoadingOverlay(
        visible: isLoading,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.person_rounded,
                size: 42,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: CPSpacing.xl),
            if (_errorMessage(state, l10n.dashboardErrorMessage)
                case final message?) ...[
              AuthErrorBanner(message: message),
              const SizedBox(height: CPSpacing.lg),
            ],
            CPTextField(
              controller: _nameController,
              labelText: l10n.displayName,
              prefix: const Icon(Icons.badge_outlined),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: CPSpacing.md),
            DropdownButtonFormField<String>(
              key: ValueKey(('profile-currency', _initializedSession)),
              initialValue: _currency,
              decoration: InputDecoration(
                labelText: l10n.preferredCurrency,
                prefixIcon: const Icon(Icons.payments_outlined),
              ),
              items: CurrencyCatalog.supportedCodes
                  .map(
                    (currency) => DropdownMenuItem(
                      value: currency,
                      child: Text(currency),
                    ),
                  )
                  .toList(growable: false),
              onChanged: isLoading
                  ? null
                  : (value) => setState(() => _currency = value ?? _currency),
            ),
            const SizedBox(height: CPSpacing.md),
            DropdownButtonFormField<String>(
              key: ValueKey(('profile-language', _initializedSession)),
              initialValue: _language,
              decoration: InputDecoration(
                labelText: l10n.language,
                prefixIcon: const Icon(Icons.translate_rounded),
              ),
              items: [
                DropdownMenuItem(value: 'en', child: Text(l10n.english)),
                DropdownMenuItem(value: 'ar', child: Text(l10n.arabic)),
              ],
              onChanged: isLoading
                  ? null
                  : (value) => setState(() => _language = value ?? _language),
            ),
            const SizedBox(height: CPSpacing.md),
            CPTextField(
              controller: _countryController,
              labelText: l10n.country,
              prefix: const Icon(Icons.public_rounded),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: CPSpacing.md),
            CPTextField(
              controller: _timezoneController,
              labelText: l10n.timezone,
              prefix: const Icon(Icons.schedule_rounded),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: CPSpacing.xl),
            CPButton(
              label: l10n.save,
              icon: Icons.check_rounded,
              size: CPButtonSize.large,
              fullWidth: true,
              isLoading: isLoading,
              onPressed: isLoading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final expectedUser = ref.read(currentAuthUserProvider);
    if (expectedUser == null ||
        expectedUser.sessionIdentity != _initializedSession) {
      return;
    }
    if (_nameController.text.trim().isEmpty ||
        _countryController.text.trim().isEmpty ||
        _timezoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.authInvalidForm)));
      return;
    }

    final ok = await ref
        .read(authControllerProvider.notifier)
        .completeProfile(
          expectedSession: expectedUser.sessionIdentity,
          displayName: _nameController.text,
          currency: _currency,
          language: _language,
          country: _countryController.text,
          timezone: _timezoneController.text,
        );

    if (ok &&
        mounted &&
        expectedUser.sessionIdentity.matches(
          ref.read(currentAuthUserProvider),
        )) {
      context.go(AppRoutePaths.dashboard);
    }
  }

  void _initializeForSession(AuthUser? user) {
    final nextSession = user?.sessionIdentity;
    if (nextSession == _initializedSession) {
      return;
    }
    _initializedSession = nextSession;
    _nameController.text = user?.displayName ?? '';
    _countryController.text = user?.country ?? '';
    _timezoneController.text = user?.timezone ?? DateTime.now().timeZoneName;
    _currency = CurrencyCatalog.normalizeCode(
      user?.currency ?? CurrencyCatalog.defaultCurrencyCode,
    );
    final language = user?.language;
    _language = language == 'ar' ? 'ar' : 'en';
  }
}

String? _errorMessage(AsyncValue<void> state, String fallbackMessage) {
  final error = state.error;
  if (error is Failure) {
    return error.message;
  }

  return error == null ? null : fallbackMessage;
}
