# الحكم النهائي للاستخدام اليومي — CashPilot AI

التاريخ: 2026-08-11، المنطقة الزمنية: Africa/Tripoli.

القرار: **Android debug جاهز للاستخدام اليومي ضمن حدود السبرنت؛ Production release غير جاهز**.

## 1. لوحة القرار

| البعد | الحكم النهائي | الأساس |
|---|---|---|
| Code Ready | PASS | Analyzer ‏0 issues؛ Flutter ‏1187/1187 |
| Android Manual Acceptance | PASS_WITH_LIMITATIONS | 56 PASS؛ 0 FAIL؛ 4 BLOCKED من 60 |
| Firebase AI Live على Android | PASS | Vertex AI global؛ gemini-3.6-flash؛ العربية والإنجليزية وRetry نجحت |
| وظائف المال اليومية | PASS_WITH_LIMITATIONS | الحسابات والمعاملات والتحويل والميزانية والهدف والتقارير نجحت؛ pending edit غير متاح |
| Owner isolation | PASS | مستخدم ثانٍ لم ير بيانات أو سجل AI للمستخدم الأول |
| Receipt UI safety | PASS | navigation/retry/loading آمنة بصورة اصطناعية |
| Receipt live extraction | NOT_VERIFIED | لم ينجح استخراج vision/OCR حي ضمن القبول |
| Groq | EXTERNALLY_NOT_CONFIGURED | لا URL أو rollout أو live gate |
| Web code/build | PASS | build/Wasm/HTTP preflight خضراء |
| Web live/manual | BLOCKED_EXTERNAL | App Check وauthorized domains وbrowser/runtime |
| Production Release | NO-GO | applicationId والتوقيع وSHA وPlay Integrity/Google Sign-In والإعدادات الخارجية |

## 2. دليل الإغلاق

- Analyzer: 0 issues خلال 142.7s.
- Flutter full suite: 1187/1187 PASS.
- Android navigation integration: 1/1 PASS.
- Android debug build: PASS في 21.1s؛ APK ‏225344000 بايت؛ SHA-256 `1C64A74E62200D76B55E5B95A4FE638C671C7992006F1B928EAF2671D36BF0D6`.
- آخر clean-install smoke: install Success؛ COLD Status ok؛ TotalTime ‏4933ms؛ واجهة auth/onboarding ظاهرة؛ fatal markers=0. قياس retained-state السابق كان 3789ms، وHOT resume ‏117ms.
- Web build: PASS في 91.9s؛ Wasm dry-run؛ index/main/sqlite/worker HTTP 200.
- Firestore/Auth emulator: exit 0 خلال 143s.
- Gateway لم يتغير؛ بوابته السابقة 109/109.

## 3. القبول اليدوي

العد النهائي هو 60 خطوة بالضبط:

| PASS | FAIL | BLOCKED |
|---:|---:|---:|
| 56 | 0 | 4 |

الخطوات المحجوبة فقط:

1. لا توجد نتيجة `WARM` حقيقية؛ الأداة أعطت `HOT` فقط.
2. لم تُنفذ حقنة transient auth-loading الدقيقة يدويًا، رغم نجاح navigation integration ‏1/1.
3. تعديل معاملة pending غير متاح في شاشة التفاصيل.
4. لم يتوفر fixture يدوي يتجاوز 50 صفًا؛ pagination/search/sort العالمية خضراء آليًا EN/AR.

## 4. AI

أجاب المسار المحلي طلبين دون Firebase sessions، وأكمل المسار البعيد ثلاثة طلبات عبر Firebase AI Logic مع `firebaseSessions=3`. نجح المحتوى العربي والإنجليزي في الواجهة. عند تعطيل الشبكة انتهى loading بسبب `appCheckUnavailable` typed، لا `offline` حرفيًا؛ مُنع double-send، ثم نجح Retry دون تكرار دور المستخدم. نجحت المغادرة أثناء البث وNew Conversation والتمرير الطويل؛ regression المحادثة الجديدة أخضر أيضًا widget ‏2/2.

هذه النتيجة تجعل **Firebase AI جاهزًا على Android debug**، ولا تجعل Groq أو Web AI أو production App Check جاهزة.

