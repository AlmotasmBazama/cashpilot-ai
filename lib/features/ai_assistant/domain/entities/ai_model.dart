import 'ai_capability.dart';
import 'ai_provider_type.dart';

class AiModel {
  AiModel({
    required this.id,
    required this.providerType,
    required this.displayName,
    required List<AiCapability> capabilities,
    required this.isDefault,
    this.maxInputTokens,
  }) : capabilities = List.unmodifiable(capabilities);

  final String id;
  final AiProviderType providerType;
  final String displayName;
  final List<AiCapability> capabilities;
  final bool isDefault;
  final int? maxInputTokens;

  bool supports(AiCapability capability) => capabilities.contains(capability);
}
