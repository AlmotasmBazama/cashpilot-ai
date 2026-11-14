# تقرير إصلاح صلاحية المسودة والمعاينة المالية المدمجة

## الخلاصة

اكتمل إصلاح التناقض بين `Full Control` وبتّات الصلاحيات القديمة، وأصبح الأمر
المالي الواضح يُحلّل محليًا ويعرض معاينة نهائية مباشرة بدل سؤال yes/no. لا
تحدث أي كتابة قبل `Confirm`، ويؤدي `Reject` إلى إلغاء المسودة من دون خطأ أو
تغيير رصيد.

## الإنكار الأصلي الدقيق

النص المرئي الأصلي كان:

> CashPilot app-control permission does not allow this financial draft. No change was made.

السلسلة القديمة أثبتت مستويين من الإنكار:

- المسار الفعلي بعد جواب yes احتفظ بـ`AiIntent.unknown`، ولذلك أعاد الكود
  العام `permissionDenied` قبل استدعاء محلّل صلاحية مسودة المعاملة.
- عند تقييم السياسة نفسها كطلب `transactionDraft`، أول إنكار نوعي دقيق هو
  `transactionDraftsDisabled`.

إذًا لم يكن Groq ولا استمرار المحادثة سبب العطل. كان العرض العام يخفي سببًا
سياسيًا معروفًا، مع وجود مسار توجيه غير مناسب للأمر الواضح.

## السبب الجذري

1. سجل سياسة V2 المحفوظ كان يختار `Full Control`، لكنه احتفظ ببتّات false
   من واجهة المفاتيح المستقلة القديمة. كانت سجلات V1 تُعاد بناؤها من المستوى،
   أما V2 فلم تكن تُطبّع.
2. العبارة الواضحة item+money كانت تُوجّه إلى `financialRecordOffer` بنية
   `unknown`؛ لهذا ظهر سؤال yes/no ثم الإنكار العام.
3. لم تكن واجهة الإعدادات تجعل مستوى التحكم مصدر الموافقة الوحيد؛ أمكن رؤية
   مستوى كامل مع مفاتيح متناقضة.

## السياسة قبل وبعد

| الحقل | قبل | بعد |
|---|---:|---:|
| مستوى التحكم | Full Control | Full Control |
| صلاحية مسودة المعاملة | false | true |
| صلاحية التنفيذ بعد التأكيد | false | true |
| revision في جلسة إعادة الإنتاج | 1 | موجب ويتجدد عند كل حفظ |
| provenance | persistedUserSelection | persistedUserSelection |
| owner scope ready | true | true |
| app-control flag | true | true |
| create-drafts flag | true | true |
| confirmed-execution flag | true | true |
| local-dataset flag | true | true |

أصبح `setLevel` والقراءة من Hive والحفظ وكل setters العامة يعيدون بناء
الصلاحيات المدعومة من المستوى المختار. تبقى العائلات غير المدعومة false،
ويبقى التأكيد الصريح إلزاميًا في Review Before Execution وFull Control.
اختيار Off الصريح يبقى Off، وإصدار Release يظل fail-closed.

## التدفق الجديد

- العبارات الواضحة للمصروف/الدخل تمر إلى مسار مالي مباشر.
- عبارات الحليب والقهوة والوقود والخبز والبقالة المحدودة تُحلل محليًا ولا
  تحتاج Groq.
- `milk 5 dinar` ينتج `Decimal(5)` بعملة LYD، ويستخدم الحساب الافتراضي فقط
  وفق القواعد الموجودة، ويقترح Groceries، ويضع تاريخ اليوم والحالة Posted.
- إذا لم يوجد حساب صالح، أو وُجد أكثر من حساب محتمل، يظهر سؤال واحد مختصر؛
  لا يُخترع حساب.
- أزيل سؤال `Would you like to record this financial activity?` من الأوامر
  الواضحة، وأصبحت البطاقة نفسها طلب التأكيد.

## بطاقة المعاينة

المكوّن الجديد هو `AiFinancialStoragePreviewCard`. يعرض فقط:

- النوع
- المبلغ
- الوصف
- التصنيف المقترح
- الحساب
- التاريخ
- الحالة
- ما سيتم حفظه وأثر الرصيد
- `Reject` و`Confirm` فقط

لا يعرض IDs أو owner scope أو JSON أو provider/model أو raw prompt أو مصطلحات
قاعدة البيانات. دعم الاختبار English LTR وArabic RTL وLight وDark وعرض 320px
وتكبير النص 1.6. بقيت المحددات اللازمة لإكمال حقل ناقص قبل البطاقة النهائية.

## الرفض والتأكيد والأخطاء

- Reject يلغي الأمر الدائم، ويبطل سلطة التأكيد، ويزيل البطاقة، ويعرض رسالة
  محايدة. لا معاملة ولا أثر رصيد ولا بطاقة حمراء.
