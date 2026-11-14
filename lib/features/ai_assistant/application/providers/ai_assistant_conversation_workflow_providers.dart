import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ai_assistant_conversation_workflow_controller.dart';

final aiAssistantConversationWorkflowControllerFactoryProvider =
    Provider<AiAssistantConversationWorkflowControllerFactory>(
      (_) => const AiAssistantConversationWorkflowControllerFactory(),
      name: 'aiAssistantConversationWorkflowControllerFactoryProvider',
    );
