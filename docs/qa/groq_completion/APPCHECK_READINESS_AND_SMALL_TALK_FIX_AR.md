# إصلاح جاهزية App Check عند البدء البارد ومسار المحادثة القصيرة

التاريخ: 2026-08-15 (Africa/Tripoli)  
الحالة: **الإصلاح المحلي والبناء ناجحان؛ القبول الحي النهائي محجوب حاليًا برفض Firebase للـDebug token الحالي (HTTP 403).**

## النتيجة المختصرة

- تم إصلاح سباق الجاهزية: لم يعد مسار Groq يفشل لمجرد أن تفعيل App Check ما زال في طور البدء؛ الطلب البعيد ينتظر منسقًا واحدًا محدود المدة قبل أي اتصال بـCloud Run.
- تم إصلاح التوجيه الحتمي للمحادثة القصيرة. الحالة المطلوبة `how are u` أصبحت `directConversation` محلية، مع بقاء الأسئلة الموضوعية الأطول على المسار البعيد.
- أضيف فصل typed بين: عدم الجاهزية المؤقت، الرفض المؤكد، انتهاء المهلة، عدم جاهزية Auth، وعدم الاتصال بالشبكة.
- Retry يعيد فحص الجاهزية ويعيد استخدام رسالة المستخدم القائمة من دون إنشاء فقاعة مستخدم أو رد مساعد مكرر.
- بقي Firebase text fallback معطلًا، وبقي App Check مفعلًا، ولم يُعدّل المنطق المالي أو خدمة Cloud Run.

## تصنيف العطل الأصلي

كان العطل مركبًا من سببين مستقلين:

1. **B — سباق جاهزية حتمي في التطبيق:** خطة المسار كانت تشترط أن يكون تفعيل App Check مكتملًا قبل السماح لمسار Groq. لذلك كان أول طلب بعيد بعد البدء البارد يُرفض محليًا قبل أن يتمكن مزود الرموز من انتظار التفعيل.
2. **A — رفض الرمز الحالي من Firebase:** فحص آمن للـDebug secret المُدار بواسطة SDK في الذاكرة فقط، باستخدام `projects.apps.exchangeDebugToken` الرسمي، أعاد HTTP 403. لم تُطبع أو تُخزّن قيمة الرمز. وفق مرجع Firebase، تنجح العملية فقط عندما يطابق السر رمز Debug منشأً/مسجلًا صالحًا.

نتيجة التصنيف قبل الإصلاح:

| الحقل الآمن | النتيجة |
|---|---|
| Firebase initialized | نعم |
| App Check activation | بدأ، لكن خطة المسار لم تكن تنضم إلى الجاهزية |
| typed classification | readiness race + current token rejected |
| gateway request started | لا في فشل السباق |
| provider/model | لم يبدأ اختيار النموذج في فشل ما قبل النقل |
| current debug token accepted | لا؛ HTTP 403 في آخر فحص آمن |

المرجع الرسمي: <https://firebase.google.com/docs/reference/appcheck/rest/v1/projects.apps/exchangeDebugToken>

## الإصلاح المعماري

أضيف `FirebaseAppCheckReadinessCoordinator` واحد على مستوى العملية، وتستخدمه محادثة Groq واختبار Settings الحي وRetry عبر مزود الرموز نفسه. حالات المنسق هي:

- `notStarted`
- `activating`
- `waitingForToken`
- `ready`
- `rejected`
- `timedOut`
- `unavailable`

السلوك:

- ينضم إلى تفعيل App Check الجاري بدل إنشاء سباق أو الفشل المبكر.
- يستخدم single-flight؛ الطلبات المتزامنة تشترك في عملية رمز واحدة.
- الحد الكلي 12 ثانية، وحد كل محاولة رمز ثانيتان.
- التأخيرات المحدودة: 0، 300، 700، 1500 مللي ثانية.
- لا يعيد محاولة رفض 403 تلقائيًا داخل النقل.
- الرفض المؤكد يُسجل كـ`appCheckRejected`، ويحتاج إجراء مستخدم جديد/Retry.
- مكالمة 401 typed من البوابة، وفشل SSE المكافئ، وHTTP 403 المجرد تُوحّد إلى الرفض نفسه.
- الإلغاء أو بدء محادثة جديدة أثناء الانتظار يمنع أي HTTP لاحق، والاكتمال المتأخر يُهمل بحارس generation.
- أُغلق سباق إضافي: رفض قديم لا يستطيع إلغاء تحديث أحدث مشترك بين Chat وSettings.

