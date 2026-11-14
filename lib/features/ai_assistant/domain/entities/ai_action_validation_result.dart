import 'ai_action.dart';

enum AiActionValidationStatus { valid, invalid, needsClarification }

class AiActionValidationResult {
  const AiActionValidationResult._({
    required this.status,
    this.action,
    this.message,
  });

  final AiActionValidationStatus status;
  final AiAction? action;
  final String? message;

  bool get isValid => status == AiActionValidationStatus.valid;

  const factory AiActionValidationResult.valid(AiAction action) =
      AiActionValidationValid;

  const factory AiActionValidationResult.invalid(String message) =
      AiActionValidationInvalid;

  const factory AiActionValidationResult.needsClarification(String message) =
      AiActionValidationNeedsClarification;
}

class AiActionValidationValid extends AiActionValidationResult {
  const AiActionValidationValid(AiAction action)
    : super._(status: AiActionValidationStatus.valid, action: action);
}

class AiActionValidationInvalid extends AiActionValidationResult {
  const AiActionValidationInvalid(String message)
    : super._(status: AiActionValidationStatus.invalid, message: message);
}

class AiActionValidationNeedsClarification extends AiActionValidationResult {
  const AiActionValidationNeedsClarification(String message)
    : super._(
        status: AiActionValidationStatus.needsClarification,
        message: message,
      );
}
