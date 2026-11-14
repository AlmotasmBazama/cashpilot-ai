// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get aiUnsupportedPromptMessage =>
      'ما قدرتش نكمّل الطلب. جرّب تعيد صياغته أو اسأل سؤالاً آمناً آخر.';

  @override
  String get aiGreetingResponse =>
      'أهلاً بيك! كيف نقدر نساعدك اليوم؟ تقدر تسألني سؤال عام، أو تخلّيني نراجع مصروفاتك، أو نسجّل معاملة جديدة.';

  @override
  String get aiSmallTalkResponse =>
      'تمام، شكراً لسؤالك! شن نقدر نساعدك فيه اليوم؟';

  @override
  String get aiHelpResponse =>
      'اسأل أي سؤال عام وآمن، أو اطلب معلومات حديثة مع مصادر، أو خلّيني نراجع بياناتك في CashPilot، أو صف إجراءً مالياً. أي تغيير مالي يبقى للمراجعة والتأكيد أولاً.';

  @override
  String get aiCapabilitiesResponse =>
      'نقدر نجاوب عن أسئلة عامة ونشرح المفاهيم، ونبحث عن معلومات حديثة مع مصادر، ونحلّل بياناتك في CashPilot، ونجهّز مسودات للمعاملات والميزانيات والأهداف.';

  @override
  String get aiUnsupportedConversationResponse =>
      'ما قدرتش نكمّل الطلب، لكن تقدر تعيد صياغته أو تسأل سؤالاً آمناً آخر.';

  @override
  String get aiDestructiveRequestBlockedResponse =>
      'لا أستطيع حذف السجلات المالية أو تغيير الأرصدة مباشرة أو تجاوز التأكيد. نقدر نساعدك نجهز إجراء آمن تراجعه أولًا.';

  @override
  String get aiAssistantResponseTitle => 'مساعد CashPilot';

  @override
  String get aiFinancialQuestionLocalResponse =>
      'فهمت هذا كسؤال مالي وليس كمعاملة. يجيب CashPilot عن الإجماليات والميزانيات والأهداف وتحويل العملات المدعومة من البيانات المحلية من غير إرسال سجل المعاملات إلى Gemini. أضف الفترة أو التصنيف إذا تبي إجابة أدق.';

  @override
  String get aiSearchingCurrentInformation => 'نبحث عن معلومات حديثة…';

  @override
  String get aiSources => 'المصادر';

  @override
  String get aiUpdatedAsOf => 'محدّث حتى';

  @override
  String get aiUnableVerifyCurrent => 'تعذّر التحقق من معلومات حديثة.';

  @override
  String get aiReviewingYourData => 'نراجع بياناتك…';

  @override
  String get aiComparingPeriods => 'نقارن بين الفترات…';

  @override
  String get aiPreparingDraft => 'نجهّز مسودة للمراجعة…';

  @override
  String get aiGeneralUnavailable =>
      'المساعد العام غير متاح مؤقتاً. جرّب مرة ثانية بعد قليل.';

  @override
  String get aiGroundedAnswer => 'إجابة حديثة موثّقة';

  @override
  String get aiJumpToLatest => 'الانتقال لآخر رسالة';

  @override
  String get aiStopGenerating => 'إيقاف التوليد';

  @override
  String get aiCopyResponse => 'نسخ الرد';

  @override
  String get aiRetryResponse => 'إعادة المحاولة';

  @override
  String get aiNewConversation => 'محادثة جديدة';

  @override
  String get aiClearConversation => 'مسح المحادثة';

  @override
  String get aiClearConversationConfirmation =>
      'هل تريد مسح كل الرسائل في هذه المحادثة؟ لا يمكن التراجع عن ذلك.';

  @override
  String get aiCurrentInfoMayChange =>
      'المعلومات الحالية قد تتغيّر؛ راجع المصادر المرفقة.';

  @override
  String get aiDraftToolsUnavailable =>
      'تعذّر تجهيز مسودة الإجراء مؤقتاً. لم يتم تنفيذ أي تغيير مالي.';

  @override
  String get aiAskAnotherQuestion => 'اسأل سؤالاً آخر';

  @override
  String get aiSelectDestinationAccount => 'اختر الحساب الذي استلم هذا الدخل';

  @override
  String get aiEvidenceCurrentMonth =>
      'بناءً على بيانات هذا الشهر في CashPilot';

  @override
  String get aiEvidenceComparedPrior => 'مقارنةً بالشهر الماضي';

  @override
  String get aiSearchEntryUnavailable =>
      'اقتراحات المتابعة من Google Search غير متاحة على هذه المنصة.';

  @override
  String get promptWhatIsInflation => 'ما هو التضخم؟';

  @override
  String get promptCurrentLibyaEconomy => 'كيف وضع الاقتصاد الليبي حالياً؟';

  @override
  String get appTitle => 'كاش بايلوت AI';

  @override
  String get homeHeadline => 'مساحة العمل المالية';

  @override
  String get homeSubtitle => 'وحداتك المالية جاهزة للبناء.';

  @override
  String get navDashboard => 'الرئيسية';

  @override
  String get secureLocalFirst => 'أساس محلي آمن للبيانات المالية';

  @override
  String get accountsTitle => 'الحسابات';

  @override
  String get accountsSubtitle => 'الأرصدة والمحافظ المرتبطة';

  @override
  String get accountsScreenTitle => 'الحسابات';

  @override
  String get accountsScreenSubtitle =>
      'تابع الأرصدة عبر النقد والبطاقات والبنوك والمحافظ.';

  @override
  String get activeAccountsLabel => 'نشطة';

  @override
  String get archivedAccountsLabel => 'مؤرشفة';

  @override
  String get trackedCurrenciesLabel => 'العملات';

  @override
  String get archivedAccountLabel => 'مؤرشف';

  @override
  String get moreActions => 'مزيد من الإجراءات';

  @override
  String get addAccount => 'إضافة حساب';

  @override
  String get editAccount => 'تعديل الحساب';

  @override
  String get deleteAccount => 'حذف الحساب';

  @override
  String get archiveAccount => 'أرشفة الحساب';

  @override
  String get accountName => 'اسم الحساب';

  @override
  String get accountType => 'نوع الحساب';

  @override
  String get accountTypeCash => 'نقد';

  @override
  String get accountTypeBank => 'حساب بنكي';

  @override
  String get accountTypeCreditCard => 'بطاقة ائتمان';

  @override
  String get accountTypeDebitCard => 'بطاقة خصم';

  @override
  String get accountTypeSavings => 'ادخار';

  @override
  String get accountTypeInvestment => 'استثمار';

  @override
  String get accountTypeDigitalWallet => 'محفظة إلكترونية';

  @override
  String get accountTypeCrypto => 'عملات رقمية';

  @override
  String get accountTypeOther => 'أخرى';

  @override
  String get currencyCode => 'العملة';

  @override
  String get accountCurrencyLockedMessage =>
      'لا يمكن تغيير العملة بعد إنشاء الحساب حتى تبقى الأرصدة والسجل المالي دقيقين.';

  @override
  String get openingBalance => 'الرصيد الافتتاحي';

  @override
  String get accountBalance => 'الرصيد';

  @override
  String get accountIcon => 'الأيقونة';

  @override
  String get accountColor => 'اللون';

  @override
  String get accountPaymentMethods => 'طرق الدفع';

  @override
  String get accountPaymentMethodsHint =>
      'اربط خدمات الدفع الليبية التابعة لهذا الحساب.';

  @override
  String get accountNameRequired => 'اسم الحساب مطلوب.';

  @override
  String get invalidAmount => 'أدخل مبلغًا صالحًا.';

  @override
  String get invalidCurrencyCode => 'استخدم رمز عملة من 3 أحرف.';

  @override
  String get selectAccountType => 'اختر نوع الحساب';

  @override
  String get emptyAccountsTitle => 'لا توجد حسابات بعد';

  @override
  String get emptyAccountsMessage => 'أضف حسابك الأول لبدء متابعة الأرصدة.';

  @override
  String get accountsErrorTitle => 'تعذر تحميل الحسابات';

  @override
  String get accountsErrorMessage => 'قم بتحديث الصفحة أو حاول لاحقا.';

  @override
  String get accountCreatedMessage => 'تم إنشاء الحساب.';

  @override
  String get accountUpdatedMessage => 'تم تحديث الحساب.';

  @override
  String get accountArchivedMessage => 'تمت أرشفة الحساب.';

  @override
  String get accountDeletedMessage => 'تم حذف الحساب.';

  @override
  String get deleteAccountTitle => 'حذف الحساب؟';

  @override
  String get deleteAccountMessage => 'لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get accountDetailsTitle => 'تفاصيل الحساب';

  @override
  String get accountDetailsPlaceholder =>
      'النشاط التفصيلي وأدوات التحكم الخاصة بهذا الحساب.';

  @override
  String get accountNotFound => 'الحساب غير موجود';

  @override
  String get accountsPreview => 'معاينة الحسابات';

  @override
  String get accountStatisticsSubtitle => 'اتجاه النشاط خلال آخر ستة أشهر.';

  @override
  String get transactionsTitle => 'المعاملات';

  @override
  String get transactionsSubtitle => 'التدفق النقدي والتصنيف';

  @override
  String get transactionsErrorTitle => 'تعذر تحميل المعاملات';

  @override
  String get transactionsErrorMessage => 'قم بتحديث الصفحة أو حاول لاحقا.';

  @override
  String get emptyTransactionsTitle => 'لا توجد معاملات بعد';

  @override
  String get emptyTransactionsMessage =>
      'ستظهر المعاملات هنا بعد إضافة دخل أو مصروف.';

  @override
  String get searchTransactions => 'بحث في المعاملات';

  @override
  String get loadMoreTransactions => 'تحميل معاملات إضافية';

  @override
  String transactionsLoadedCount(int loaded, int total) {
    return '$loaded من $total';
  }

  @override
  String get addExpense => 'إضافة مصروف';

  @override
  String get addIncome => 'إضافة دخل';

  @override
  String get editTransaction => 'تعديل المعاملة';

  @override
  String get transactionCreatedMessage => 'تم إنشاء المعاملة.';

  @override
  String get transactionUpdatedMessage => 'تم تحديث المعاملة.';

  @override
  String get pendingTransactionEditHint =>
      'لا تؤثر المعاملة المعلّقة في أرصدة الحسابات حتى يتم ترحيلها.';

  @override
  String get postedTransactionEditHint =>
      'عند الحفظ يُعكس أثر الرصيد السابق ثم تُطبق القيم المعدلة مرة واحدة فقط.';

  @override
  String get transactionPrerequisitesTitle => 'الحسابات والتصنيفات مطلوبة';

  @override
  String get transactionPrerequisitesMessage =>
      'أنشئ حسابًا واحدًا وتصنيفًا مناسبًا على الأقل قبل إضافة معاملة.';

  @override
  String get transactionDetails => 'تفاصيل المعاملة';

  @override
  String get transactionNotFound => 'المعاملة غير موجودة';

  @override
  String get deleteTransactionTitle => 'حذف المعاملة؟';

  @override
  String get deleteTransactionMessage =>
      'سيؤدي حذف معاملة منشورة إلى عكس تأثيرها على الرصيد.';

  @override
  String get category => 'التصنيف';

  @override
  String get categoryTypeExpense => 'مصروف';

  @override
  String get categoryTypeIncome => 'دخل';

  @override
  String get categoryTypeTransfer => 'تحويل';

  @override
  String get amount => 'المبلغ';

  @override
  String get paymentMethod => 'طريقة الدفع';

  @override
  String get paymentMethodCash => 'نقد';

  @override
  String get paymentMethodDebitCard => 'بطاقة خصم';

  @override
  String get paymentMethodCreditCard => 'بطاقة ائتمان';

  @override
  String get paymentMethodBankTransfer => 'تحويل بنكي';

  @override
  String get paymentMethodDigitalWallet => 'محفظة إلكترونية';

  @override
  String get paymentMethodEdfaly => 'ادفع لي';

  @override
  String get paymentMethodMasrafiPay => 'مصرفي';

  @override
  String get paymentMethodMobiCash => 'موبي كاش';

  @override
  String get paymentMethodYusrPay => 'يسر';

  @override
  String get paymentMethodCheck => 'صك';

  @override
  String get paymentMethodCrypto => 'عملات رقمية';

  @override
  String get paymentMethodOther => 'أخرى';

  @override
  String get status => 'الحالة';

  @override
  String get transactionStatusPosted => 'مرحّلة';

  @override
  String get transactionStatusPending => 'معلّقة';

  @override
  String get transactionStatusCancelled => 'ملغاة';

  @override
  String get transactionStatusFailed => 'فشلت';

  @override
  String get transactionTypeExpense => 'مصروف';

  @override
  String get transactionTypeIncome => 'دخل';

  @override
  String get transactionTypeTransferOut => 'تحويل صادر';

  @override
  String get transactionTypeTransferIn => 'تحويل وارد';

  @override
  String get transactionDate => 'تاريخ المعاملة';

  @override
  String get note => 'ملاحظة';

  @override
  String get location => 'الموقع';

  @override
  String get source => 'المصدر';

  @override
  String get transactionSourceManual => 'إدخال يدوي';

  @override
  String get transactionSourceImported => 'مستوردة';

  @override
  String get transactionSourceRecurring => 'متكررة';

  @override
  String get transactionSourceAiGenerated => 'من المساعد الذكي';

  @override
  String get transactionSourceCloudSync => 'مزامنة سحابية';

  @override
  String get transactionSourceSystem => 'النظام';

  @override
  String get aiReview => 'مراجعة الذكاء الاصطناعي';

  @override
  String get aiReviewNeeded => 'هذه المعاملة محددة للمراجعة.';

  @override
  String get aiReviewNotNeeded => 'لا توجد حاجة لمراجعة الذكاء الاصطناعي.';

  @override
  String get categoriesTitle => 'التصنيفات';

  @override
  String get categoriesSubtitle => 'نظم الدخل والمصروفات والتحويلات.';

  @override
  String get createCategory => 'إنشاء تصنيف';

  @override
  String get editCategory => 'تعديل التصنيف';

  @override
  String get categoryName => 'اسم التصنيف';

  @override
  String get categoryNameRequired => 'اسم التصنيف مطلوب.';

  @override
  String get parentCategory => 'التصنيف الأب';

  @override
  String get noParentCategory => 'بدون تصنيف أب';

  @override
  String get categoriesErrorTitle => 'تعذر تحميل التصنيفات';

  @override
  String get categoriesErrorMessage => 'قم بتحديث الصفحة أو حاول لاحقا.';

  @override
  String get emptyCategoriesTitle => 'لا توجد تصنيفات بعد';

  @override
  String get emptyCategoriesMessage =>
      'ستظهر التصنيفات الافتراضية والمخصصة هنا.';

  @override
  String get defaultCategory => 'افتراضي';

  @override
  String get categoryNameFood => 'طعام';

  @override
  String get categoryNameCoffee => 'قهوة';

  @override
  String get categoryNameRestaurant => 'مطاعم';

  @override
  String get categoryNameTransport => 'مواصلات';

  @override
  String get categoryNameTaxi => 'تاكسي';

  @override
  String get categoryNameFuel => 'وقود';

  @override
  String get categoryNameShopping => 'تسوّق';

  @override
  String get categoryNameGroceries => 'بقالة ومواد غذائية';

  @override
  String get categoryNameEntertainment => 'ترفيه';

  @override
  String get categoryNameGaming => 'ألعاب';

  @override
  String get categoryNameTravel => 'سفر';

  @override
  String get categoryNameHotel => 'فنادق';

  @override
  String get categoryNameBills => 'فواتير';

  @override
  String get categoryNameInternet => 'إنترنت';

  @override
  String get categoryNamePhone => 'هاتف';

  @override
  String get categoryNameRent => 'إيجار';

  @override
  String get categoryNameInsurance => 'تأمين';

  @override
  String get categoryNameHealthcare => 'رعاية صحية';

  @override
  String get categoryNamePharmacy => 'صيدلية';

  @override
  String get categoryNameEducation => 'تعليم';

  @override
  String get categoryNameSubscription => 'اشتراكات';

  @override
  String get categoryNameElectronics => 'إلكترونيات';

  @override
  String get categoryNamePets => 'حيوانات أليفة';

  @override
  String get categoryNameCharity => 'تبرعات';

  @override
  String get categoryNameTaxes => 'ضرائب';

  @override
  String get categoryNameGift => 'هدايا';

  @override
  String get categoryNameClothing => 'ملابس';

  @override
  String get categoryNameSports => 'رياضة';

  @override
  String get categoryNameBeauty => 'عناية وجمال';

  @override
  String get categoryNameHome => 'المنزل';

  @override
  String get categoryNameSalary => 'راتب';

  @override
  String get categoryNameFreelance => 'عمل حر';

  @override
  String get categoryNameBonus => 'مكافأة';

  @override
  String get categoryNameInvestment => 'استثمار';

  @override
  String get categoryNameRefund => 'استرداد';

  @override
  String get categoryNameCashback => 'استرجاع نقدي';

  @override
  String get categoryNameRentalIncome => 'دخل إيجار';

  @override
  String get categoryNameInterest => 'فوائد';

  @override
  String get categoryNameOtherIncome => 'دخل آخر';

  @override
  String get categoryNameBusinessRevenue => 'إيراد أعمال';

  @override
  String get categoryNameAllowance => 'مصروف شخصي';

  @override
  String get categoryNameReimbursement => 'تعويض مصروف';

  @override
  String get categoryNameSaleProceeds => 'عائد بيع';

  @override
  String get categoryNameGovernmentSupport => 'دعم حكومي';

  @override
  String get categoryNameScholarship => 'منحة دراسية';

  @override
  String get categoryNamePrize => 'جائزة';

  @override
  String get categoryNameLoanProceeds => 'متحصلات قرض';

  @override
  String get categoryNameTransfer => 'تحويل';

  @override
  String get payeesTitle => 'المستفيدون';

  @override
  String get payeesSubtitle => 'إدارة الأشخاص والتجار وجهات العمل والخدمات.';

  @override
  String get payeesErrorTitle => 'تعذر تحميل المستفيدين';

  @override
  String get searchPayees => 'بحث في المستفيدين';

  @override
  String get emptyPayeesTitle => 'لا يوجد مستفيدون بعد';

  @override
  String get emptyPayeesMessage =>
      'أضف مستفيدًا لتحسين إدخال المعاملات والمطابقة بالذكاء الاصطناعي.';

  @override
  String get payeeDetails => 'تفاصيل المستفيد';

  @override
  String get payeeDetailsMessage =>
      'تجعل القيم الافتراضية والأسماء البديلة إدخال المعاملات أسرع وأكثر دقة.';

  @override
  String payeeTransactionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count معاملات',
      one: 'معاملة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get budgetsTitle => 'الميزانيات';

  @override
  String get budgetsSubtitle => 'الخطط وحدود الإنفاق';

  @override
  String get budgetProgress => 'تقدم الميزانية';

  @override
  String get budgetProgressPending =>
      'ضع حدودًا شهرية لمتابعة وتيرة الصرف وضغط التصنيفات هنا.';

  @override
  String get budgetBackendPendingTitle => 'مركز متابعة الميزانية';

  @override
  String get budgetBackendPendingMessage =>
      'خطط حدود الصرف، راقب وتيرة الإنفاق، واجعل التنبيهات المهمة واضحة في مساحة واحدة.';

  @override
  String get createBudget => 'إنشاء ميزانية';

  @override
  String get activeBudgets => 'الميزانيات النشطة';

  @override
  String get remainingBudget => 'المتبقي من الميزانية';

  @override
  String get budgetAlerts => 'تنبيهات الميزانية';

  @override
  String get emptyBudgetsTitle => 'لا توجد ميزانيات بعد';

  @override
  String get emptyBudgetsMessage =>
      'ستظهر بطاقات الميزانية هنا عندما تبدأ بتحديد حدود الإنفاق.';

  @override
  String get addBudget => 'إضافة ميزانية';

  @override
  String get editBudget => 'تعديل الميزانية';

  @override
  String get archiveBudget => 'أرشفة الميزانية';

  @override
  String get restoreBudget => 'استعادة الميزانية';

  @override
  String get budgetName => 'اسم الميزانية';

  @override
  String get budgetAmount => 'مبلغ الميزانية';

  @override
  String get budgetPeriod => 'فترة الميزانية';

  @override
  String get weekly => 'أسبوعية';

  @override
  String get monthly => 'شهرية';

  @override
  String get yearly => 'سنوية';

  @override
  String get customPeriod => 'فترة مخصصة';

  @override
  String get alertThreshold => 'حد التنبيه';

  @override
  String get spent => 'المصروف';

  @override
  String get remaining => 'المتبقي';

  @override
  String get onTrack => 'ضمن الخطة';

  @override
  String get nearLimit => 'قريبة من الحد';

  @override
  String get exceeded => 'تم تجاوزها';

  @override
  String get inactive => 'غير نشطة';

  @override
  String get createYourFirstBudget =>
      'أنشئ ميزانيتك الأولى لمتابعة حد الإنفاق على أحد التصنيفات.';

  @override
  String get budgetSaved => 'تم حفظ الميزانية.';

  @override
  String get budgetArchived => 'تمت أرشفة الميزانية.';

  @override
  String get budgetRestored => 'تمت استعادة الميزانية.';

  @override
  String get invalidBudgetAmount => 'أدخل مبلغ ميزانية أكبر من صفر.';

  @override
  String get selectCategory => 'اختر تصنيفًا.';

  @override
  String get budgetPeriodInvalid => 'اختر تاريخ بداية ونهاية صالحين.';

  @override
  String get budgetMissingExchangeRate =>
      'هذا التقدم جزئي بسبب فقدان سعر صرف مطلوب.';

  @override
  String get includeArchivedBudgets => 'إظهار الميزانيات المؤرشفة';

  @override
  String get budgetDetails => 'تفاصيل الميزانية';

  @override
  String get budgetStartDate => 'تاريخ البداية';

  @override
  String get budgetEndDate => 'تاريخ النهاية';

  @override
  String get budgetArchiveConfirm =>
      'لن تظهر الميزانيات المؤرشفة ضمن ملخصات التخطيط النشطة.';

  @override
  String get budgetsLoadError => 'تعذر تحميل الميزانيات';

  @override
  String get budgetsLoadErrorMessage =>
      'لا تزال ميزانياتك محفوظة بأمان. حاول تحميلها مجددًا.';

  @override
  String get budgetSaveError => 'تعذر حفظ الميزانية.';

  @override
  String get goalsTitle => 'الأهداف';

  @override
  String get goalsSubtitle => 'أهداف الادخار والمراحل';

  @override
  String get goalsProgress => 'تقدم الأهداف';

  @override
  String get goalsProgressPending =>
      'أنشئ أهدافًا لمتابعة المراحل والمبالغ المدخرة وتقدم خطتك.';

  @override
  String get goalsBackendPendingTitle => 'مساحة تخطيط الأهداف';

  @override
  String get goalsBackendPendingMessage =>
      'حدد أهداف الادخار، تابع المراحل، واحتفظ بخططك طويلة المدى أمامك بوضوح.';

  @override
  String get createGoal => 'إنشاء هدف';

  @override
  String get activeGoals => 'الأهداف النشطة';

  @override
  String get savedForGoals => 'مدخر للأهداف';

  @override
  String get goalMilestones => 'المراحل';

  @override
  String get emptyGoalsTitle => 'لا توجد أهداف بعد';

  @override
  String get emptyGoalsMessage =>
      'ستظهر أهداف الادخار هنا عندما تبدأ بتخطيط هدف جديد.';

  @override
  String get addGoal => 'إضافة هدف';

  @override
  String get editGoal => 'تعديل الهدف';

  @override
  String get archiveGoal => 'أرشفة الهدف';

  @override
  String get restoreGoal => 'استعادة الهدف';

  @override
  String get goalTitle => 'عنوان الهدف';

  @override
  String get goalDescription => 'الوصف';

  @override
  String get goalType => 'نوع الهدف';

  @override
  String get targetAmount => 'المبلغ المستهدف';

  @override
  String get currentAmount => 'المبلغ الحالي';

  @override
  String get targetDate => 'تاريخ الوصول';

  @override
  String get clearTargetDate => 'إزالة تاريخ الوصول';

  @override
  String get contribution => 'مساهمة';

  @override
  String get addContribution => 'إضافة مساهمة';

  @override
  String get contributionHistory => 'سجل المساهمات';

  @override
  String get savingsGoal => 'هدف ادخار';

  @override
  String get emergencyFund => 'صندوق طوارئ';

  @override
  String get debtPayoff => 'سداد دين';

  @override
  String get purchaseGoal => 'هدف شراء';

  @override
  String get customGoal => 'هدف مخصص';

  @override
  String get goalStatusActive => 'نشط';

  @override
  String get goalStatusCompleted => 'مكتمل';

  @override
  String get goalStatusPaused => 'متوقف مؤقتًا';

  @override
  String get goalStatusArchived => 'مؤرشف';

  @override
  String get goalProgress => 'تقدم الهدف';

  @override
  String get remainingAmount => 'المبلغ المتبقي';

  @override
  String get daysRemaining => 'الأيام المتبقية';

  @override
  String get monthlyNeeded => 'المطلوب شهريًا';

  @override
  String get createYourFirstGoal => 'أنشئ هدفك الأول وتابع كل مساهمة فيه.';

  @override
  String get goalSaved => 'تم حفظ الهدف.';

  @override
  String get goalArchived => 'تمت أرشفة الهدف.';

  @override
  String get goalRestored => 'تمت استعادة الهدف.';

  @override
  String get contributionAdded => 'تمت إضافة المساهمة.';

  @override
  String get contributionReversed => 'تم عكس المساهمة.';

  @override
  String get invalidGoalAmount => 'أدخل مبلغًا مستهدفًا أكبر من صفر.';

  @override
  String get invalidContributionAmount => 'أدخل مساهمة أكبر من صفر.';

  @override
  String get selectGoal => 'اختر هدفًا.';

  @override
  String get includeArchivedGoals => 'إظهار الأهداف المؤرشفة';

  @override
  String get goalsLoadError => 'تعذر تحميل الأهداف';

  @override
  String get goalsLoadErrorMessage =>
      'لا تزال أهدافك محفوظة بأمان. حاول تحميلها مجددًا.';

  @override
  String get goalSaveError => 'تعذر حفظ الهدف.';

  @override
  String get contributionSaveError => 'تعذرت إضافة هذه المساهمة.';

  @override
  String get goalDetails => 'تفاصيل الهدف';

  @override
  String get goalArchiveConfirm =>
      'لن تقبل الأهداف المؤرشفة مساهمات جديدة ولن تظهر ضمن ملخصات التخطيط النشطة.';

  @override
  String get contributionNote => 'ملاحظة';

  @override
  String get contributionDate => 'تاريخ المساهمة';

  @override
  String get reversedContribution => 'معكوسة';

  @override
  String get reverseContribution => 'عكس المساهمة';

  @override
  String get reverseContributionConfirm =>
      'سيُخصم مبلغ المساهمة من تقدم الهدف المسجل دون تحريك أموال الحسابات.';

  @override
  String get noContributionsYet => 'لا توجد مساهمات بعد';

  @override
  String get noContributionsMessage => 'ستظهر مساهمات هذا الهدف هنا.';

  @override
  String get linkedAccount => 'الحساب المرتبط';

  @override
  String get noLinkedAccount => 'دون حساب مرتبط';

  @override
  String get nearestTargetDate => 'أقرب تاريخ وصول';

  @override
  String get completedGoals => 'الأهداف المكتملة';

  @override
  String get goalMissingExchangeRate =>
      'أضف سعر صرف يدويًا قبل استخدام عملة هذه المساهمة.';

  @override
  String get goalWouldExceedTarget =>
      'ستتجاوز هذه المساهمة المبلغ المتبقي للهدف.';

  @override
  String get goalTargetBelowCurrent =>
      'لا يمكن أن يقل المبلغ المستهدف عن المبلغ المدخر حاليًا.';

  @override
  String get goalTrackingOnly => 'مساهمة تتبعية';

  @override
  String get comingSoon => 'قريبًا';

  @override
  String get financialInsights => 'الرؤى المالية';

  @override
  String get financialInsightsSubtitle =>
      'محسوبة بخصوصية من نشاطك المالي المحلي';

  @override
  String get noInsightsTitle => 'لا توجد رؤى بعد';

  @override
  String get noInsightsMessage =>
      'ستظهر الرؤى عند توفر نشاط منشور كافٍ للمقارنة.';

  @override
  String get insightSpendingIncreaseTitle => 'ارتفاع في الإنفاق';

  @override
  String insightSpendingIncreaseMessage(String percent) {
    return 'ارتفع الإنفاق بنسبة $percent% مقارنة بالشهر الماضي.';
  }

  @override
  String get insightPositiveSpendingTitle => 'تحسن في اتجاه الإنفاق';

  @override
  String insightPositiveSpendingMessage(String percent) {
    return 'انخفض الإنفاق بنسبة $percent% مقارنة بالشهر الماضي.';
  }

  @override
  String get insightTopCategoryTitle => 'أعلى تصنيف إنفاقًا';

  @override
  String insightTopCategoryMessage(String category, String amount) {
    return 'تصدّر $category الإنفاق هذا الشهر بمبلغ $amount.';
  }

  @override
  String get insightRecurringTitle => 'مدفوعات متكررة محتملة';

  @override
  String insightRecurringMessage(String count) {
    return 'تم اكتشاف $count أنماط محتملة لمدفوعات متكررة محليًا.';
  }

  @override
  String get insightCashFlowWarningTitle => 'التدفق النقدي يحتاج مراجعة';

  @override
  String insightCashFlowWarningMessage(String amount) {
    return 'صافي التدفق النقدي المنشور حاليًا هو $amount.';
  }

  @override
  String get insightPositiveCashFlowTitle => 'اتجاه إيجابي للتدفق النقدي';

  @override
  String insightPositiveCashFlowMessage(String amount) {
    return 'صافي التدفق النقدي المنشور حاليًا هو $amount.';
  }

  @override
  String get insightMissingRateTitle => 'سعر صرف مفقود';

  @override
  String insightMissingRateMessage(String pair) {
    return 'سعر $pair غير متوفر، لذلك بعض الإجماليات جزئية.';
  }

  @override
  String get insightBudgetWarningTitle => 'تنبيه ميزانية';

  @override
  String insightBudgetWarningMessage(String name, String percent) {
    return 'وصلت $name إلى $percent%.';
  }

  @override
  String get insightGoalProgressTitle => 'تقدم الهدف';

  @override
  String insightGoalProgressMessage(String name, String percent) {
    return 'وصل $name إلى $percent%.';
  }

  @override
  String get insightSavingsOpportunityTitle => 'فرصة للادخار';

  @override
  String get insightUnusualTransactionTitle => 'معاملة غير معتادة';

  @override
  String get insightPeriod => 'فترة الرؤية';

  @override
  String get reviewInsight => 'مراجعة';

  @override
  String get reportsTitle => 'التقارير';

  @override
  String get reportsSubtitle => 'الاتجاهات والرؤى المالية';

  @override
  String get reportsErrorTitle => 'تعذر تحميل التقارير';

  @override
  String get monthlyReport => 'التقرير الشهري';

  @override
  String get yearlyReport => 'التقرير السنوي';

  @override
  String get yearlyInsightsEmptyTitle => 'الرؤى السنوية قيد التجهيز';

  @override
  String get yearlyInsightsEmptyMessage =>
      'ستظهر هنا صورة سنوية مكتملة عندما تتوفر فترة تقرير كاملة.';

  @override
  String get categoryReport => 'تقرير التصنيفات';

  @override
  String get cashFlow => 'التدفق النقدي';

  @override
  String get cashFlowSubtitle => 'حركة المصروفات خلال آخر ستة أشهر.';

  @override
  String get cashFlowActiveMessage =>
      'يتم حساب التدفق النقدي من المعاملات المحلية المنشورة.';

  @override
  String get cashFlowEmptyMessage =>
      'أضف معاملات لتفعيل اتجاهات التدفق النقدي.';

  @override
  String get reportActualDataSubtitle =>
      'محسوب من الحسابات والمعاملات المحلية.';

  @override
  String get aiAssistantTitle => 'المساعد الذكي';

  @override
  String get aiAssistantShort => 'AI';

  @override
  String get aiAssistantSubtitle => 'ذكاء مالي شخصي';

  @override
  String get aiAssistantBackendPendingTitle => 'ذكاء كاش بايلوت';

  @override
  String get aiAssistantBackendPendingMessage =>
      'اسأل عن أمورك المالية أو صف إجراءً ماليًا. يجهّز كاش بايلوت مسودة للمراجعة ولا يغيّر أموالك دون تأكيدك.';

  @override
  String get aiAssistantPendingSnack =>
      'الإدخال الصوتي غير متاح بعد. يمكنك كتابة طلبك بدلًا منه.';

  @override
  String get suggestedPrompts => 'اقتراحات';

  @override
  String get promptAnalyzeSpending => 'حلل إنفاقي';

  @override
  String get promptFindSavings => 'ابحث عن فرص ادخار';

  @override
  String get promptExplainCashFlow => 'اشرح التدفق النقدي';

  @override
  String get promptReviewSubscriptions => 'راجع الاشتراكات';

  @override
  String get insightCards => 'بطاقات الرؤى';

  @override
  String get aiInsightCard => 'رؤية ذكية';

  @override
  String get aiInsightDataReady =>
      'سجل معاملاتك المحلي جاهز لتحليل ذكي يراعي الخصوصية.';

  @override
  String get aiInsightEmpty => 'أضف معاملات لفتح الرؤى الشخصية.';

  @override
  String get openAssistant => 'فتح المساعد';

  @override
  String get emptyConversationTitle => 'لا توجد محادثة بعد';

  @override
  String get emptyConversationMessage =>
      'ابدأ بسؤال أو صف معاملة تريد من CashPilot تجهيزها للمراجعة.';

  @override
  String get aiReadyBadge => 'الذكاء جاهز';

  @override
  String get aiThinking => 'جارٍ فهم طلبك';

  @override
  String get askAiHint => 'اسأل كاش بايلوت AI';

  @override
  String get aiTransactionDraftTitle => 'مسودة معاملة';

  @override
  String get aiClarifyPaymentMethod => 'أي طريقة دفع استخدمت؟';

  @override
  String get aiParsedAccount => 'الحساب';

  @override
  String get aiParsedCurrency => 'العملة';

  @override
  String get aiParsedPaymentMethod => 'طريقة الدفع';

  @override
  String get aiParsedConfidence => 'تم التحليل من رسالتك. راجعها قبل الحفظ.';

  @override
  String get voiceInput => 'إدخال صوتي';

  @override
  String get send => 'إرسال';

  @override
  String get aiDiagnosticsTitle => 'تشخيص الذكاء الاصطناعي';

  @override
  String get aiDiagnosticsDescription =>
      'تحقق من مزوّد النص البعيد والبوابة والمصادقة وApp Check دون تغيير أي بيانات مالية.';

  @override
  String get aiConfigurationTitle => 'إعدادات الذكاء الاصطناعي';

  @override
  String get aiRemoteTextProviderLabel => 'مزوّد النص البعيد';

  @override
  String get aiGeneralConversationModelLabel => 'نموذج المحادثة العامة';

  @override
  String get aiFinancialExplanationModelLabel => 'نموذج الشرح المالي';

  @override
  String get aiLocalCommandParserLabel => 'محلل الأوامر المحلي';

  @override
  String get aiReceiptVisionProviderLabel => 'مزوّد قراءة الإيصالات';

  @override
  String get aiProviderRoutingLabel => 'توجيه المزوّد';

  @override
  String get aiFirebaseTextFallbackLabel => 'البديل النصي من Firebase';

  @override
  String get aiGatewayLabel => 'البوابة';

  @override
  String get aiAuthenticationLabel => 'المصادقة';

  @override
  String get aiAppCheckLabel => 'App Check';

  @override
  String get aiEnvironmentLabel => 'البيئة';

  @override
  String get aiBuildModeLabel => 'وضع البناء';

  @override
  String get aiProviderGroq => 'Groq';

  @override
  String get aiProviderFirebaseAi => 'Firebase AI';

  @override
  String get aiProviderNotConfigured => 'غير مهيأ';

  @override
  String get aiProviderRoutingGroqPrimary => 'Groq أساسي';

  @override
  String get aiProviderRoutingFirebasePrimary => 'Firebase أساسي';

  @override
  String get aiProviderRoutingDisabled => 'النص البعيد متوقف';

  @override
  String get aiStatusEnabled => 'مفعّل';

  @override
  String get aiStatusDisabled => 'معطّل';

  @override
  String get aiStatusAvailable => 'متاحة';

  @override
  String get aiStatusUnavailable => 'غير متاحة';

  @override
  String get aiStatusReady => 'جاهزة';

  @override
  String get aiStatusNotReady => 'غير جاهزة';

  @override
  String get aiStatusVerified => 'تم التحقق';

  @override
  String get aiStatusNotActivated => 'غير مفعّل';

  @override
  String get aiStatusChecking => 'جارٍ التحقق…';

  @override
  String get aiProviderLabel => 'مزوّد الذكاء الاصطناعي';

  @override
  String get aiProviderMock => 'مزوّد الاختبار';

  @override
  String get aiProviderLocalParserOnly => 'المحلل المحلي فقط';

  @override
  String get aiProviderFirebaseGemini => 'Firebase Gemini (مباشر)';

  @override
  String get aiProviderAutomatic => 'اختيار المزوّد تلقائيًا';

  @override
  String get aiProviderGroqGateway => 'بوابة Groq الآمنة';

  @override
  String get aiModelGatewayManaged => 'نموذج تُديره البوابة';

  @override
  String get aiModelLabel => 'نموذج الذكاء الاصطناعي النشط';

  @override
  String get aiStructuredOutputEnabledLabel => 'المخرجات المنظّمة مفعّلة';

  @override
  String get aiStructuredOutputEnabledValue => 'مفعّلة';

  @override
  String get aiStructuredOutputDisabledValue => 'غير مفعّلة';

  @override
  String get aiLastTestStatusLabel => 'حالة آخر اختبار';

  @override
  String get aiTestStatusNotTested => 'لم يُختبر بعد';

  @override
  String get aiTestStatusTesting => 'جارٍ الاختبار';

  @override
  String get aiTestStatusAvailable => 'متاح';

  @override
  String get aiTestStatusUnavailable => 'غير متاح';

  @override
  String get aiTestStatusConfigurationMissing => 'الإعدادات ناقصة';

  @override
  String get aiTestStatusAuthenticationRequired => 'المصادقة مطلوبة';

  @override
  String get aiTestStatusAppCheckUnavailable => 'App Check غير متاح';

  @override
  String get aiTestStatusGatewayUnavailable => 'البوابة غير متاحة';

  @override
  String get aiTestStatusModelUnavailable => 'النموذج غير متاح';

  @override
  String get aiTestStatusOffline => 'غير متصل';

  @override
  String get aiTestStatusTimedOut => 'انتهت المهلة';

  @override
  String get aiTestStatusSuccess => 'نجح الاختبار';

  @override
  String get aiTestStatusProviderUnavailable => 'المزوّد غير متاح';

  @override
  String get aiTestStatusAppCheckBlocked => 'محظور بواسطة App Check';

  @override
  String get aiTestStatusRateLimited => 'تم بلوغ حد الطلبات';

  @override
  String get aiTestStatusInvalidResponse => 'استجابة غير صالحة';

  @override
  String get aiTestStatusNetworkFailure => 'فشل الاتصال بالشبكة';

  @override
  String get aiTestStatusFallbackUsed => 'تم استخدام البديل المحلي';

  @override
  String get aiLastCheckedLabel => 'آخر فحص';

  @override
  String get aiLiveTestLatencyLabel => 'زمن الاختبار المباشر';

  @override
  String aiLiveTestLatencyValue(int milliseconds) {
    return '$milliseconds مللي ثانية';
  }

  @override
  String get aiNotCheckedYet => 'لم يُفحص بعد';

  @override
  String aiLastCheckedValue(String date, String time) {
    return '$date، $time';
  }

  @override
  String get aiTechnicalCodeLabel => 'الرمز التقني';

  @override
  String get aiFallbackAvailabilityLabel => 'البديل المحلي الآمن';

  @override
  String get aiFallbackAvailable => 'متاح';

  @override
  String get aiFallbackUnavailable => 'غير متاح';

  @override
  String get aiLiveProviderInactiveMessage =>
      'مزوّد النص البعيد المهيأ غير مفعّل. لن يُرسل طلب ذكاء اصطناعي مباشر.';

  @override
  String get aiGroqLiveTestMessage =>
      'يرسل هذا الاختبار طلبًا مباشرًا صغيرًا عبر بوابة Groq المهيأة وبمسار المزود الموثّق نفسه الذي تستخدمه محادثة الذكاء. لن تُعرض صيغة الطلب أو الاستجابة هنا ولن تُخزنا.';

  @override
  String get aiRemoteProviderLiveTestMessage =>
      'يرسل هذا الاختبار طلبًا مباشرًا صغيرًا عبر المزوّد البعيد المهيأ وبالمسار الموثّق نفسه الذي تستخدمه محادثة الذكاء. لن تُعرض صيغة الطلب أو الاستجابة هنا ولن تُخزنا.';

  @override
  String get aiGroqNotConfiguredBuildMessage => 'Groq غير مهيأ في هذا البناء.';

  @override
  String get aiNotTestedCurrentConfiguration =>
      'لم يُختبر مع الإعدادات الحالية';

  @override
  String get aiLiveTestAvailableMessage =>
      'بوابة Groq والمصادقة وApp Check والاستجابة المتدفقة متاحة.';

  @override
  String get testAiConnection => 'اختبار اتصال الذكاء الاصطناعي';

  @override
  String get testingAiConnection => 'جارٍ اختبار اتصال الذكاء الاصطناعي…';

  @override
  String get aiConnectionSuccess =>
      'خدمة Firebase AI Logic وApp Check جاهزتان.';

  @override
  String get aiProviderConnectionSuccess =>
      'مزوّد الذكاء الاصطناعي المحدد جاهز.';

  @override
  String get aiConnectionFallbackReady =>
      'المحلل المالي المحلي جاهز. لم يُرسل أي طلب إلى مزوّد ذكاء بعيد.';

  @override
  String aiConnectionFallbackAfterFailure(String reason) {
    return '$reason لا يزال المحلل المحلي الآمن متاحًا.';
  }

  @override
  String get aiConnectionFailed =>
      'اتصال الذكاء الاصطناعي والمحلل المحلي غير متاحين.';

  @override
  String get aiRateLimitedMessage =>
      'تم بلوغ حد طلبات الذكاء الاصطناعي. انتظر قليلًا ثم حاول مجددًا.';

  @override
  String get aiAppCheckBlockedMessage =>
      'تعذر على App Check التحقق من التطبيق للوصول إلى الذكاء الاصطناعي. راجع إعداد Firebase.';

  @override
  String get aiNetworkFailureMessage =>
      'تعذر على كاش بايلوت الوصول إلى خدمة الذكاء الاصطناعي. تحقق من الاتصال وحاول مجددًا.';

  @override
  String get aiProviderUnavailableMessage =>
      'خدمة الذكاء الاصطناعي المحددة غير متاحة. سيُستخدم المحلل المحلي عندما يكون ذلك ممكنًا.';

  @override
  String get aiLocalParserOnlyMessage =>
      'الذكاء الاصطناعي البعيد متوقف في هذا الإصدار، والمحلل المالي المحلي مفعّل.';

  @override
  String get aiInvalidResponseMessage =>
      'تعذر التحقق من استجابة الذكاء الاصطناعي، لذلك لم تُستخدم.';

  @override
  String get aiRequestInFlightMessage =>
      'يوجد طلب ذكاء اصطناعي قيد التنفيذ بالفعل.';

  @override
  String get aiRequestTooFastMessage =>
      'انتظر لحظة قبل إرسال طلب ذكاء اصطناعي آخر.';

  @override
  String get aiDuplicatePromptMessage =>
      'تم إرسال الطلب نفسه قبل لحظات. انتظر أو عدّله قبل المحاولة مجددًا.';

  @override
  String get aiGenericFailureMessage =>
      'تعذر على كاش بايلوت إكمال طلب الذكاء الاصطناعي بأمان.';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get appearance => 'المظهر';

  @override
  String get theme => 'النمط';

  @override
  String get system => 'النظام';

  @override
  String get light => 'فاتح';

  @override
  String get dark => 'داكن';

  @override
  String get language => 'اللغة';

  @override
  String get english => 'الإنجليزية';

  @override
  String get arabic => 'العربية';

  @override
  String get preferences => 'التفضيلات';

  @override
  String get currency => 'العملة';

  @override
  String get currencyPendingMessage =>
      'تساعد العملة الأساسية على توحيد التقارير بين الحسابات.';

  @override
  String get backup => 'النسخ الاحتياطي';

  @override
  String get backupPendingMessage =>
      'يتوفر النسخ الاحتياطي السحابي للحسابات المسجلة.';

  @override
  String get cloudBackup => 'النسخ الاحتياطي السحابي';

  @override
  String get cloudBackupEnabled => 'النسخ الاحتياطي السحابي مفعّل.';

  @override
  String get cloudBackupDisabled => 'النسخ الاحتياطي السحابي متوقف.';

  @override
  String get backupOnlyDescription =>
      'يرفع التغييرات المحلية المنتظرة إلى نسخة سحابية خاصة بحسابك. الاستعادة والدمج من السحابة إلى الجهاز غير متاحين بعد.';

  @override
  String get guestBackupWarning =>
      'سجّل الدخول بحساب غير ضيف لاستخدام النسخ الاحتياطي السحابي.';

  @override
  String get lastBackup => 'آخر نسخة احتياطية ناجحة';

  @override
  String get neverBackedUp => 'لا توجد نسخة احتياطية ناجحة بعد';

  @override
  String get pendingBackupItems => 'عناصر النسخ المنتظرة';

  @override
  String get failedBackupItems => 'عناصر النسخ المتعثرة';

  @override
  String get backupNow => 'نسخ احتياطي الآن';

  @override
  String get retryFailedBackup => 'إعادة محاولة المتعثّر';

  @override
  String get backupNoPendingItems => 'طابور النسخ الاحتياطي محدّث بالفعل.';

  @override
  String backupSuccess(int count) {
    return 'تم نسخ $count عناصر احتياطيًا.';
  }

  @override
  String backupPartialFailure(int count) {
    return 'اكتمل النسخ مع تعثّر $count عناصر.';
  }

  @override
  String get security => 'الأمان';

  @override
  String get biometricToggle => 'فتح بالبصمة';

  @override
  String get biometricPendingMessage =>
      'يفتح قفل الجهاز الوصول بسرعة وأمان على الأجهزة المدعومة.';

  @override
  String get securityPendingMessage =>
      'يساعد توثيق البريد وحماية الجلسة على تأمين مساحة عملك.';

  @override
  String get about => 'حول التطبيق';

  @override
  String get aboutMessage =>
      'منصة مالية شخصية محلية أولا ومجهزة للذكاء الاصطناعي والمزامنة السحابية.';

  @override
  String get legalAndPrivacy => 'القانون والخصوصية';

  @override
  String get privacyPolicy => 'سياسة الخصوصية';

  @override
  String get privacyPolicySubtitle =>
      'راجع كيفية التعامل مع البيانات المحلية والنسخ السحابي والذكاء الاصطناعي والحذف.';

  @override
  String get termsOfUse => 'شروط الاستخدام';

  @override
  String get termsOfUseSubtitle => 'راجع مسودة شروط استخدام المنتج وحدوده.';

  @override
  String get policyDraftNoticeTitle => 'معلومات منتج أولية';

  @override
  String get policyDraftNoticeMessage =>
      'هذه صياغة محايدة مؤقتة وتتطلب مراجعة قانونية قبل أي إصدار عام. وهي ليست استشارة قانونية أو سياسة نهائية.';

  @override
  String get privacyLocalDataTitle => 'البيانات على هذا الجهاز';

  @override
  String get privacyLocalDataMessage =>
      'تُحفظ السجلات المالية محليًا في قاعدة بيانات التطبيق وتبقى مصدر الحقيقة. ويمسح مسار حذف الحساب الكامل هذه البيانات المالية المحلية وطابور النسخ المعلّق من هذا الجهاز أيضًا.';

  @override
  String get privacyCloudBackupTitle => 'نسخ سحابي اختياري';

  @override
  String get privacyCloudBackupMessage =>
      'يمكن للمستخدم المسجل بحساب غير ضيف تفعيل نسخة Firestore خاصة بحسابه. ترفع البنية الحالية التغييرات المنتظرة فقط؛ ولا تتوفر الاستعادة أو عملية الدمج من السحابة إلى الجهاز.';

  @override
  String get privacyAiTitle => 'معالجة الذكاء الاصطناعي';

  @override
  String get privacyAiMessage =>
      'قد ترسل طلبات الذكاء الاصطناعي الرسالة والسياق المحدود اللازم لرد المزود المهيأ. وقد تكون المخرجات ناقصة أو غير دقيقة، وتبقى الإجراءات المالية بحاجة إلى تأكيد صريح.';

  @override
  String get privacyDeletionTitle => 'حذف الحساب والبيانات';

  @override
  String get privacyDeletionMessage =>
      'بعد التأكيد الصريح وإعادة التحقق عند الحاجة، يحذف خيار حذف الحساب مجموعات النسخ المعروفة في Firestore والملف السحابي، ثم يمسح السجلات المالية المحلية وتفضيلات الحساب، وأخيرًا يحذف ملف مصادقة Firebase. إذا فشلت مرحلة، تتوقف المراحل الإتلافية اللاحقة حتى يمكن إعادة المحاولة بأمان.';

  @override
  String get termsPersonalUseTitle => 'الاستخدام الشخصي';

  @override
  String get termsPersonalUseMessage =>
      'CashPilot AI أداة شخصية لحفظ السجلات. تقع عليك مسؤولية مراجعة القيود والتصنيفات والأرصدة وأسعار الصرف والميزانيات والأهداف للتأكد من دقتها.';

  @override
  String get termsFinancialInfoTitle => 'المعلومات المالية';

  @override
  String get termsFinancialInfoMessage =>
      'التقارير والتوقعات والرؤى والاقتراحات خصائص معلوماتية في المنتج، وليست استشارة مالية أو استثمارية أو ضريبية أو محاسبية أو قانونية.';

  @override
  String get termsAiTitle => 'الإجراءات المدعومة بالذكاء الاصطناعي';

  @override
  String get termsAiMessage =>
      'قد تكون تفسيرات الذكاء الاصطناعي خاطئة. راجع الحساب والمبلغ والعملة والتصنيف والحالة وسعر الصرف في كل إجراء مقترح قبل تأكيده.';

  @override
  String get termsAvailabilityTitle => 'التوفر والنسخ الاحتياطي';

  @override
  String get termsAvailabilityMessage =>
      'يمكن أن يستمر الاستخدام المحلي دون اتصال للخصائص المدعومة. وقد يتأخر النسخ السحابي أو لا يتوفر، وهو لا يحل محل عملية استعادة أو تصدير تم التحقق منها.';

  @override
  String get aiFinancialDisclaimer =>
      'قد تكون مخرجات الذكاء الاصطناعي غير دقيقة وهي للمعلومات فقط وليست استشارة مالية. راجع كل إجراء قبل تأكيده.';

  @override
  String get bootstrapFailureTitle => 'تعذر تشغيل CashPilot AI';

  @override
  String get bootstrapFailureMessage =>
      'إحدى خدمات الجهاز أو Firebase المطلوبة غير متاحة. تحقق من الاتصال وإعدادات التطبيق ثم حاول مجددًا.';

  @override
  String get profileTitle => 'الملف الشخصي';

  @override
  String get profileGuestName => 'ملف محلي';

  @override
  String get profileLocalAccount => 'محفوظ على هذا الجهاز';

  @override
  String get profileBackendPendingTitle => 'الملف الشخصي';

  @override
  String get profileBackendPendingMessage =>
      'أدر الهوية، التحقق، وتفضيلات الحساب من ملفك الآمن.';

  @override
  String get authDefaultSubtitle => 'وصول آمن إلى مساحتك المالية.';

  @override
  String get authSecureAccess => 'وصول آمن';

  @override
  String get authVerifiedSession => 'جلسة موثّقة';

  @override
  String get authTermsPrivacy =>
      'بالمتابعة، فإنك توافق على الشروط وتقر بسياسة الخصوصية.';

  @override
  String get authCheckingSession => 'جارٍ التحقق من الجلسة الآمنة';

  @override
  String get onboardingTrackTitle => 'تابع كل حساباتك.';

  @override
  String get onboardingTrackMessage =>
      'اجمع النقد والبطاقات والحسابات البنكية والمحافظ في مساحة مالية واحدة وواضحة.';

  @override
  String get onboardingAiTitle => 'مساعد مالي ذكي.';

  @override
  String get onboardingAiMessage =>
      'اسأل أسئلة أذكى، راجع إنفاقك، واكتشف فرصًا أفضل مع نمو بياناتك.';

  @override
  String get onboardingInsightsTitle => 'رؤى مالية.';

  @override
  String get onboardingInsightsMessage =>
      'افهم الاتجاهات والميزانيات والأهداف من خلال تقارير واضحة تساعدك على القرار.';

  @override
  String get skip => 'تخطي';

  @override
  String get next => 'التالي';

  @override
  String get getStarted => 'ابدأ الآن';

  @override
  String get authWelcomeTitle => 'CashPilot AI';

  @override
  String get authWelcomeSubtitle =>
      'مساحة مالية شخصية آمنة للحسابات والتدفق النقدي والرؤى المدعومة بالذكاء الاصطناعي.';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get createAccount => 'إنشاء حساب';

  @override
  String get continueAsGuest => 'المتابعة كضيف';

  @override
  String get loginHeadline => 'مرحبًا بعودتك';

  @override
  String get loginSubtitle => 'سجّل الدخول لمتابعة جلستك المالية الآمنة.';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get showPassword => 'إظهار كلمة المرور';

  @override
  String get hidePassword => 'إخفاء كلمة المرور';

  @override
  String get rememberMe => 'تذكرني';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get continueWithGoogle => 'المتابعة باستخدام Google';

  @override
  String get continueWithApple => 'المتابعة باستخدام Apple';

  @override
  String get authInvalidForm => 'راجع الحقول المطلوبة ثم حاول مرة أخرى.';

  @override
  String get registerHeadline => 'أنشئ حسابك';

  @override
  String get registerSubtitle =>
      'ابدأ بتسجيل دخول آمن ثم أكمل ملفك في الخطوة التالية.';

  @override
  String get name => 'الاسم';

  @override
  String get confirmPassword => 'تأكيد كلمة المرور';

  @override
  String get acceptTerms => 'أوافق على الشروط وسياسة الخصوصية.';

  @override
  String get forgotPasswordTitle => 'إعادة تعيين كلمة المرور';

  @override
  String get forgotPasswordSubtitle =>
      'أدخل بريدك الإلكتروني وسنرسل لك رابطًا آمنًا لإعادة التعيين.';

  @override
  String get resetLinkSent =>
      'تم إرسال رابط إعادة التعيين. راجع بريدك للمتابعة.';

  @override
  String get sendResetLink => 'إرسال رابط التعيين';

  @override
  String get backToLogin => 'العودة لتسجيل الدخول';

  @override
  String get verifyEmailTitle => 'تحقق من بريدك الإلكتروني';

  @override
  String get verifyEmailSubtitle => 'تأكيد سريع يحافظ على حماية حسابك.';

  @override
  String get verifyEmailMessage =>
      'افتح رابط التحقق الذي أرسلناه، ثم حدّث الحالة من هنا.';

  @override
  String get resendEmail => 'إعادة إرسال البريد';

  @override
  String get refreshStatus => 'تحديث الحالة';

  @override
  String get verificationEmailSent => 'تم إرسال رسالة التحقق.';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get profileCompletionTitle => 'إكمال الملف الشخصي';

  @override
  String get profileCompletionSubtitle =>
      'اضبط كاش بايلوت حسب عملتك ولغتك ومنطقتك.';

  @override
  String get displayName => 'اسم العرض';

  @override
  String get preferredCurrency => 'العملة المفضلة';

  @override
  String get country => 'الدولة';

  @override
  String get timezone => 'المنطقة الزمنية';

  @override
  String get guestModeTitle => 'وضع الضيف';

  @override
  String get guestModeSubtitle => 'جرّب التطبيق بجلسة مؤقتة بدون حساب كامل.';

  @override
  String get guestModeLocalTitle => 'جلسة محلية أولًا';

  @override
  String get guestModeLocalMessage =>
      'يمكنك استكشاف مساحة العمل دون مشاركة بيانات شخصية.';

  @override
  String get guestModeSyncTitle => 'مزامنة سحابية محدودة';

  @override
  String get guestModeSyncMessage =>
      'يتطلب النسخ الاحتياطي والمزامنة بين الأجهزة والاسترداد حسابًا كاملًا.';

  @override
  String get guestModeUpgradeTitle => 'يمكنك الترقية في أي وقت';

  @override
  String get guestModeUpgradeMessage =>
      'أنشئ حسابًا لاحقًا لتفعيل التحقق والاسترداد المحمي.';

  @override
  String get account => 'الحساب';

  @override
  String get guestAccount => 'حساب ضيف';

  @override
  String get deleteAccountSettingsSubtitle =>
      'حذف هذا الحساب وجميع البيانات المالية المحلية والسحابية نهائيًا.';

  @override
  String get accountDataDeletionMessage =>
      'سيؤدي هذا إلى حذف النسخة السحابية والسجلات المالية المحلية وطابور النسخ المعلّق وتفضيلات الحساب وملف تسجيل الدخول نهائيًا. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get confirmFullDataDeletion =>
      'أفهم أن حسابي وجميع بياناتي المالية ستُحذف نهائيًا.';

  @override
  String get passwordForEmailAccounts =>
      'يجب على حسابات البريد وكلمة المرور إدخال كلمة المرور الحالية. ستفتح حسابات Google وApple نافذة تأكيد المزوّد.';

  @override
  String get dataDeletionInProgress => 'جارٍ حذف الحساب وجميع البيانات...';

  @override
  String get dataDeletionCompleted => 'تم حذف الحساب وجميع البيانات.';

  @override
  String get dataDeletionConfirmationRequired =>
      'أكّد الحذف النهائي قبل المتابعة.';

  @override
  String get dataDeletionReauthFailed =>
      'تعذر التحقق من هويتك. لم تُحذف أي بيانات. تحقق من بيانات الدخول وحاول مجددًا.';

  @override
  String get dataDeletionCloudFailed =>
      'لم يكتمل الحذف السحابي. احتُفظ بالحساب والبيانات المحلية كي تتمكن من إعادة المحاولة بأمان.';

  @override
  String get dataDeletionLocalFailed =>
      'حُذفت النسخة السحابية، لكن تعذر حذف البيانات المحلية. احتُفظ بالحساب كي تتمكن من إعادة المحاولة.';

  @override
  String get dataDeletionPreferencesFailed =>
      'حُذفت السجلات المالية، لكن تعذر مسح تفضيلات الحساب. احتُفظ بالحساب كي تتمكن من إعادة المحاولة.';

  @override
  String get dataDeletionAuthFailed =>
      'حُذفت بياناتك المالية، لكن تعذر حذف ملف تسجيل الدخول. سجّل الدخول مجددًا وأعد المحاولة.';

  @override
  String get verifiedAccount => 'حساب موثّق';

  @override
  String get verifiedAccountMessage =>
      'تم توثيق بريدك الإلكتروني وجلسة حسابك محمية.';

  @override
  String get profileCompletionSettingsSubtitle =>
      'حدّث اسم العرض والمنطقة واللغة والعملة.';

  @override
  String get greetingMorning => 'صباح الخير';

  @override
  String get greetingAfternoon => 'مساء الخير';

  @override
  String get greetingEvening => 'مساء الخير';

  @override
  String get dashboardErrorTitle => 'تعذر تحميل الرئيسية';

  @override
  String get dashboardErrorMessage => 'قم بتحديث الصفحة أو حاول لاحقا.';

  @override
  String get totalNetWorth => 'إجمالي صافي الثروة';

  @override
  String get monthlyIncome => 'الدخل الشهري';

  @override
  String get monthlyExpense => 'المصروف الشهري';

  @override
  String get monthlySavings => 'الادخار الشهري';

  @override
  String get yearlyIncome => 'الدخل السنوي';

  @override
  String get yearlyExpense => 'المصروف السنوي';

  @override
  String get yearlySavings => 'الادخار السنوي';

  @override
  String get recentTransactions => 'أحدث المعاملات';

  @override
  String get spendingChart => 'مخطط الإنفاق';

  @override
  String get spendingChartSubtitle => 'أعلى تصنيفات المصروفات هذا الشهر.';

  @override
  String get noSpendingYet => 'لا يوجد إنفاق بعد';

  @override
  String get noSpendingYetMessage => 'ستظهر المصروفات المنشورة هنا.';

  @override
  String get quickActions => 'إجراءات سريعة';

  @override
  String get viewAll => 'عرض الكل';

  @override
  String get openBudgets => 'فتح الميزانيات';

  @override
  String get openGoals => 'فتح الأهداف';

  @override
  String get transfer => 'تحويل';

  @override
  String get transferHistory => 'سجل التحويلات';

  @override
  String get transferScreenSubtitle =>
      'انقل الأموال بين حساباتك مع مراجعة واضحة قبل الترحيل.';

  @override
  String get transferBackendPendingTitle => 'مساحة التحويلات';

  @override
  String get transferBackendPendingMessage =>
      'راجع حساب المصدر وحساب الوجهة قبل ترحيل التحويل المزدوج.';

  @override
  String get transferExchangeRequiredTitle => 'مبلغ الوجهة مطلوب';

  @override
  String get transferExchangeRequiredMessage =>
      'الحسابان يستخدمان عملتين مختلفتين. أدخل المبلغ الذي سيصل إلى حساب الوجهة.';

  @override
  String get fromAccount => 'من حساب';

  @override
  String get toAccount => 'إلى حساب';

  @override
  String get destinationAmount => 'مبلغ الوجهة';

  @override
  String get transferPreviewTitle => 'معاينة التحويل';

  @override
  String get transferPreviewSubtitle =>
      'راجع أثر التحويل على الحسابات والعملات قبل إنشائه.';

  @override
  String get manualConversionBadge => 'تحويل يدوي';

  @override
  String get manualExchangeRateLabel => 'السعر اليدوي الضمني';

  @override
  String get exchangeRatesTitle => 'أسعار الصرف';

  @override
  String get exchangeRatesSubtitle =>
      'أسعار يدوية تُستخدم للتحويل والتقارير الموحّدة.';

  @override
  String get baseCurrency => 'العملة الأساسية';

  @override
  String get addExchangeRate => 'إضافة سعر صرف';

  @override
  String get editExchangeRate => 'تعديل سعر الصرف';

  @override
  String get deleteExchangeRate => 'حذف سعر الصرف';

  @override
  String get archiveExchangeRate => 'أرشفة سعر الصرف';

  @override
  String get archiveExchangeRateConfirm =>
      'لن يُستخدم السعر المؤرشف في التحويلات أو الإجماليات الموحّدة.';

  @override
  String get fromCurrency => 'من عملة';

  @override
  String get toCurrency => 'إلى عملة';

  @override
  String get exchangeRate => 'السعر';

  @override
  String get manualRate => 'سعر يدوي';

  @override
  String get lastUpdated => 'آخر تحديث';

  @override
  String get missingExchangeRateTitle => 'سعر صرف مفقود';

  @override
  String get missingExchangeRateDescription =>
      'بعض الإجماليات جزئية لعدم وجود سعر يدوي نشط لأحد أزواج العملات المطلوبة.';

  @override
  String get conversionFailed => 'تعذر تحويل العملة.';

  @override
  String get sameCurrencyNotAllowed => 'اختر عملتين مختلفتين.';

  @override
  String get invalidExchangeRate => 'أدخل سعرًا أكبر من صفر.';

  @override
  String get exchangeRateSaved => 'تم حفظ سعر الصرف.';

  @override
  String get exchangeRateDeleted => 'تم حذف سعر الصرف.';

  @override
  String get exchangeRateArchived => 'تمت أرشفة سعر الصرف.';

  @override
  String get netWorthPartiallyCalculated => 'تم حساب صافي الثروة بشكل جزئي.';

  @override
  String get addRateToContinue =>
      'أضف السعر اليدوي المفقود لإكمال هذه الإجماليات.';

  @override
  String get selectBaseCurrency =>
      'اختر العملة المستخدمة في الإجماليات الموحّدة.';

  @override
  String get convertedTotal => 'الإجمالي المحوّل';

  @override
  String get originalCurrency => 'العملة الأصلية';

  @override
  String get rateUsed => 'السعر المستخدم';

  @override
  String get suggestedStoredRate => 'سعر يدوي محفوظ مقترح';

  @override
  String get enterExchangeRate => 'أدخل سعر الصرف';

  @override
  String get exchangeRateRequired => 'يلزم إدخال سعر صرف أو مبلغ الوجهة.';

  @override
  String get noExchangeRatesTitle => 'لا توجد أسعار يدوية بعد';

  @override
  String get noExchangeRatesMessage =>
      'أضف سعرًا عند الحاجة إلى تحويل الأرصدة أو المعاملات بين العملات.';

  @override
  String get exchangeRatesErrorTitle => 'تعذر تحميل أسعار الصرف';

  @override
  String get ratesAreManualNotice =>
      'تُدخل الأسعار يدويًا ولا يتم جلبها أو تخمينها تلقائيًا.';

  @override
  String get includeArchivedRates => 'إظهار الأسعار المؤرشفة';

  @override
  String get archivedRate => 'مؤرشف';

  @override
  String get destinationAmountRequired => 'أدخل مبلغ الوجهة لإكمال المعاينة.';

  @override
  String get transferPostedEffectMessage =>
      'يحدّث التحويل المرحّل رصيدي الحسابين فورًا.';

  @override
  String get transferPendingEffectMessage =>
      'يُسجل التحويل المعلّق من دون تغيير رصيد أي حساب.';

  @override
  String get transferSafetyTitle => 'راجع قبل الإنشاء';

  @override
  String get transferSafetyMessage =>
      'ينشئ CashPilot زوج تحويل مترابطًا واحدًا بعد الإرسال، وتُدخل مبالغ العملات المختلفة يدويًا.';

  @override
  String get createTransfer => 'إنشاء تحويل';

  @override
  String get transferCreatedMessage => 'تم إنشاء التحويل.';

  @override
  String get transferFailedMessage => 'فشل التحويل.';

  @override
  String get transferCannotBeEditedMessage => 'لا يمكن تعديل التحويلات مباشرة.';

  @override
  String get transferCannotBeDeletedMessage => 'لا يمكن حذف هذا التحويل بأمان.';

  @override
  String get postedTransferCannotBeDeletedMessage =>
      'لا يمكن حذف التحويلات المرحلة. ألغ التحويل لعكس أثره.';

  @override
  String get missingExchangeRateMessage =>
      'أدخل مبلغ الوجهة أو سعر صرف صالحًا.';

  @override
  String get invalidTransferStateMessage =>
      'هذا التحويل غير مكتمل أو في حالة غير صالحة.';

  @override
  String get transferIntegrityReviewMessage =>
      'يتطلب سجل التحويلات مراجعة يدوية قبل إجراء أي تغييرات مالية جديدة.';

  @override
  String get transferReference => 'مرجع التحويل';

  @override
  String get cancelTransfer => 'إلغاء التحويل';

  @override
  String get transferCancelledMessage => 'تم إلغاء التحويل.';

  @override
  String get confirm => 'تأكيد';

  @override
  String get aiActionConfirmationTitle => 'راجع إجراء الذكاء الاصطناعي';

  @override
  String get aiActionConfirmationMessage =>
      'لن يحفظ CashPilot هذا الإجراء إلا بعد تأكيدك.';

  @override
  String get aiAwaitingConfirmationStatus => 'بانتظار التأكيد';

  @override
  String get aiExecutingStatus => 'جارٍ التنفيذ بأمان';

  @override
  String get aiExecutedStatus => 'تم التنفيذ';

  @override
  String get aiConfirmationSafetyTitle => 'لن يحدث شيء قبل تأكيدك';

  @override
  String get aiConfirmationSafetyMessage =>
      'راجع التفاصيل أدناه. ينفذ CashPilot هذا الإجراء مرة واحدة وبعد تأكيدك فقط.';

  @override
  String get aiActionConfirmedMessage => 'تم حفظ إجراء الذكاء الاصطناعي.';

  @override
  String get aiActionCancelledMessage => 'تم إلغاء إجراء الذكاء الاصطناعي.';

  @override
  String get aiActionInvalidMessage =>
      'تحتاج هذه المسودة إلى مراجعة قبل حفظها.';

  @override
  String get aiAmbiguousAccountMessage => 'أي حساب تريد استخدامه؟';

  @override
  String get aiActionAlreadyExecutedMessage =>
      'تم تنفيذ إجراء الذكاء الاصطناعي هذا بالفعل.';

  @override
  String get aiClarificationTitle => 'مطلوب توضيح';

  @override
  String get aiActionExpenseTitle => 'مسودة مصروف';

  @override
  String get aiActionIncomeTitle => 'مسودة دخل';

  @override
  String get aiActionTransferTitle => 'مسودة تحويل';

  @override
  String get aiActionQuestionTitle => 'سؤال';

  @override
  String get aiDetectedItem => 'العنصر المكتشف';

  @override
  String get aiSuggestedCategory => 'التصنيف المقترح';

  @override
  String get aiCategoryConfidenceHigh => 'ثقة عالية';

  @override
  String get aiCategoryConfidenceSuggested => 'مقترح';

  @override
  String get aiCategoryConfidenceNeedsChoice => 'يحتاج اختيارك';

  @override
  String get aiCategorySourceExplicit => 'اختيار من رسالتك';

  @override
  String get aiCategorySourceUserRule => 'قاعدتك المحفوظة';

  @override
  String get aiCategorySourcePayee => 'التصنيف الافتراضي للمستفيد';

  @override
  String get aiCategorySourceAlias => 'تطابق العنصر';

  @override
  String get aiCategorySourceAi => 'اقتراح حسب المعنى';

  @override
  String get aiCategorySourceKeyword => 'تطابق محلي';

  @override
  String get aiCategorySourceFallback => 'لا يوجد تطابق موثوق';

  @override
  String get aiEditCategory => 'تعديل التصنيف';

  @override
  String get aiIncomeSourceType => 'نوع مصدر الدخل';

  @override
  String get aiIncomeSourceName => 'من';

  @override
  String get aiIncomeSourceIdentityHint =>
      'أدخل اسم الشخص أو الجهة التي أتت منها الأموال';

  @override
  String get aiIncomeDestinationAccount => 'الحساب المستلم';

  @override
  String get aiRecordIncomeOffer => 'يبدو أن أموالاً وصلتك. هل تريد تسجيلها؟';

  @override
  String get aiRecordTransactionOffer => 'هل تريد تسجيل هذه الحركة المالية؟';

  @override
  String get aiRecordIncomeOfferCancelled => 'حسنًا — لم أسجّل أي شيء.';

  @override
  String get aiIncomeMissingDetails =>
      'قبل تجهيز المعاينة، اختر الحساب المستلم ونوع المصدر والتصنيف وتاريخ العملية، وحدد مصدر الأموال عندما يُطلب ذلك.';

  @override
  String get aiIncomeSpecialReviewTitle => 'راجع هذا التدفق بعناية';

  @override
  String get aiIncomeLoanWarning =>
      'متحصلات القرض تزيد النقد لكنها التزام وليست دخلاً مكتسباً.';

  @override
  String get aiIncomeDebtRepaymentWarning =>
      'سداد الدين يعيد أموالاً كانت مستحقة لك وليس دخلاً مكتسباً جديداً.';

  @override
  String get aiIncomeRefundWarning =>
      'هذه أموال مستردة من عملية شراء وليست دخلاً مكتسباً جديداً.';

  @override
  String get aiIncomeReimbursementWarning =>
      'هذا سداد لمصروف سابق ويظل منفصلاً عن الراتب أو إيراد الأعمال.';

  @override
  String get aiIncomeExternalTransferWarning =>
      'وضّح هل الحوالة هدية أو تعويضاً أو عائد بيع أو راتباً أو مصدراً آخر.';

  @override
  String get aiIncomeOtherWarning => 'أكد نوع المصدر قبل حفظ هذا التدفق.';

  @override
  String get incomeSourceSalary => 'راتب';

  @override
  String get incomeSourceFreelance => 'عمل حر';

  @override
  String get incomeSourceBusinessRevenue => 'إيراد أعمال';

  @override
  String get incomeSourceGift => 'هدية';

  @override
  String get incomeSourceDebtRepayment => 'سداد دين';

  @override
  String get incomeSourceAllowance => 'مصروف شخصي';

  @override
  String get incomeSourceRefund => 'استرداد';

  @override
  String get incomeSourceSale => 'عائد بيع';

  @override
  String get incomeSourceRentalIncome => 'دخل إيجار';

  @override
  String get incomeSourceGovernmentSupport => 'دعم حكومي';

  @override
  String get incomeSourceScholarship => 'منحة دراسية';

  @override
  String get incomeSourceInvestmentReturn => 'عائد استثمار';

  @override
  String get incomeSourceReimbursement => 'تعويض مصروف';

  @override
  String get incomeSourcePrize => 'جائزة';

  @override
  String get incomeSourceLoanProceeds => 'متحصلات قرض';

  @override
  String get incomeSourceExternalTransfer => 'حوالة خارجية';

  @override
  String get incomeSourceOther => 'أخرى';

  @override
  String get statistics => 'الإحصاءات';

  @override
  String get save => 'حفظ';

  @override
  String get cancel => 'إلغاء';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get delete => 'حذف';

  @override
  String get edit => 'تعديل';

  @override
  String get archive => 'أرشفة';

  @override
  String get sort => 'ترتيب';

  @override
  String get all => 'الكل';

  @override
  String get income => 'الدخل';

  @override
  String get expense => 'المصروف';

  @override
  String get pending => 'معلق';

  @override
  String get sortNewest => 'الأحدث';

  @override
  String get sortOldest => 'الأقدم';

  @override
  String get sortAmountHigh => 'الأعلى مبلغا';

  @override
  String get resultsLabel => 'النتائج';

  @override
  String get zero => '0';

  @override
  String get switchLanguageTooltip => 'تغيير اللغة';

  @override
  String get switchThemeTooltip => 'تغيير النمط';

  @override
  String get routeNotFoundTitle => 'الصفحة غير موجودة';

  @override
  String get routeNotFoundMessage => 'الوجهة المطلوبة غير متاحة.';

  @override
  String get addPayee => 'إضافة مستفيد';

  @override
  String get editPayee => 'تعديل المستفيد';

  @override
  String get archivePayee => 'أرشفة المستفيد';

  @override
  String get restorePayee => 'استعادة المستفيد';

  @override
  String get payeeName => 'اسم المستفيد';

  @override
  String get payeeNameRequired => 'اسم المستفيد مطلوب.';

  @override
  String get selectPayee => 'المستفيد';

  @override
  String get noPayee => 'بلا مستفيد';

  @override
  String get payeeType => 'نوع المستفيد';

  @override
  String get payeeAliases => 'الأسماء البديلة';

  @override
  String get payeeAliasesHint => 'افصل الأسماء البديلة بفواصل';

  @override
  String get payeeDefaultCategory => 'التصنيف الافتراضي';

  @override
  String get payeeDefaultAccount => 'الحساب الافتراضي';

  @override
  String get payeeNotes => 'ملاحظات';

  @override
  String get payeeTypeMerchant => 'تاجر';

  @override
  String get payeeTypePerson => 'شخص';

  @override
  String get payeeTypeEmployer => 'جهة عمل';

  @override
  String get payeeTypeBank => 'مصرف';

  @override
  String get payeeTypePaymentService => 'خدمة دفع';

  @override
  String get payeeTypeUtility => 'مرفق خدمي';

  @override
  String get payeeTypeTelecom => 'اتصالات';

  @override
  String get payeeTypeGovernment => 'جهة حكومية';

  @override
  String get payeeTypeSchool => 'مدرسة';

  @override
  String get payeeTypeOther => 'أخرى';

  @override
  String get payeeAlreadyExists => 'يوجد مستفيد بهذا الاسم بالفعل.';

  @override
  String get aliasAlreadyExists => 'هذا الاسم البديل مرتبط بمستفيد آخر.';

  @override
  String get ambiguousPayee => 'أي مستفيد تقصد؟';

  @override
  String get payeeNotFound => 'المستفيد غير موجود.';

  @override
  String get createNewPayeeSuggestion =>
      'لم يتم العثور على مستفيد مطابق. يمكنك إنشاء مستفيد بعد مراجعة المعاملة.';

  @override
  String get payeeArchivedMessage => 'تمت أرشفة المستفيد.';

  @override
  String get payeeRestoredMessage => 'تمت استعادة المستفيد.';

  @override
  String get payeeSavedMessage => 'تم حفظ المستفيد.';

  @override
  String get includeArchivedPayees => 'إظهار المؤرشفين';

  @override
  String get archivedPayee => 'مؤرشف';

  @override
  String get filterByType => 'تصفية حسب النوع';

  @override
  String get allPayeeTypes => 'كل الأنواع';

  @override
  String get noDefaultSelection => 'بلا قيمة افتراضية';

  @override
  String get lastUsed => 'آخر استخدام';

  @override
  String get neverUsed => 'لم يُستخدم بعد';

  @override
  String get relatedTransactions => 'المعاملات المرتبطة';

  @override
  String get scanReceipt => 'مسح إيصال';

  @override
  String get receiptScannerTitle => 'ماسح الإيصالات';

  @override
  String get receiptScannerSubtitle =>
      'التقط صورة للإيصال أو استورد صورة، ثم راجع كل قيمة مستخرجة.';

  @override
  String get takeReceiptPhoto => 'التقاط صورة';

  @override
  String get importReceiptImage => 'استيراد صورة';

  @override
  String get documentScannerUnavailable =>
      'ماسح المستندات غير متاح على هذا الجهاز.';

  @override
  String get receiptPrivacyTitle => 'إرسال هذا الإيصال إلى Firebase AI؟';

  @override
  String get receiptPrivacyMessage =>
      'تُرسل صورة الإيصال المحددة إلى Firebase AI لاستخراج البيانات. قد تتضمن الصور تفاصيل التاجر أو الشراء أو الضريبة أو العنوان. لا يرسل CashPilot أرصدة الحسابات أو سجل المعاملات معها. راجع جميع النتائج قبل التأكيد.';

  @override
  String get analyzeReceipt => 'تحليل الإيصال';

  @override
  String get manualReceiptReview => 'مراجعة يدوية';

  @override
  String get receiptReviewTitle => 'مراجعة الإيصال';

  @override
  String get receiptReviewSubtitle =>
      'قد يكون استخراج الذكاء الاصطناعي غير دقيق. لن تُحفظ أي معاملة حتى تؤكدها.';

  @override
  String get receiptMerchant => 'التاجر';

  @override
  String get receiptDocumentType => 'نوع المستند';

  @override
  String get receiptPaymentStatus => 'حالة الدفع';

  @override
  String get receiptPurchaseDate => 'تاريخ الشراء';

  @override
  String get receiptSubtotal => 'المجموع الفرعي';

  @override
  String get receiptTax => 'الضريبة';

  @override
  String get receiptDiscount => 'الخصم';

  @override
  String get receiptTip => 'الإكرامية';

  @override
  String get receiptTotal => 'الإجمالي';

  @override
  String get receiptLineItems => 'عناصر الإيصال';

  @override
  String get receiptAddLineItem => 'إضافة عنصر';

  @override
  String get receiptWarnings => 'التحذيرات';

  @override
  String get receiptKeepImage => 'الاحتفاظ بالصورة محلياً';

  @override
  String get receiptDeleteImage => 'حذف الصورة بعد الاستخراج';

  @override
  String get receiptRetentionRequired =>
      'اختر ما يجب أن يفعله CashPilot بالصورة المحلية.';

  @override
  String get receiptWarningsAcknowledgement =>
      'راجعت التحذيرات والقيم المستخرجة.';

  @override
  String get receiptSaveDraft => 'حفظ المسودة';

  @override
  String get receiptConfirmTransaction => 'تأكيد المعاملة';

  @override
  String get receiptCreatedMessage => 'تم إنشاء معاملة الإيصال.';

  @override
  String get receiptSavedMessage => 'تم حفظ مسودة الإيصال.';

  @override
  String get receiptNoAccounts => 'أضف حساباً قبل تأكيد هذا الإيصال.';

  @override
  String get receiptNoItems =>
      'أضف أو راجع عناصر الإيصال وتصنيفاتها قبل التأكيد.';

  @override
  String get receiptDuplicateWarning =>
      'تم العثور على إيصال أو معاملة مكررة محتملة.';

  @override
  String get receiptAnalysisProgress => 'جارٍ تحليل الإيصال بأمان…';

  @override
  String get receiptPreparingProgress => 'جارٍ تجهيز صورة الإيصال…';

  @override
  String get receiptSavingDraftProgress => 'جارٍ حفظ مسودة مراجعة خاصة…';

  @override
  String get receiptLoadingContextProgress =>
      'جارٍ تجهيز التصنيفات والحسابات للمراجعة…';

  @override
  String get aiLocalGreeting =>
      'أهلاً بيك! كيف نقدر نساعدك اليوم؟ اسألني شن نقدر ندير باش نوضح لك المزايا المتاحة حالياً.';

  @override
  String get aiLocalSmallTalk =>
      'تمام، شكراً لسؤالك! شن نقدر نساعدك فيه اليوم؟';

  @override
  String get aiCapabilityLocal =>
      'نقدر نرد على التحيات والمساعدة وأسئلة الإمكانيات محلياً من غير اتصال.';

  @override
  String get aiCapabilityGeneralChat =>
      'الأسئلة العامة مهيّأة عبر مزوّد بعيد، وكل طلب يتحقق من التوفر وقت الإرسال.';

  @override
  String get aiCapabilityCurrentKnowledge =>
      'البحث عن معلومات حديثة مهيّأ مع مصادر، وكل طلب يتحقق من التوفر وقت الإرسال.';

  @override
  String get aiCapabilityPersonalFinance =>
      'لما يظل نطاق المالك والموافقة صالحين، نقدر نحلّل بياناتك المالية المسموح بها داخل CashPilot.';

  @override
  String get aiCapabilityFinancialDrafts => 'نقدر نجهّز مسودات مالية للمراجعة.';

  @override
  String get aiCapabilityReceiptVision =>
      'تحليل صورة الإيصال مهيّأ بعد موافقتك، وكل طلب يتحقق من التوفر وقت الإرسال.';

  @override
  String get aiCapabilityNavigation =>
      'نقدر نفتح شاشات CashPilot المدعومة لما تطلب.';

  @override
  String get aiCapabilityFinancialDisabled =>
      'تحليل بياناتك والإجراءات المالية مش مفعّلين حالياً.';

  @override
  String get aiCapabilityConfirmationRequired =>
      'ما يصيرش أي تغيير مالي من غير مراجعتك وتأكيدك.';

  @override
  String get aiUnavailablePlatformNotConfigured =>
      'المحادثة العامة مش مهيّأة على هالمنصة. التحيات والمساعدة المحلية ما زالت متاحة.';

  @override
  String get aiUnavailableFirebaseNotInitialized =>
      'المحادثة العامة ما بدتش لأن Firebase مش جاهز. راجع إعداد التطبيق وحاول من جديد.';

  @override
  String get aiUnavailableFirebaseAi =>
      'نموذج المحادثة المهيّأ مش متاح حالياً.';

  @override
  String get aiUnavailableAppCheck =>
      'جاري تجهيز التحقق من الجهاز. حاول مرة أخرى بعد لحظات.';

  @override
  String get aiUnavailableAppCheckTimedOut =>
      'استغرق التحقق من الجهاز وقتًا أطول من المتوقع. تحقق من الاتصال وحاول مرة أخرى.';

  @override
  String get aiUnavailableAppCheckRejected =>
      'تعذر التحقق من نسخة التطوير على هذا الجهاز. تحقق من تسجيل App Check للمحاكي.';

  @override
  String get aiUnavailableAuthenticationNotReady =>
      'جاري تجهيز تسجيل الدخول. حاول مرة أخرى بعد لحظات.';

  @override
  String get aiUnavailableAuthentication =>
      'سجّل الدخول لاستخدام المحادثة العامة. التحيات والمساعدة المحلية متاحة بدون طلب للنموذج.';

  @override
  String get aiUnavailableGatewayDisabled =>
      'ما فيش مزوّد محادثة عامة مفعّل حالياً. التحيات والمساعدة المحلية ما زالت متاحة.';

  @override
  String get aiUnavailableGatewayUrlMissing =>
      'عنوان بوابة المحادثة مش مهيّأ، وما فيش مزوّد احتياطي متاح.';

  @override
  String get aiUnavailableGatewayUnreachable =>
      'تعذّر الوصول لخدمة المحادثة. تأكد من الاتصال وحاول من جديد.';

  @override
  String get aiUnavailableOffline =>
      'يبدو أن الجهاز غير متصل بالإنترنت. تحقق من الاتصال وحاول مرة أخرى.';

  @override
  String get aiUnavailableProviderTimedOut =>
      'خدمة المحادثة تأخرت في الرد. حاول من جديد.';

  @override
  String get aiUnavailableProviderRejected =>
      'خدمة المحادثة رفضت الطلب بأمان. عدّل صياغته أو حاول من جديد.';

  @override
  String get aiUnavailableFinancialAccess =>
      'الوصول إلى التحليل المالي الشخصي مش مفعّل حالياً.';

  @override
  String get aiUnavailableOwnerScope =>
      'بياناتك الخاصة في CashPilot مش جاهزة لهذا الطلب. المحادثة العامة والمساعدة المحلية ممكن تظل متاحة.';

  @override
  String get aiUnavailableLegacyData =>
      'التحليل المالي الشخصي متوقف لين تكتمل مراجعة ملكية البيانات القديمة.';

  @override
  String get aiUnavailableReceiptVision =>
      'تحليل صور الإيصالات مش متاح حالياً. تقدر تراجع بيانات الإيصال يدوياً.';

  @override
  String get aiUnavailableTemporary =>
      'تعذّر إكمال المحادثة مؤقتاً. حاول من جديد.';

  @override
  String get aiFinancialAnalysisUnavailableWithGeneral =>
      'المحادثة العامة متاحة، لكن تحليل بياناتك المالية مش مفعّل حالياً.';

  @override
  String get aiFinancialAnalysisUnavailable =>
      'تحليل بياناتك المالية مش مفعّل حالياً.';

  @override
  String get aiNavigationUnavailable =>
      'التنقّل من المساعد مش مفعّل حالياً. افتح الشاشة المطلوبة من القائمة.';

  @override
  String get aiDiagnosticCodeLabel => 'رمز التشخيص';

  @override
  String get aiOfflineInflationAnswer =>
      'التضخم هو ارتفاع عام ومستمر في أسعار السلع والخدمات مع الوقت، وهذا يعني أن نفس المبلغ يشتري أشياء أقل. يُقاس عادةً بمتابعة تغيّر أسعار سلة من الاحتياجات مثل الغذاء والسكن والنقل. التضخم البسيط قد يصاحب نمو الاقتصاد، لكن ارتفاعه بسرعة يضغط على القوة الشرائية والمدخرات.';

  @override
  String get aiOfflineTunisiaCapitalAnswer => 'عاصمة تونس هي مدينة تونس.';

  @override
  String get expenseAnalyticsTitle => 'تحليل المصروفات';

  @override
  String get expenseAnalyticsThisWeek => 'هذا الأسبوع';

  @override
  String get expenseAnalyticsThisMonth => 'هذا الشهر';

  @override
  String get expenseAnalyticsViewDetails => 'عرض التفاصيل';

  @override
  String get expenseAnalyticsTotal => 'إجمالي المصروفات';

  @override
  String get expenseAnalyticsPartialTotal => 'إجمالي جزئي';

  @override
  String get expenseAnalyticsOther => 'أخرى';

  @override
  String get expenseAnalyticsEmpty => 'ما عندكش مصروفات مسجلة في الفترة هذه.';

  @override
  String get expenseAnalyticsErrorTitle => 'تعذّر تحميل تحليل المصروفات';

  @override
  String get expenseAnalyticsErrorMessage =>
      'باقي معلومات الرئيسية ما زالت متاحة. حاول تحميل البطاقة من جديد.';

  @override
  String get expenseAnalyticsPartialWarning =>
      'بعض المصروفات غير داخلة في الإجمالي بسبب عدم توفر سعر الصرف.';

  @override
  String get expenseAnalyticsNoPreviousData =>
      'ما فيش بيانات كافية للمقارنة بالفترة السابقة.';

  @override
  String get expenseAnalyticsComparisonUnavailable =>
      'المقارنة مش متاحة لأن بعض أسعار الصرف ناقصة.';

  @override
  String get expenseAnalyticsLastWeek => 'الأسبوع الماضي';

  @override
  String get expenseAnalyticsLastMonth => 'الشهر الماضي';

  @override
  String expenseAnalyticsIncreasedComparison(String percentage, String period) {
    return 'مصروفاتك زادت $percentage مقارنة بـ$period.';
  }

  @override
  String expenseAnalyticsDecreasedComparison(String percentage, String period) {
    return 'مصروفاتك انخفضت $percentage مقارنة بـ$period.';
  }

  @override
  String expenseAnalyticsUnchangedComparison(String period) {
    return 'مصروفاتك ما تغيرتش مقارنة بـ$period.';
  }

  @override
  String expenseAnalyticsSemanticsSummary(
    String period,
    String total,
    String category,
    String categoryAmount,
    String percentage,
  ) {
    return 'إجمالي مصروفات $period هو $total. أعلى تصنيف $category بقيمة $categoryAmount، بنسبة $percentage.';
  }

  @override
  String expenseAnalyticsLegendSemantics(
    String category,
    String amount,
    String percentage,
  ) {
    return '$category، $amount، $percentage.';
  }

  @override
  String get aiFinancialPreviewTitle => 'مراجعة العملية';

  @override
  String get aiFinancialPreviewSubtitle =>
      'لن تُحفظ إلا هذه البيانات بعد موافقتك.';

  @override
  String get aiFinancialPreviewType => 'النوع';

  @override
  String get aiFinancialPreviewDescription => 'الوصف';

  @override
  String get aiFinancialPreviewSuggestedCategory => 'التصنيف المقترح';

  @override
  String get aiFinancialPreviewDate => 'التاريخ';

  @override
  String get aiFinancialPreviewStorageEffect => 'ما سيتم حفظه';

  @override
  String get aiFinancialPreviewToday => 'اليوم';

  @override
  String get aiFinancialPreviewReject => 'إلغاء';

  @override
  String get aiFinancialPreviewConfirm => 'تأكيد';

  @override
  String get aiFinancialPreviewRejected =>
      'تم إلغاء العملية، وما تمش حفظ أي تغيير.';

  @override
  String get aiFinancialPreviewCategoryAssumption =>
      'التصنيف مقترح بناءً على صياغة العملية.';

  @override
  String aiFinancialPreviewPostedExpenseEffect(String amount, String account) {
    return 'سيُحفظ مصروف منشور واحد، وسيُخصم $amount من $account.';
  }

  @override
  String aiFinancialPreviewPostedIncomeEffect(String amount, String account) {
    return 'سيُحفظ دخل منشور واحد، وستُضاف قيمة $amount إلى $account.';
  }

  @override
  String get aiFinancialPreviewPendingEffect =>
      'ستُحفظ معاملة معلّقة واحدة، ولن يتغير الرصيد حتى تُنشر.';

  @override
  String get aiFinancialExpenseSaved => 'تم تسجيل المصروف';

  @override
  String get aiFinancialIncomeSaved => 'تم تسجيل الدخل';

  @override
  String aiFinancialSavedSummary(String amount, String description) {
    return '$amount — $description';
  }

  @override
  String aiFinancialSavedCategory(String category) {
    return 'التصنيف: $category';
  }

  @override
  String aiFinancialSavedAccount(String account) {
    return 'الحساب: $account';
  }

  @override
  String aiFinancialSavedDate(String date) {
    return 'التاريخ: $date';
  }

  @override
  String aiFinancialSavedStatus(String status) {
    return 'الحالة: $status';
  }

  @override
  String get aiExpenseAccountClarification => 'من أي حساب تبي تسجل المصروف؟';

  @override
  String get aiFinancialActionsDisabledTitle =>
      'العمليات المالية بالذكاء الاصطناعي غير مفعلة لهذا الحساب.';

  @override
  String get aiFinancialActionsDisabledBody =>
      'فعّل «المراجعة قبل التنفيذ» أو «التحكم الكامل» من إعدادات AI.';

  @override
  String get aiOpenAiSettings => 'فتح إعدادات AI';

  @override
  String get aiControlOffFailure =>
      'ميزة تحكم المساعد في التطبيق غير مفعّلة لهذا الحساب. فعّلها من الإعدادات. لم يحدث أي تغيير.';

  @override
  String get aiTransactionDraftsDisabledFailure =>
      'مستوى تحكم المساعد المحدد لا يسمح بمسودات المعاملات. لم يحدث أي تغيير.';

  @override
  String get aiConfirmedExecutionDisabledFailure =>
      'التنفيذ المالي بعد التأكيد غير متاح في هذه النسخة. لم يحدث أي تغيير.';

  @override
  String get aiOwnerScopeNotReadyFailure =>
      'بيانات حسابك غير جاهزة لهذا الإجراء المالي. حاول بعد اكتمال تحميل الحساب. لم يحدث أي تغيير.';

  @override
  String get aiLegacyDataUnresolvedFailure =>
      'اربط البيانات المحلية الموجودة بهذا الحساب قبل إنشاء مسودة مالية. لم يحدث أي تغيير.';

  @override
  String get aiLegacyPolicyUnresolvedFailure =>
      'أكمل ترحيل سياسة تحكم المساعد لهذا الحساب من الإعدادات. لم يحدث أي تغيير.';

  @override
  String get aiStaleControlFailure =>
      'تغيرت إعدادات تحكم المساعد أثناء فتح المسودة. راجع الإعدادات الحالية وحاول مجددًا. لم يحدث أي تغيير.';

  @override
  String get aiGenericDraftPermissionFailure =>
      'صلاحية تحكم المساعد لا تسمح بهذه المسودة المالية. لم يحدث أي تغيير.';

  @override
  String get aiOpenSettings => 'فتح الإعدادات';

  @override
  String get aiFinancialWriteFailure =>
      'تعذّر الحفظ. لم تُحفظ أي معاملة ولم يتغير أي رصيد. حاول مجددًا.';

  @override
  String get aiStalePreviewFailure =>
      'معاينة العملية قديمة. أنشئ معاينة جديدة وراجعها من جديد.';

  @override
  String get aiDuplicateExecutionFailure =>
      'تم إرسال هذه العملية من قبل، ولم يتم إنشاء نسخة مكررة.';

  @override
  String get aiFinancialVerificationFailure =>
      'تعذر على كاش بايلوت التحقق من العملية المحفوظة، لذلك لم يتم عرض نجاح.';

  @override
  String get aiInvalidFinancialDraftFailure =>
      'تفاصيل العملية لم تعد صالحة. راجعها وحاول مجددًا.';
}