## المحادثة القصيرة

صار التطبيع يشمل حالة الأحرف، أشكال الفاصلة العليا، علامات الترقيم، والمسافات المتكررة، ثم يطابق قائمة قصيرة **مطابقة تامة**. لذلك:

- `how are u` ونظائرها الإنجليزية والعربية المطلوبة محلية.
- سؤال موضوعي أطول يحتوي صياغة مشابهة لا يُصنف كمحادثة قصيرة لمجرد احتوائه العبارة.
- الرد المحلي لا يدعي استعمال Groq.

## تجربة المستخدم وRetry

توجد رسائل محلية منفصلة للحالات التالية:

- App Check قيد التجهيز/غير متاح مؤقتًا.
- App Check مرفوض في نسخة التطوير.
- انتهت مهلة App Check.
- Firebase Auth غير جاهز.
- الجهاز غير متصل.

Retry يستدعي `requestRetry()` مرة واحدة، ثم يعيد الطلب المخزن مع `appendUserMessage: false`. الاختبارات تثبت انتهاء loading، وعدم تكرار رسالة المستخدم، وعدم إرسال أكثر من طلب بوابة واحد.

## مصفوفة الاختبارات المطلوبة

- البنود 1–15 مغطاة باختبارات router، المنسق، مزود الرموز، عميل Groq، controller، وwidget.
- البند 9 مغلق باختبار widget متكامل يثبت: صفر gateway calls، `isSending=false`، اختفاء loading، حالة `appCheckTimedOut`، وظهور Retry.
- البند 16 له اختبار process-fresh وعقد harness للـforce-stop/Launcher، لكن **الإثبات الحي إلى Groq لم يُنفذ** لأن الرمز الحالي مرفوض.
- البند 17 مغطى بإعدادات no-defines واختبارات Groq primary؛ الجولة الحية الحالية لم تُستكمل للسبب نفسه.
- البند 18 مغطى: Firebase text fallback بقي `false`.

## نتائج التحقق

| البوابة | النتيجة |
|---|---|
| اختبارات Flutter المركزة المشتركة | PASS، 217/217 |
| small-talk المركزة | PASS، 29/29 |
| routing/understanding المشتركة | PASS، 58/58 |
| Harness Node | PASS، 13/13 |
| Harness dry-run | PASS؛ device/package/Flutter متاحة، ولا build/install/uninstall أو App Check mutation |
| `flutter analyze --no-pub` | PASS، لا مسائل، 74.8s |
| `flutter test --no-pub -r compact` | PASS، 1334/1334 |
| `flutter build apk --debug --no-pub` | PASS، 55.4s |
| `git diff --check` | PASS؛ تحذيرات تحويل LF/CRLF فقط |
| فحص الأسرار الموجه | PASS؛ لا Groq key shape ولا credential assignment في ملفات الإصلاح الحساسة |

APK الناتج:

- المسار: `build/app/outputs/flutter-apk/app-debug.apk`
- الحجم: `204313783` بايت
- SHA-256: `8D6646796568300B7BB4B126E6E8CC8CB737D03F03B0A569165CC987DFC442FE`

## حالة القبول الحي

لم أزعم نجاح القبول الحي بعد الإصلاح. آخر فحص آمن للـDebug token الحالي أعاد 403، ولذلك لم أشغّل harness بوضع live ولم أُنشئ طلبات Groq مضللة.

يوجد تطبيق Debug مثبت أصلًا على `emulator-5554` والجهاز متصل، لكن APK الناتج بعد هذا الإصلاح **لم يُثبت كبديل عن مسار القبول**: تعليمات المهمة تشترط أن يتم التثبيت/التشغيل عبر الأمر الحرفي `flutter run -d emulator-5554` بلا wrapper أو defines. تشغيل ذلك المسار قبل قبول الرمز لن يحقق ردَّي Groq المطلوبين، لذلك بقي install/acceptance post-fix محجوبًا بدل تقديم إثبات ناقص.

الحالة الدقيقة:

| المطلوب | الحالة |
|---|---|
| `how are u` محلي | PASS في الاختبارات الحتمية وwidget؛ القبول الحي post-fix لم يُنفذ |
| prompt بعيد فور البدء البارد | BLOCKED / NOT RUN بسبب Debug token 403 |
| Retry بعد offline | BLOCKED / NOT RUN للسبب نفسه |
| force-stop/reopen ثم Groq | BLOCKED / NOT RUN للسبب نفسه |
| ردّان حقيقيان من Groq بعد plain `flutter run` | BLOCKED / NOT RUN |

المطلوب خارجيًا فقط: تسجيل Debug token الحالي يدويًا في Firebase Console، من دون لصقه في المحادثة أو المصدر. بعد أن تقبله Firebase، يُعاد الفحص الآمن ثم تُنفذ الجولة الحية بالأمر الحرفي:

```powershell
flutter run -d emulator-5554
```

لا يقوم التطبيق أو harness بتسجيل الرمز تلقائيًا، ولا يحذف تسجيلًا موجودًا.

## الخصوصية والنطاق

- لم تُطبع أو تُحفظ token أو UID أو نصوص الطلبات/الردود أو بيانات الحساب.
- لا توجد مفاتيح إدارية في Flutter أو harness.
- لم يتغير Cloud Run أو traffic أو Secret Manager أو Gateway source.
- لم يتغير المنطق المالي.
- لم يُفعّل Firebase text fallback.
- لم يُحذف Debug token قائم ولم يُنشأ تسجيل App Check تلقائي.

## الملفات التي عدلتها هذه المهمة

الإنتاج والتوصيل:

1. `lib/core/firebase/firebase_app_check_readiness.dart`
2. `lib/core/firebase/firebase_providers.dart`
3. `lib/features/ai_assistant/application/providers/ai_agent_providers.dart`
4. `lib/features/ai_assistant/data/gateway/firebase_gateway_token_provider.dart`
5. `lib/features/ai_assistant/data/gateway/groq_gateway_client.dart`
6. `lib/features/ai_assistant/domain/gateway/ai_conversation_gateway.dart`
7. `lib/features/ai_assistant/domain/services/ai_provider_route_resolver.dart`
8. `lib/features/ai_assistant/domain/entities/ai_capability.dart`
9. `lib/features/ai_assistant/domain/entities/ai_runtime_status.dart`
10. `lib/features/ai_assistant/application/agent/ai_agent_orchestrator_impl.dart`
11. `lib/features/ai_assistant/application/services/ai_runtime_status_probe.dart`
12. `lib/features/ai_assistant/application/services/ai_connection_diagnostic.dart`
13. `lib/features/ai_assistant/domain/agent/general_assistant_policy.dart`
14. `lib/features/ai_assistant/domain/services/ai_intent_router.dart`
15. `lib/features/ai_assistant/presentation/pages/ai_assistant_screen.dart`
16. `lib/shared/accessibility/acceptance_semantics.dart`

التعريب:

17. `lib/l10n/app_en.arb`
18. `lib/l10n/app_ar.arb`
19. `lib/l10n/app_localizations.dart`
20. `lib/l10n/app_localizations_en.dart`
21. `lib/l10n/app_localizations_ar.dart`

الاختبارات:

22. `test/core/firebase/firebase_app_check_readiness_test.dart`
23. `test/features/ai_assistant/ai_app_check_readiness_provider_test.dart`
24. `test/features/ai_assistant/firebase_gateway_token_provider_test.dart`
25. `test/features/ai_assistant/groq_gateway_client_test.dart`
26. `test/features/ai_assistant/ai_provider_route_resolver_test.dart`
27. `test/features/ai_assistant/ai_availability_test.dart`
28. `test/features/ai_assistant/ai_runtime_status_probe_test.dart`
29. `test/features/ai_assistant/ai_app_check_failure_ux_test.dart`
30. `test/features/ai_assistant/ai_agent_test.dart`
31. `test/features/ai_assistant/ai_agent_ui_test.dart`
32. `test/features/ai_assistant/ai_small_talk_routing_test.dart`

Harness القبول:

33. `tool/android_appcheck_smalltalk_acceptance_support.cjs`
34. `tool/android_appcheck_smalltalk_acceptance_support.test.cjs`
35. `tool/run_android_appcheck_smalltalk_acceptance.cjs`

التقرير:

36. `docs/qa/groq_completion/APPCHECK_READINESS_AND_SMALL_TALK_FIX_AR.md`

هذه القائمة تخص التغييرات المباشرة لهذه المهمة فقط؛ حُفظت بقية تعديلات worktree السابقة كما هي.