- Confirm يعيد فحص المالك والسياسة وrevision والمراجع وحداثة المعاينة، ثم
  يستهلك proof واحدة وينفّذ عبر CreateTransaction وFinance Engine، ولا يعرض
  النجاح إلا بعد التحقق.
- تأكيدان متزامنان يُنتجان معاملة واحدة فقط.
- فشل قاعدة البيانات يعرض رسالة عدم الحفظ/عدم تغير الرصيد مع Retry. إعادة
  المحاولة تنشئ معاينة جديدة وتتطلب Confirm صريحًا آخر؛ لا تنفّذ تلقائيًا.
- Off يعرض سببًا دقيقًا مع فتح الإعدادات. owner scope غير الجاهز يعرض رسالة
  تجهيز الحساب. لم يعد السبب المعروف يتحول إلى الرسالة العامة القديمة.

## نتائج الاختبار

- اختبارات المساعد: 862/862 ناجحة.
- الحزمة الكاملة: 1738/1738 ناجحة.
- `flutter analyze --no-pub`: لا مشاكل.
- APK Debug: ناجح في `build/app/outputs/flutter-apk/app-debug.apk`.
- Web: ناجح في `build/web`، ونجح Wasm dry run.
- fixture التنفيذ: Reject أبقى 0/100؛ Confirm مزدوج أعطى 1/95؛ إعادة فتح
  المنفّذ لم تعِد التنفيذ وبقيت 1/95.

## القبول الحي

النسخة الجديدة ثُبتت على `emulator-5554`. ظهرت المعاينة مباشرة دون yes/no أو
خطأ صلاحية. بعد Reject بقي الحساب الحي 1150 د.ل وعدد المعاملات 2. لم يُنفذ
Confirm على الحساب الحي لأنه مصادق عليه ومتصل بنسخ سحابي وليس fixture 100
د.ل. لا يدّعي هذا التقرير قبولًا حيًا للطفرة؛ إثبات 100→95 معزول ومذكور في
`LIVE_ACCEPTANCE_AR.md`.

## الملفات المعدلة لهذه المهمة

### الإنتاج

- `lib/features/ai_assistant/application/app_agent/ai_app_control_permission_resolver.dart`
- `lib/features/ai_assistant/application/providers/ai_app_control_providers.dart`
- `lib/features/ai_assistant/application/services/ai_assistant_conversation_workflow_controller.dart`
- `lib/features/ai_assistant/data/app_agent/hive_ai_app_control_settings_store.dart`
- `lib/features/ai_assistant/domain/app_agent/ai_app_control_settings.dart`
- `lib/features/ai_assistant/domain/services/ai_intent_router.dart`
- `lib/features/ai_assistant/domain/services/financial_command_parser.dart`
- `lib/features/ai_assistant/domain/usecases/create_ai_action_draft.dart`
- `lib/features/ai_assistant/presentation/pages/ai_assistant_screen.dart`
- `lib/features/ai_assistant/presentation/widgets/ai_action_confirmation_card.dart`
- `lib/features/ai_assistant/presentation/widgets/ai_financial_storage_preview_card.dart`
- `lib/features/ai_assistant/presentation/widgets/ai_verified_action_card.dart`
- `lib/features/settings/presentation/widgets/ai_app_control_settings_section.dart`
- `lib/shared/design_system/widgets/cp_skeleton.dart`
- `lib/l10n/app_en.arb`
- `lib/l10n/app_ar.arb`
- `lib/l10n/app_localizations.dart`
- `lib/l10n/app_localizations_en.dart`
- `lib/l10n/app_localizations_ar.dart`

### الاختبارات

- `test/features/ai_assistant/ai_action_confirmation_card_test.dart`
- `test/features/ai_assistant/ai_action_test.dart`
- `test/features/ai_assistant/ai_app_control_permission_resolver_test.dart`
- `test/features/ai_assistant/ai_app_control_policy_modes_test.dart`
- `test/features/ai_assistant/ai_assistant_send_test.dart`
- `test/features/ai_assistant/ai_financial_storage_preview_card_test.dart`
- `test/features/ai_assistant/ai_income_finance_engine_integration_test.dart`
- `test/features/ai_assistant/assistant_routing_regression_test.dart`
- `test/features/ai_assistant/financial_command_parser_compact_confirmation_test.dart`
- `test/features/ai_assistant/financial_record_offer_routing_test.dart`

`cp_skeleton.dart` أصلح overflow عابرًا قدره 3px كشفته الحزمة الكاملة في
shell العربي الضيق. تغييرات تحليلات Home الأخرى الموجودة في شجرة العمل تخص
مهمة سابقة وليست ضمن هذا التقرير.

## الأدلة

- `TEST_MATRIX.csv`
- `LIVE_ACCEPTANCE_AR.md`
- `evidence/ORIGINAL_DENIAL_TRACE.txt`
- `evidence/SYNTHETIC_EXECUTION_RESULTS.txt`
- `evidence/VALIDATION_RESULTS.txt`
- `screenshots/`
