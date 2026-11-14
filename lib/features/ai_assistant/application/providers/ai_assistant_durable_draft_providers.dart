import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ai_assistant_durable_draft_coordinator.dart';

final aiAssistantDurableDraftCoordinatorFactoryProvider =
    Provider<AiAssistantDurableDraftCoordinatorFactory>(
      (_) => const AiAssistantDurableDraftCoordinatorFactory(),
      name: 'aiAssistantDurableDraftCoordinatorFactoryProvider',
    );