## 5. العيوب الخمسة

| ID | الحالة | الدليل | الحد |
|---|---|---|---|
| FUNC-015 | Fixed Pending Manual Verification | 10000→50؛ 209797→1738µs؛ EN/AR ‏2/2 | لا fixture يدوي >50 |
| FUNC-016 | Fixed Pending Manual Verification | البحث والفلترة والفرز قبل LIMIT؛ manual صغير ناجح | لا long-history manual |
| FUNC-017 | Fixed Pending Manual Verification | 10020→20؛ 179125→1100µs؛ budget manual ناجح | لا device profile |
| FUNC-018 | Fixed Pending Manual Verification | 25/25؛ UI/navigation/retry آمنة | لا live extraction أو frame/memory profile |
| FUNC-028 | Fixed Pending Manual Verification | synthetic compatibility ‏22/22 | physical retained-device upgrade محجوب |

لم يعد أي من الخمسة `Reproduced`، ولا يدعي FUNC-028 migration فعلية.

## 6. القيود اليومية الظاهرة

- لا Edit للمعاملة pending من شاشة التفاصيل الحالية.
- تقرير السنة يعمل، لكن بعض labels داخل اللوحة ما زالت شهرية.
- لم يُختبر pagination يدويًا فوق 50 صفًا رغم الدليل الآلي.
- live receipt extraction غير مثبت؛ المثبت هو سلامة UI والفشل القابل للإعادة.
- snapshot الرسوم على emulator/debug: 570 frame، 347 janky بنسبة 60.88%، p50=18ms وp90=26ms وp95=34ms وp99=53ms. يلزم profile release على جهاز فعلي قبل أي ادعاء أداء إنتاجي.
- retained-device secure-storage upgrade ما زال يحتاج جهازًا يحتفظ ببيانات الإصدار السابق.

## 7. سجل العيوب والمحاسبة

توزيع 28 عيبًا: 22 `Fixed Pending Manual Verification`، و1 `Fixed Pending External Configuration`، و2 `Verified`، و3 `Blocked`، و0 `Reproduced`. FUNC-014 أصبح `Verified` لنجاح Firebase Android live؛ Groq وWeb حاجزان منفصلان.

حساب الجولة هو 55 مسارًا: 47 implementation/test/integration/tool، و7 تقارير، وملف baseline واحد. رقم 111 القديم لا يصف هذه الجولة.

## 8. الخصوصية والتنظيف

حُذف المستخدمان الاصطناعيان A وB بعد اختبار العزل. حُذف تسجيل App Check اليدوي الخاص بالسبرنت فقط مع الحفاظ على التسجيلين الآخرين. مُسح logcat بعد آخر smoke. لا تحتوي الأدلة tokens أو API keys أو UIDs أو owner scopes أو بيانات دخول أو نصوص prompts/responses.

## 9. شروط الانتقال إلى production

1. تحديد applicationId الإنتاجي وإعداد keystore وتوقيع release وSHA fingerprints.
2. إغلاق Play Integrity/App Check وGoogle Sign-In على Android production.
3. إغلاق App Check وauthorized domains/OAuth وallowed origins على Web إذا كان ضمن الإصدار.
4. تنفيذ release profile على جهاز فعلي ومعالجة الجَنك إن تكرر.
5. اختبار retained-device secure-storage upgrade الفعلي.
6. إثبات receipt live extraction إذا كانت الميزة ستعلن كجاهزة.

## 10. الحكم

يمكن استخدام Android debug يوميًا في الاختبار/التجربة الداخلية مع القيود المعلنة؛ لا يوجد فشل يدوي ضمن 60 خطوة، وFirebase AI الحي متاح. لا يجوز إعلان **production ready** أو **Web live ready** أو **Groq ready** أو **receipt vision ready** قبل إغلاق الشروط السابقة.

## 11. الملفات الدقيقة المنسوبة إلى جولة الإغلاق

المسارات التالية هي محاسبة الجولة الحالية عند cutoff، وعددها 55 مسارًا بالضبط. لا تشمل بقية الشجرة القذرة التي سبقت الجولة.

