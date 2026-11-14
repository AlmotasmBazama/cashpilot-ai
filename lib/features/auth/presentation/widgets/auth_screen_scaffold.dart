import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';

class AuthScreenScaffold extends StatelessWidget {
  const AuthScreenScaffold({
    required this.child,
    this.title,
    this.subtitle,
    this.footer,
    this.leading,
    this.maxWidth = 480,
    super.key,
  });

  final String? title;
  final String? subtitle;
  final Widget child;
  final Widget? footer;
  final Widget? leading;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          gradient: colorScheme.brightness == Brightness.dark
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    CPColors.background,
                    CPColors.surface,
                    colorScheme.surfaceContainerLow,
                  ],
                )
              : null,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.all(CPSpacing.xl),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: width >= 900 ? 1040 : maxWidth,
                ),
                child: width >= 900
                    ? Row(
                        children: [
                          Expanded(
                            child: _BrandPanel(
                              title: title ?? l10n.appTitle,
                              subtitle: subtitle ?? l10n.authDefaultSubtitle,
                              leading: leading,
                            ),
                          ),
                          const SizedBox(width: CPSpacing.xxxl),
                          SizedBox(
                            width: maxWidth,
                            child: _FormPanel(child: child),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CashPilotBrandMark(size: 72),
                          const SizedBox(height: CPSpacing.lg),
                          if (title != null)
                            Text(
                              title!,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          if (subtitle != null) ...[
                            const SizedBox(height: CPSpacing.sm),
                            Text(
                              subtitle!,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                          const SizedBox(height: CPSpacing.xxl),
                          _FormPanel(child: child),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: footer == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(CPSpacing.md),
                child: footer,
              ),
            ),
    );
  }
}

class CashPilotBrandMark extends StatelessWidget {
  const CashPilotBrandMark({this.size = 56, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'cashpilot-brand-mark',
      child: CPBrandMark(size: size),
    );
  }
}

class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(CPSpacing.lg),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(CPRadius.sm),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: CPSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthProviderButton extends StatelessWidget {
  const AuthProviderButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return CPButton(
      label: label,
      icon: icon,
      variant: CPButtonVariant.outline,
      size: CPButtonSize.large,
      fullWidth: true,
      isLoading: isLoading,
      onPressed: onPressed,
    );
  }
}

class AuthTermsText extends StatelessWidget {
  const AuthTermsText({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Text(
      l10n.authTermsPrivacy,
      textAlign: TextAlign.center,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
    );
  }
}

class AuthLoadingOverlay extends StatelessWidget {
  const AuthLoadingOverlay({
    required this.visible,
    required this.child,
    super.key,
  });

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (visible)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.64),
                borderRadius: BorderRadius.circular(CPRadius.lg),
              ),
              child: const Center(child: CPLoadingIndicator()),
            ),
          ),
      ],
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({
    required this.title,
    required this.subtitle,
    this.leading,
  });

  final String title;
  final String subtitle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const CashPilotBrandMark(size: 88),
        const SizedBox(height: CPSpacing.lg),
        Text(
          AppLocalizations.of(context).appTitle,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: CPSpacing.lg),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: CPSpacing.md),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: CPSpacing.xxl),
        leading ?? const _SecurityIllustration(),
      ],
    );
  }
}

class _FormPanel extends StatelessWidget {
  const _FormPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CPCard(
      variant: CPCardVariant.elevated,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      padding: const EdgeInsetsDirectional.all(CPSpacing.xl),
      child: child,
    );
  }
}

class _SecurityIllustration extends StatelessWidget {
  const _SecurityIllustration();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surfaceContainerHigh,
            colorScheme.surfaceContainerLow,
          ],
        ),
        borderRadius: BorderRadius.circular(CPRadius.sm),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.72),
        ),
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            top: 28,
            start: 28,
            child: _MetricPill(
              icon: Icons.lock_outline_rounded,
              label: AppLocalizations.of(context).authSecureAccess,
            ),
          ),
          PositionedDirectional(
            bottom: 28,
            end: 28,
            child: _MetricPill(
              icon: Icons.verified_user_outlined,
              label: AppLocalizations.of(context).authVerifiedSession,
            ),
          ),
          Center(
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(CPRadius.sm),
              ),
              child: Icon(
                Icons.shield_rounded,
                color: colorScheme.onPrimary,
                size: 56,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: CPSpacing.md,
        vertical: CPSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(CPRadius.sm),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: CPSpacing.sm),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}
