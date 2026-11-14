import '../../../../shared/domain/currency/currency_catalog.dart';
import '../entities/ai_intent.dart';

class AiActionSafetyPolicy {
  const AiActionSafetyPolicy();

  AiIntent? destructiveIntentFor(String input) {
    final normalized = CurrencyCatalog.normalizeText(
      input,
    ).replaceAll(RegExp(r'[_-]+'), ' ').replaceAll(RegExp(r'\s+'), ' ');
    final compact = normalized.replaceAll(' ', '');

    if (_bypassConfirmationAliases.any(compact.contains) ||
        _balanceManipulationAliases.any(compact.contains)) {
      return AiIntent.resetData;
    }

    for (final entry in _destructiveAliases.entries) {
      if (entry.value.any(compact.contains)) {
        return entry.key;
      }
    }

    final deleteRequested =
        normalized.contains('delete') ||
        normalized.contains('remove') ||
        normalized.contains('erase') ||
        normalized.contains('wipe') ||
        normalized.contains('احذف') ||
        normalized.contains('حذف') ||
        normalized.contains('امسح') ||
        normalized.contains('مسح');
    if (!deleteRequested) {
      return null;
    }
    if (normalized.contains('all') ||
        normalized.contains('bulk') ||
        normalized.contains('كل')) {
      return AiIntent.bulkDelete;
    }
    if (normalized.contains('transaction') ||
        normalized.contains('معامل') ||
        normalized.contains('حرك')) {
      return AiIntent.deleteTransaction;
    }
    if (normalized.contains('account') || normalized.contains('حساب')) {
      return AiIntent.deleteAccount;
    }
    if (normalized.contains('category') ||
        normalized.contains('فئ') ||
        normalized.contains('تصنيف')) {
      return AiIntent.deleteCategory;
    }
    if (normalized.contains('payee')) {
      return AiIntent.deletePayee;
    }

    return null;
  }
}

const _bypassConfirmationAliases = <String>[
  'نفذبدونتاكيد',
  'نفذمنغيرتاكيد',
  'بدونتاكيد',
  'bypassconfirmation',
  'withoutconfirmation',
  'skipconfirmation',
];

const _balanceManipulationAliases = <String>[
  'غيررصيدي',
  'عدلرصيدي',
  'زدرصيدي',
  'اجعلرصيدي',
  'setmybalance',
  'changemybalance',
  'increasebalance',
];

const _destructiveAliases = <AiIntent, List<String>>{
  AiIntent.deleteAccount: <String>[
    'deleteaccount',
    'removeaccount',
    'حذفالحساب',
  ],
  AiIntent.deleteTransaction: <String>[
    'deletetransaction',
    'removetransaction',
    'حذفالمعامله',
    'حذفالحركه',
  ],
  AiIntent.deleteCategory: <String>[
    'deletecategory',
    'removecategory',
    'حذفالفئه',
    'حذفالتصنيف',
  ],
  AiIntent.deletePayee: <String>['deletepayee', 'removepayee', 'حذفالمستفيد'],
  AiIntent.bulkDelete: <String>[
    'bulkdelete',
    'deletealltransactions',
    'حذفالكل',
  ],
  AiIntent.resetData: <String>[
    'resetdata',
    'erasealldata',
    'wipealldata',
    'اعادهضبطالبيانات',
    'مسحالبيانات',
  ],
};