### Implementation وl10n (27)

- `lib/core/firebase/firebase_ai_backend.dart`
- `lib/core/logging/app_logger.dart`
- `lib/core/sync/data/sync_preferences_local_data_source.dart`
- `lib/features/ai_assistant/application/providers/ai_agent_providers.dart`
- `lib/features/ai_assistant/data/agent/firebase_ai_agent_model_gateway.dart`
- `lib/features/ai_assistant/data/datasources/firebase_ai_provider_data_source.dart`
- `lib/features/ai_assistant/domain/services/ai_intent_router.dart`
- `lib/features/ai_assistant/presentation/pages/ai_assistant_screen.dart`
- `lib/features/budgets/application/providers/budgets_providers.dart`
- `lib/features/budgets/data/budget_transactions_read_model.dart`
- `lib/features/data_deletion/data/datasources/account_deletion_session_proof_store.dart`
- `lib/features/receipts/application/receipt_providers.dart`
- `lib/features/receipts/data/providers/firebase_receipt_analysis_provider.dart`
- `lib/features/receipts/data/services/isolate_receipt_image_preparation_worker.dart`
- `lib/features/receipts/domain/services/receipt_image_preparation_worker.dart`
- `lib/features/receipts/domain/usecases/capture_receipt_image.dart`
- `lib/features/receipts/domain/usecases/import_receipt_image.dart`
- `lib/features/receipts/domain/usecases/prepare_receipt_image.dart`
- `lib/features/transactions/application/providers/transactions_providers.dart`
- `lib/features/transactions/data/transaction_history_read_model.dart`
- `lib/features/transactions/domain/entities/transaction_history_page.dart`
- `lib/features/transactions/presentation/pages/transactions_screen.dart`
- `lib/l10n/app_ar.arb`
- `lib/l10n/app_en.arb`
- `lib/l10n/app_localizations.dart`
- `lib/l10n/app_localizations_ar.dart`
- `lib/l10n/app_localizations_en.dart`

### Tests (14)

- `test/core/firebase/firebase_ai_backend_test.dart`
- `test/core/logging/app_logger_test.dart`
- `test/core/sync/sync_startup_repair_provider_test.dart`
- `test/features/ai_assistant/ai_agent_ui_test.dart`
- `test/features/ai_assistant/assistant_routing_regression_test.dart`
- `test/features/ai_assistant/firebase_ai_agent_model_gateway_test.dart`
- `test/features/budgets/budget_transactions_read_model_test.dart`
- `test/features/data_deletion/account_deletion_secure_storage_upgrade_compatibility_test.dart`
- `test/features/receipts/receipt_capture_usecases_test.dart`
- `test/features/receipts/receipt_image_preparation_worker_test.dart`
- `test/features/receipts/receipt_owner_scope_isolation_test.dart`
- `test/features/receipts/receipt_persistence_and_image_test.dart`
- `test/features/transactions/transaction_history_pagination_test.dart`
- `test/features/transactions/transactions_ui_test.dart`

### Android integration والـrunners (6)

- `integration_test/ai_navigation_device_regression_test.dart`
- `integration_test/android_live_ai_acceptance_test.dart`
- `integration_test/android_live_ai_failure_recovery_test.dart`
- `tool/android_app_check_probe.dart`
- `tool/run_android_live_ai_acceptance.cjs`
- `tool/run_android_live_ai_failure_recovery.cjs`

### التقارير والدليل (8)

- `docs/qa/functionality/FUNCTIONAL_DEFECTS.csv`
- `docs/qa/functionality/PERFORMANCE_BEFORE_AFTER.csv`
- `docs/qa/functionality/AI_AVAILABILITY_MATRIX_AR.md`
- `docs/qa/functionality/MANUAL_ACCEPTANCE_RESULTS_AR.md`
- `docs/qa/functionality/FULL_FUNCTIONAL_READINESS_AR.md`
- `docs/qa/functionality/ANDROID_LIVE_ACCEPTANCE_AR.md`
- `docs/qa/functionality/DAILY_USE_FINAL_VERDICT_AR.md`
- `docs/qa/functionality/evidence/live-android-closure-baseline.txt`
