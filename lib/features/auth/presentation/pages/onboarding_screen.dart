import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/accessibility/acceptance_semantics.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../application/providers/auth_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  var _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authControllerState = ref.watch(authControllerProvider);
    final isCompleting = authControllerState.isLoading;
    final pages = [
      _OnboardingItem(
        icon: Icons.account_balance_wallet_outlined,
        title: l10n.onboardingTrackTitle,
        message: l10n.onboardingTrackMessage,
      ),
      _OnboardingItem(
        icon: Icons.auto_awesome_outlined,
        title: l10n.onboardingAiTitle,
        message: l10n.onboardingAiMessage,
      ),
      _OnboardingItem(
        icon: Icons.query_stats_outlined,
        title: l10n.onboardingInsightsTitle,
        message: l10n.onboardingInsightsMessage,
      ),
    ];
    final isLast = _index == pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.all(CPSpacing.md),
              child: Row(
                children: [
                  const CPBrandMark(size: 44),
                  const Spacer(),
                  cashPilotForceStopAcceptanceSemantics(
                    identifier: 'cashpilot_acceptance_onboarding_skip',
                    child: TextButton(
                      onPressed: isCompleting ? null : _finish,
                      child: Text(l10n.skip),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (value) => setState(() => _index = value),
                itemCount: pages.length,
                itemBuilder: (context, index) =>
                    _OnboardingPage(item: pages[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.all(CPSpacing.lg),
              child: Column(
                children: [
                  _PageIndicators(count: pages.length, index: _index),
                  const SizedBox(height: CPSpacing.xl),
                  Row(
                    children: [
                      Expanded(
                        child: CPButton(
                          label: isLast ? l10n.getStarted : l10n.next,
                          icon: isLast
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                          size: CPButtonSize.large,
                          fullWidth: true,
                          isLoading: isCompleting,
                          onPressed: isCompleting
                              ? null
                              : isLast
                              ? _finish
                              : _next,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _next() {
    unawaited(
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _finish() {
    unawaited(ref.read(authControllerProvider.notifier).completeOnboarding());
  }
}

class _OnboardingItem {
  const _OnboardingItem({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.item});

  final _OnboardingItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 430;
        final illustrationSize = compact ? 156.0 : 210.0;
        final iconSize = compact ? 68.0 : 92.0;
        final gap = compact ? CPSpacing.lg : CPSpacing.xxl;
        final accent = item.icon == Icons.auto_awesome_outlined
            ? context.cpColors.ai
            : colorScheme.primary;

        return SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(CPSpacing.xl),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - (CPSpacing.xl * 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.92, end: 1),
                  duration: CPDurations.slow,
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) {
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: SizedBox(
                    width: illustrationSize,
                    height: illustrationSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: illustrationSize,
                          height: illustrationSize,
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
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.72,
                              ),
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          top: illustrationSize * 0.16,
                          start: illustrationSize * 0.16,
                          child: _IllustrationBar(
                            width: illustrationSize * 0.28,
                            color: accent,
                          ),
                        ),
                        PositionedDirectional(
                          bottom: illustrationSize * 0.18,
                          end: illustrationSize * 0.15,
                          child: _IllustrationBar(
                            width: illustrationSize * 0.36,
                            color: context.cpColors.transfer,
                          ),
                        ),
                        Container(
                          width: illustrationSize * 0.54,
                          height: illustrationSize * 0.54,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(CPRadius.sm),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.24),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.18),
                                blurRadius: 24,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: Icon(item.icon, size: iconSize, color: accent),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: gap),
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: CPSpacing.md),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Text(
                    item.message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PageIndicators extends StatelessWidget {
  const _PageIndicators({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: i == index ? 28 : 8,
            height: 8,
            margin: const EdgeInsetsDirectional.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: i == index
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(CPRadius.full),
            ),
          ),
      ],
    );
  }
}

class _IllustrationBar extends StatelessWidget {
  const _IllustrationBar({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 10,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(CPRadius.full),
      ),
    );
  }
}
