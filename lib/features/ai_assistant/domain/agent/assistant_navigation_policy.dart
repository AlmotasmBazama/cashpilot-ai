import 'ai_agent_models.dart';

class AssistantNavigationRequest {
  const AssistantNavigationRequest({
    required this.toolName,
    required this.path,
  });

  final String toolName;
  final String path;
}

/// Deterministic, local policy for the assistant's non-financial navigation.
///
/// Model output cannot create or widen this allowlist. A request must contain
/// both an explicit navigation verb and a known destination.
class AssistantNavigationPolicy {
  const AssistantNavigationPolicy();

  static const Map<String, String> approvedToolPaths = <String, String>{
    'navigate_dashboard': '/dashboard',
    'navigate_accounts': '/accounts',
    'navigate_transactions': '/transactions',
    'navigate_reports': '/reports',
    'navigate_budgets': '/budgets',
    'navigate_goals': '/goals',
    'navigate_payees': '/payees',
    'navigate_receipt_scanner': '/receipts/scan',
  };

  AssistantNavigationRequest? classify(String input) {
    final normalized = _normalize(input);
    if (!_hasExplicitNavigationVerb(normalized)) {
      return null;
    }
    for (final entry in _destinationTerms.entries) {
      if (entry.value.any(normalized.contains)) {
        final path = approvedToolPaths[entry.key];
        if (path != null) {
          return AssistantNavigationRequest(toolName: entry.key, path: path);
        }
      }
    }
    return null;
  }

  static bool isApprovedResponse({
    required bool isAppNavigationRoute,
    required String? selectedToolName,
    required AiAgentResponse? response,
  }) {
    if (!isAppNavigationRoute ||
        selectedToolName == null ||
        response == null ||
        response.kind != AiAgentResponseKind.navigation ||
        response.turnKind != AssistantTurnKind.appNavigation ||
        !response.executedToolNames.contains(selectedToolName)) {
      return false;
    }
    final approvedPath = approvedToolPaths[selectedToolName];
    return approvedPath != null && response.navigationPath == approvedPath;
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), ' ')
        .trim();
  }

  static bool _hasExplicitNavigationVerb(String value) {
    return _navigationVerbs.any(
      (verb) =>
          value == verb ||
          value.startsWith('$verb ') ||
          value.contains(' $verb '),
    );
  }

  static const List<String> _navigationVerbs = <String>[
    'open',
    'go to',
    'take me to',
    'navigate to',
    'show me the',
    'افتح',
    'اذهب الى',
    'اذهب إلى',
    'وديني',
    'خذني الى',
    'خذني إلى',
  ];

  static const Map<String, List<String>>
  _destinationTerms = <String, List<String>>{
    'navigate_dashboard': <String>[
      'dashboard',
      'home screen',
      'الرييسية',
      'الرئيسية',
      'لوحة التحكم',
    ],
    'navigate_accounts': <String>['accounts', 'accounts screen', 'الحسابات'],
    'navigate_transactions': <String>[
      'transactions',
      'transactions screen',
      'المعاملات',
      'الحركات',
    ],
    'navigate_reports': <String>['reports', 'reports screen', 'التقارير'],
    'navigate_budgets': <String>['budgets', 'budgets screen', 'الميزانيات'],
    'navigate_goals': <String>['goals', 'goals screen', 'الاهداف', 'الأهداف'],
    'navigate_payees': <String>['payees', 'payees screen', 'المستفيدين'],
    'navigate_receipt_scanner': <String>[
      'receipt scanner',
      'scan receipt',
      'ماسح الايصال',
      'ماسح الإيصال',
      'مسح الايصال',
      'مسح الإيصال',
    ],
  };
}
