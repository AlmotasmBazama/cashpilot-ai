import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/presentation/widgets/finance_ui_components.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _ProductPolicyScreen(
      title: l10n.privacyPolicy,
      sections: [
        _PolicySection(
          title: l10n.privacyLocalDataTitle,
          body: l10n.privacyLocalDataMessage,
        ),
        _PolicySection(
          title: l10n.privacyCloudBackupTitle,
          body: l10n.privacyCloudBackupMessage,
        ),
        _PolicySection(title: l10n.privacyAiTitle, body: l10n.privacyAiMessage),
        _PolicySection(
          title: l10n.privacyDeletionTitle,
          body: l10n.privacyDeletionMessage,
        ),
      ],
    );
  }
}

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _ProductPolicyScreen(
      title: l10n.termsOfUse,
      sections: [
        _PolicySection(
          title: l10n.termsPersonalUseTitle,
          body: l10n.termsPersonalUseMessage,
        ),
        _PolicySection(
          title: l10n.termsFinancialInfoTitle,
          body: l10n.termsFinancialInfoMessage,
        ),
        _PolicySection(title: l10n.termsAiTitle, body: l10n.termsAiMessage),
        _PolicySection(
          title: l10n.termsAvailabilityTitle,
          body: l10n.termsAvailabilityMessage,
        ),
      ],
    );
  }
}

class _ProductPolicyScreen extends StatelessWidget {
  const _ProductPolicyScreen({required this.title, required this.sections});

  final String title;
  final List<_PolicySection> sections;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: CPAppBar(title: title),
      body: FinanceScreenBody(
        child: SelectionArea(
          child: ListView(
            children: [
              FinanceInfoCard(
                title: l10n.policyDraftNoticeTitle,
                message: l10n.policyDraftNoticeMessage,
                icon: Icons.info_outline_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: CPSpacing.xl),
              for (var index = 0; index < sections.length; index++) ...[
                FinanceSection(
                  title: sections[index].title,
                  child: Text(
                    sections[index].body,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),
                ),
                if (index != sections.length - 1)
                  const Padding(
                    padding: EdgeInsetsDirectional.symmetric(
                      vertical: CPSpacing.lg,
                    ),
                    child: Divider(),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicySection {
  const _PolicySection({required this.title, required this.body});

  final String title;
  final String body;
}
