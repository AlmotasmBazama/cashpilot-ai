import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ai_assistant_send_lifecycle_coordinator.dart';

final aiAssistantSendLifecycleCoordinatorFactoryProvider =
    Provider<AiAssistantSendLifecycleCoordinatorFactory>(
      (_) => const AiAssistantSendLifecycleCoordinatorFactory(),
      name: 'aiAssistantSendLifecycleCoordinatorFactoryProvider',
    );
