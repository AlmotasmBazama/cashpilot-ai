import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/sync/application/backup_operation_fence.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/domain/entities/category_classification_rule.dart';
import '../../../payees/domain/entities/payee.dart';
import '../entities/prepared_receipt_image.dart';
import '../entities/receipt_analysis_draft.dart';
import '../enums/duplicate_match_strength.dart';
import '../enums/receipt_draft_status.dart';
import '../enums/receipt_warning.dart';
import '../failures/receipt_failure_codes.dart';
import '../repositories/receipt_analysis_provider.dart';
import '../repositories/receipt_repository.dart';
import 'resolve_receipt_categories.dart';
import 'validate_receipt_analysis.dart';
import '../services/receipt_merchant_resolver.dart';

final class ReceiptAnalysisOperationCancelledException implements Exception {
  const ReceiptAnalysisOperationCancelledException();
}

class AnalyzeReceiptImageUseCase {
  AnalyzeReceiptImageUseCase({
    required ReceiptAnalysisProvider provider,
    required ReceiptRepository repository,
    required BackupOperationFence operationFence,
    required String boundOwnerScope,
    required bool Function() isOwnerScopeCurrent,
    ValidateReceiptAnalysisUseCase validate =
        const ValidateReceiptAnalysisUseCase(),
    ResolveReceiptCategoriesUseCase resolveCategories =
        const ResolveReceiptCategoriesUseCase(),
    ReceiptMerchantResolver resolveMerchant = const ReceiptMerchantResolver(),
  }) : _provider = provider,
       _repository = repository,
       _operationFence = operationFence,
       _boundOwnerScope = boundOwnerScope,
       _isOwnerScopeCurrent = isOwnerScopeCurrent,
       _validate = validate,
       _resolveCategories = resolveCategories,
       _resolveMerchant = resolveMerchant;

  final ReceiptAnalysisProvider _provider;
  final ReceiptRepository _repository;
  final BackupOperationFence _operationFence;
  final String _boundOwnerScope;
  final bool Function() _isOwnerScopeCurrent;
  final ValidateReceiptAnalysisUseCase _validate;
  final ResolveReceiptCategoriesUseCase _resolveCategories;
  final ReceiptMerchantResolver _resolveMerchant;
  final Set<String> _inFlight = <String>{};
  final Set<String> _completedImageKeys = <String>{};

