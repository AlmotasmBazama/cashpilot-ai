import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../shared/design_system/design_system.dart';

class BootstrapFailureApp extends StatelessWidget {
  const BootstrapFailureApp({required this.onRetry, this.locale, super.key});

  final Future<void> Function() onRetry;
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: CPTheme.light(),
      darkTheme: CPTheme.dark(),
      themeMode: ThemeMode.system,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _BootstrapFailurePage(onRetry: onRetry),
    );
  }
}

class _BootstrapFailurePage extends StatefulWidget {
  const _BootstrapFailurePage({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  State<_BootstrapFailurePage> createState() => _BootstrapFailurePageState();
}

class _BootstrapFailurePageState extends State<_BootstrapFailurePage> {
  var _retrying = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
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
                    Icons.cloud_off_outlined,
                    size: 56,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: CPSpacing.lg),
                  Text(
                    l10n.bootstrapFailureTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: CPSpacing.sm),
                  Text(
                    l10n.bootstrapFailureMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: CPSpacing.xl),
                  FilledButton.icon(
                    onPressed: _retrying ? null : _retry,
                    icon: _retrying
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _retry() async {
    setState(() => _retrying = true);
    await widget.onRetry();
    if (mounted) {
      setState(() => _retrying = false);
    }
  }
}
