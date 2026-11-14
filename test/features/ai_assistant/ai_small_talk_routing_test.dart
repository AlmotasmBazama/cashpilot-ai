import 'package:cashpilot_ai/features/ai_assistant/application/agent/general_assistant_policy.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_intent.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/ai_intent_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const router = AiIntentRouter();

  group('deterministic direct-conversation routing', () {
    final directCases = <(String, AiIntent)>[
      ('hello', AiIntent.greeting),
      ('hi', AiIntent.greeting),
      ('hey', AiIntent.greeting),
      ('good morning', AiIntent.greeting),
      ('good evening', AiIntent.greeting),
      ('how are you', AiIntent.smallTalk),
      ('how are u', AiIntent.smallTalk),
      ('how r u', AiIntent.smallTalk),
      ("how're you", AiIntent.smallTalk),
      ('what’s up', AiIntent.smallTalk),
      ('whats up', AiIntent.smallTalk),
      ('sup', AiIntent.smallTalk),
      ('u good', AiIntent.smallTalk),
      ('مرحبا', AiIntent.greeting),
      ('السلام عليكم', AiIntent.greeting),
      ('كيف حالك', AiIntent.smallTalk),
      ('كيفك', AiIntent.smallTalk),
      ('شلونك', AiIntent.smallTalk),
      ('شن حالك', AiIntent.smallTalk),
      ('شخبارك', AiIntent.smallTalk),
      ('شني أخبارك', AiIntent.smallTalk),
    ];

    for (final entry in directCases) {
      test('routes "${entry.$1}" locally', () {
        final route = router.route(entry.$1);

        expect(route.target, AssistantRouteTarget.directConversation);
        expect(route.intent, entry.$2);
        expect(route.isDeterministic, isTrue);
        expect(route.useFinancialPipeline, isFalse);
      });
    }

    test('normalizes case, apostrophes, whitespace, and punctuation', () {
      for (final message in <String>[
        '  HOW   ARE   U?!  ',
        'HOW’RE YOU!!!',
        "What's\tup...",
        'السَّلَامُ   عَلَيْكُمْ؟',
        'شني   أخبارك؟؟',
      ]) {
        expect(
          router.route(message).target,
          AssistantRouteTarget.directConversation,
          reason: message,
        );
      }
    });
  });

  group('substantive questions remain remote', () {
    for (final message in <String>[
      'How are interest rates calculated?',
      'How are budgets created?',
      'كيف يتم حساب الفائدة؟',
      'كيف نقدر ننظم مصاريف الشهر؟',
      'How are you calculating interest rates?',
      'كيف حالك، وكيف يتم حساب الفائدة؟',
    ]) {
      test('keeps "$message" on general conversation', () {
        final route = router.route(message);

        expect(route.target, AssistantRouteTarget.generalConversation);
        expect(route.intent, AiIntent.unknown);
        expect(route.isDeterministic, isFalse);
        expect(route.useFinancialPipeline, isFalse);
      });
    }
  });

  test('direct greeting and small-talk replies do not claim Groq was used', () {
    for (final locale in <String>['en', 'ar']) {
      for (final intent in <AiIntent>[AiIntent.greeting, AiIntent.smallTalk]) {
        final response = GeneralAssistantPolicy.localDirectReply(
          intent: intent,
          locale: locale,
        );

        expect(response.trim(), isNotEmpty);
        expect(response.toLowerCase(), isNot(contains('groq')));
      }
    }
  });
}