  Future<AppResult<ReceiptAnalysisDraft>> call({
    required ReceiptAnalysisDraft draft,
    required PreparedReceiptImage image,
    required ReceiptAnalysisContext context,
    required List<Category> categories,
    List<CategoryClassificationRule> categoryRules =
        const <CategoryClassificationRule>[],
    List<Payee> payees = const <Payee>[],
    String? merchantDefaultCategoryId,
    bool Function()? isOperationCurrent,
    Future<void>? cancellationSignal,
  }) async {
    if (!_isOwnerScopeCurrent()) {
      throw const ReceiptAnalysisOperationCancelledException();
    }
    final writer = _operationFence.tryAcquireWriter(_boundOwnerScope);
    if (writer == null) {
      throw const ReceiptAnalysisOperationCancelledException();
    }
    final requestKey = '${draft.id}:${image.sha256}';
    var registeredInFlight = false;
    try {
      _assertOperationCurrent(writer, isOperationCurrent);
      if (_completedImageKeys.contains(requestKey)) {
        return const AppResult.failure(
          Failure(
            message: 'This identical receipt image was already analyzed.',
            code: ReceiptFailureCodes.duplicateAnalysis,
          ),
        );
      }
      if (!_inFlight.add(requestKey)) {
        return const AppResult.failure(
          Failure(
            message: 'Receipt analysis is already in progress.',
            code: ReceiptFailureCodes.analysisInProgress,
          ),
        );
      }
      registeredInFlight = true;
      _assertOperationCurrent(writer, isOperationCurrent);
      await _repository.updateAnalysisDraft(
        draft.copyWith(status: ReceiptDraftStatus.analyzing),
      );
      _assertOperationCurrent(writer, isOperationCurrent);
      final providerResult = _provider.analyzeReceipt(
        draftId: draft.id,
        image: image,
        context: context,
        assertEgressAllowed: () =>
            _assertOperationCurrent(writer, isOperationCurrent),
      );
      final extracted = cancellationSignal == null
          ? await providerResult
          : await Future.any<ReceiptAnalysisDraft>(
              <Future<ReceiptAnalysisDraft>>[
                providerResult,
                cancellationSignal.then<ReceiptAnalysisDraft>(
                  (_) =>
                      throw const ReceiptAnalysisOperationCancelledException(),
                ),
              ],
            );
      _assertOperationCurrent(writer, isOperationCurrent);
      final merchantResolved = _resolveMerchant.resolve(
        extracted.copyWith(
          imageHash: image.sha256,
          localImageReference: draft.localImageReference,
          imageRetentionChoice: draft.imageRetentionChoice,
        ),
        payees,
      );
      final resolvedMerchantDefault =
          merchantDefaultCategoryId ??
          payees
              .where(
                (payee) =>
                    payee.id == merchantResolved.merchantPayeeId &&
                    !payee.isArchived,
              )
              .firstOrNull
              ?.defaultCategoryId;
      final categorized = _resolveCategories(
        draft: merchantResolved,
        categories: categories,
        userRules: categoryRules,
        merchantDefaultCategoryId: resolvedMerchantDefault,
      );
      var validated = _validate(categorized).draft;
      _assertOperationCurrent(writer, isOperationCurrent);
      final duplicateResult = await _repository.findDuplicateCandidates(
        validated,
      );
      _assertOperationCurrent(writer, isOperationCurrent);
      if (duplicateResult case AppSuccess(
        :final data,
      ) when data.strength != DuplicateMatchStrength.noMatch) {
        validated = validated.copyWith(
          duplicateCandidateIds: data.candidateIds,
          warnings: <ReceiptWarning>{
            ...validated.warnings,
            ReceiptWarning.duplicatePossible,
          }.toList(growable: false),
          status: ReceiptDraftStatus.reviewRequired,
        );
      }
      _assertOperationCurrent(writer, isOperationCurrent);
      final saved = await _repository.updateAnalysisDraft(validated);
      _assertOperationCurrent(writer, isOperationCurrent);
      if (saved case AppSuccess()) {
        _assertOperationCurrent(writer, isOperationCurrent);
        _completedImageKeys.add(requestKey);
      }
      return saved;
    } on ReceiptAnalysisOperationCancelledException {
      rethrow;
    } on ReceiptException catch (error) {
      _assertOperationCurrent(writer, isOperationCurrent);
      await _repository.updateAnalysisDraft(
        draft.copyWith(status: ReceiptDraftStatus.failed),
      );
      _assertOperationCurrent(writer, isOperationCurrent);
      return AppResult.failure(
        Failure(message: error.safeMessage, code: error.code),
      );
    } on Object {
      _assertOperationCurrent(writer, isOperationCurrent);
      await _repository.updateAnalysisDraft(
        draft.copyWith(status: ReceiptDraftStatus.failed),
      );
      _assertOperationCurrent(writer, isOperationCurrent);
      return const AppResult.failure(
        Failure(
          message: 'Receipt analysis failed safely.',
          code: ReceiptFailureCodes.providerUnavailable,
        ),
      );
    } finally {
      if (registeredInFlight) {
        _inFlight.remove(requestKey);
      }
      writer.release();
    }
  }

  void _assertOperationCurrent(
    BackupWriterLease writer,
    bool Function()? isOperationCurrent,
  ) {
    try {
      writer.assertActive();
    } on BackupWriterCancelledException {
      throw const ReceiptAnalysisOperationCancelledException();
    }
    if (!_isOwnerScopeCurrent() ||
        (isOperationCurrent != null && !isOperationCurrent())) {
      throw const ReceiptAnalysisOperationCancelledException();
    }
  }
}
