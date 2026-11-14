import 'package:cashpilot_ai/features/ai_assistant/application/agent/financial_agent_tools.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/governed_ai_tool_registry.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/riverpod_financial_agent_data_gateway.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_tool_contracts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('get_category_spending gateway parity', () {
    test('definition requires a trimmed category bounded to 1..80', () {
      final tool = _categoryTool(_CapturingFinancialDataGateway());
      final category = tool.definition.arguments['category'];

      expect(category, isNotNull);
      expect(category!.required, isTrue);
      expect(category.trimWhitespace, isTrue);
      expect(category.minLength, 1);
      expect(category.maxLength, 80);
    });

    test('registry rejects missing, blank, and overlong categories', () async {
      final registry = _registry(_CapturingFinancialDataGateway());

      await _expectInvalid(registry, const <String, Object?>{});
      await _expectInvalid(registry, const <String, Object?>{'category': '  '});
      await _expectInvalid(registry, <String, Object?>{
        'category': List<String>.filled(81, 'a').join(),
      });
    });

    test(
      'registry accepts the 80-character boundary and trims for handler',
      () async {
        final gateway = _CapturingFinancialDataGateway();
        final registry = _registry(gateway);
        final boundary = List<String>.filled(80, 'a').join();

        await registry.execute(
          AiAgentToolCall(
            id: 'category-boundary',
            name: 'get_category_spending',
            arguments: <String, Object?>{'category': '  $boundary  '},
          ),
          _context,
        );

        expect(gateway.lastArguments, <String, Object?>{'category': boundary});
      },
    );

    test('data handler independently rejects a missing category', () async {
      final provider = Provider<RiverpodFinancialAgentDataGateway>(
        (ref) => RiverpodFinancialAgentDataGateway(
          ref,
          boundOwnerScope: _ownerScope,
          currentOwnerScope: () => _ownerScope,
        ),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(provider)
            .executeReadTool(
              'get_category_spending',
              const <String, Object?>{},
              _context,
            ),
        throwsA(
          isA<AiToolFailure>().having(
            (failure) => failure.code,
            'code',
            'invalid_arguments',
          ),
        ),
      );
    });
  });
}

final AiToolExecutionContext _context = AiToolExecutionContext(
  locale: 'en',
  baseCurrencyCode: 'LYD',
  now: DateTime.utc(2026, 7, 31),
  maxSearchResults: 20,
  ownerScope: _ownerScope,
  financialDataScopeVerified: true,
);

const _ownerScope = AiToolOwnerScopeBinding(
  accountScope:
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  epoch: 1,
);

RegisteredAiTool _categoryTool(FinancialAgentDataGateway gateway) =>
    FinancialAgentToolCatalog(gateway)
        .build(draftEnabled: false, navigationEnabled: false)
        .singleWhere((tool) => tool.definition.name == 'get_category_spending');

GovernedAiToolRegistry _registry(FinancialAgentDataGateway gateway) =>
    GovernedAiToolRegistry(
      tools: <RegisteredAiTool>[_categoryTool(gateway)],
      permissionPolicy: const DefaultAiToolPermissionPolicy(),
      currentOwnerScope: () => _ownerScope,
    );

Future<void> _expectInvalid(
  GovernedAiToolRegistry registry,
  Map<String, Object?> arguments,
) => expectLater(
  registry.execute(
    AiAgentToolCall(
      id: 'category-invalid',
      name: 'get_category_spending',
      arguments: arguments,
    ),
    _context,
  ),
  throwsA(
    isA<AiToolFailure>().having(
      (failure) => failure.code,
      'code',
      'invalid_arguments',
    ),
  ),
);

class _CapturingFinancialDataGateway implements FinancialAgentDataGateway {
  Map<String, Object?>? lastArguments;

  @override
  Future<AiToolResult> executeReadTool(
    String name,
    Map<String, Object?> arguments,
    AiToolExecutionContext context,
  ) async {
    lastArguments = arguments;
    return AiToolResult(
      toolName: name,
      data: const <String, Object?>{'categories': <Object?>[]},
    );
  }
}
