# تقرير إكمال Groq كمزوّد النص الأساسي — CashPilot AI

التاريخ: 2026-08-14 (Africa/Tripoli).

الحالة الحالية: **Groq منشور على Cloud Run والمراجعة `00005-civ` تخدم 100%؛
اكتمل force-stop/reopen الحقيقي والسؤال الثاني، والمسار جاهز للاستخدام الداخلي اليومي
على بيئة staging/debug ضمن القيود الموثقة أدناه.**

## الخلاصة التنفيذية

أصبح مسار النص البعيد في Flutter يختار Groq صراحةً عند تفعيل أعلام Groq، مع
تعطيل Firebase text fallback افتراضيًا. بقيت التحيات والرسائل الحتمية محلية،
واستخراج الأوامر المالية حتميًا/محليًا، والتنفيذ المالي معطلًا، بينما بقي
Receipt Vision على Firebase بصورة مستقلة. Firebase Authentication وFirebase
App Check لم يُزالا؛ هما بوابة الدخول الإلزامية إلى مسارات Cloud Run.

المرشح النهائي المنشور هو
`cashpilot-ai-gateway-staging-00005-civ` في `europe-west1`. جرى اختباره عند
0% من الحركة، وظلت المراجعة القديمة `00002-sww` تخدم 100% أثناء القبول. الرابط
الثابت للخدمة هو
`https://cashpilot-ai-gateway-staging-yfgt2ypuvq-ew.a.run.app`، ورابط المرشح
الموسوم هو
`https://groq-candidate---cashpilot-ai-gateway-staging-yfgt2ypuvq-ew.a.run.app`.
بعد نجاح القبول نُقلت الحركة صراحةً إلى `00005-civ=100%` في 22.021s، ثم نجح
الرابط الثابت 3/3 وبقيت نقطة التراجع `00002-sww` موجودة بلا حركة موجبة.

## الحاجز الأصلي وما تغيّر

كان Groq موجودًا في المصدر لكنه لم يكن المزوّد النصي الفعلي: أعلامه كانت
معطلة افتراضيًا، و`auto` كان يختار Firebase أو يرجع إليه بصمت، وكان الشرح
المالي مقترنًا باختيار الأدوات، والعميل يعيد إرسالًا تلقائيًا، ولم تكن البوابة
تبث المحتوى تدريجيًا أو تطبق taxonomy/health/retry المطلوبين. كما لم يوجد دليل
نشر حي، ولا تحقق Models API، ولا قبول Android مباشر لـGroq.

أُغلق ذلك عبر:

- اختيار Groq وحده للنص في إعداد القبول، واشتراط الأعلام العامة/الخاصة حتى مع
  `provider=groq` لكي يعمل rollback فعلًا.
- علم مستقل `CASH_PILOT_AI_FIREBASE_TEXT_FALLBACK_ENABLED=false` افتراضيًا.
- بث SSE حقيقي، حدود line/event/stream/output، وإلغاء upstream عند قطع العميل.
- إعادة واحدة فقط قبل أي محتوى وللأخطاء العابرة، مع jitter و`Retry-After`
  محدود؛ لا إعادة تلقائية من Flutter.
- نماذج ثابتة في الخادم، وفحص Models API وقت النشر، ورفض model override.
- مسار قراءة مالية حتمي محلي ثم شرح Groq من دون تمكين tool-selection أو تنفيذ
  مالي.
- أخطاء typed ورسائل Retry العربية/الإنجليزية، وحدود مهلة منسقة:
  Groq 20s < gateway 30s < Flutter 40s < orchestrator 45s.

## حالة البوابة المحلية

- `npm test`: **PASS 123/123**.
- `npm run lint`: **PASS**.
- `npm run typecheck`: **PASS**.
- `npm run build`: **PASS**.
- `npm run secret-scan`: **PASS**.
- Dockerfile فُحص، وCloud Build بنى الصورة بنجاح. Docker CLI المحلي لم يكن
  متاحًا، وكان اختبار المضيف على Node 26 بينما صورة الخدمة تستهدف Node 20.

كشف القبول الحي عيبين لم تكن تغطيهما الجولة الأولى: مطابقة `تم` داخل `يتم`
في أمان الرد العربي، وتطبيق regex رقم الهاتف على UUID داخلي. أُصلح الأول
بحدود Unicode عربية، وأصبح فحص الخصوصية path-aware بحيث تبقى الرسائل والـlabels
محمية ولا تُفحص metadata البنيوية كأنها نص خاص.

## حالة Cloud Run وSecret Manager

| الحقل | القيمة المثبتة |
|---|---|
| المشروع | `cashpilot-ai-a6b49` |
| الخدمة | `cashpilot-ai-gateway-staging` |
| المنطقة | `europe-west1` |
| المرشح النهائي | `cashpilot-ai-gateway-staging-00005-civ` |
| وقت الإنشاء | `2026-08-14T10:55:10.505708Z` |
| جاهزية/حركة المراجعة | Ready=true؛ 0% أثناء القبول ثم 100% بعد الترويج |
| الصورة | digest يطابق Cloud Build النهائي |
| CPU / الذاكرة | 1 CPU / 512MiB |
| concurrency / timeout | 80 / 60s |
| min / max instances | 0 أو unset / 1 |
| diagnostics / tool-selection | false / false |
| Secret Manager | المراجعة النهائية مربوطة بـ`cashpilot-groq-api-key:latest`؛ تحقق خط الأساس من أن الإصدار 1 كان enabled، ولم تُقرأ أي قيمة |
| GROQ_API_KEY في Flutter/المصدر | غير موجود |

اختيرت `europe-west1` لأنها منطقة الخدمة القائمة؛ الاستمرار فيها يمنع ترحيلًا
إقليميًا غير لازم ويحافظ على أبسط مسار تشغيل وتراجع. لم يُرفع min instances
إلى 1 لعدم وجود موافقة تكلفة. health المرشح كان 574/117/102ms، وبعد الترويج
كان الرابط الثابت 331/106/92ms، وكلها HTTP 200/no-store/ready=true.

## التحقق الحي للنماذج

استخدم verifier وقت النشر قيمة Secret Manager في الذاكرة فقط، وكانت النتيجة:

- `openai/gpt-oss-20b`: **ACTIVE** — النموذج العام النهائي.
- `openai/gpt-oss-120b`: **ACTIVE** — نموذج الشرح المالي النهائي.

لا يستطيع Flutter إرسال model ID، ولا تستدعي `/health` قائمة النماذج في كل
طلب. شغلت المقارنة paced نفس 15 حالة عربية و10 إنجليزية على كل نموذج:

- 20b: ‏25/25، median/p95 TTFC ‏332/482ms، وcompletion ‏834/1029ms.
- 120b: ‏25/25، median/p95 TTFC ‏367/457ms، وcompletion ‏1370/1493ms.
- كل rubrics الحتمية الأربعة نجحت 25/25 لكليهما. لا تُعد هذه proxies بديلًا
  عن مراجعة بشرية للنص الكامل، الذي لم يُحفظ حفاظًا على الخصوصية.

اختير 20b للمحادثة العامة لأن reliability/proxy quality متساويتان وكان median
completion أقل، وبقي 120b للشرح المالي المحدود. حُفظت الجولة غير paced أيضًا؛
أظهرت 429 بدل إخفائها ثم نجحت إعادة القياس بسرعة مستدامة.

## Auth وApp Check وHTTP

- HTTP matrix: **PASS 24/24**.
- no/invalid Auth: رُفضا بـ`gatewayAuthenticationRequired`.
- valid Auth مع missing/invalid App Check على Android: رُفضا حيًا HTTP 401
  بـ`gatewayAppCheckRequired`.
- valid synthetic Auth + Android Debug App Check: قُبلا حيًا.
- native Android بلا `Origin`: وصل إلى auth ولم يُرفض كـCORS.
- origin المسموح الدقيق/preflight: PASS؛ disallowed/wildcard: 403.
- non-JSON/malformed/oversized/method/unknown route: أكواد آمنة صحيحة.
- كل الأخطاء المرصودة: `Cache-Control: no-store`.
- revoked/wrong-project/expired attestation بقيت محاكاة محلية/اختبارات، وليست
  دورة credential حية مدمرة في هذا السبرنت.

## قبول Android الحي

الجهاز: Pixel_6 emulator، Android 17/API 37. لا يوجد جهاز مادي متصل.

| الحالة | النتيجة | أول محتوى | الاكتمال | deltas / partials / bytes |
|---|---|---:|---:|---|
| العربية | PASS | 1657ms | 2113ms | 240 / 8 / 1471 |
| الإنجليزية | PASS | 1430ms | 1435ms | 21 / 1 / 300 |
| إلغاء بث حي | PASS | 1246ms | cancel 9ms | 1 delta؛ صفر late/completed/failure |
| force-stop ثم سؤال ثانٍ | PASS | UI غير مقاس؛ server 368/317ms | 17418ms ثم 17076ms | PID قديم غاب؛ PID جديد مختلف خلال 3709ms |

اختار سجل Cloud الآمن `openai/gpt-oss-20b` ونجح upstream. لم تُنشأ أي
Firebase AI text object في harness؛ استخدمت Firebase للمصادقة وApp Check فقط.
لا duplicate response ولا empty success ولا رسالة عامة «AI unavailable» في
الحالتين الناجحتين.

نجح أيضًا مسار واجهة التطبيق الكامل في debug APK بأدوات الإنتاج والراوتر الفعلي:
اكتمل سؤال Groq أول، أوقف Android العملية قسريًا، فُتح التطبيق صراحةً عبر
`MAIN/LAUNCHER` بعملية جديدة، استُعيدت الجلسة، ثم اكتمل سؤال Groq ثانٍ. أكد سجلا
Cloud Run المنقحان أن الطلبين استخدما `openai/gpt-oss-20b` وأعادا HTTP 200/
`completed` بلا retry؛ TTFC على الخادم كان 368ms و317ms. أزمنة 17.4s و17.1s
هي زمن قبول UI end-to-end مع polling وليست بديلًا عن قياسات SSE المباشرة أعلاه.

## Offline وRetry وrate limit

- قطع شبكة المحاكي: loading ظهر ثم انتهى، والسبب typed هو
  `gatewayUnreachable` وقابل للإعادة.
- double-send أثناء الانتظار: ممنوع.
- بقي user turn واحد ظاهرًا.
- بعد إعادة الشبكة وضغطة Retry واحدة: اكتمل Groq، دون تكرار الرسالة أو الرد.
- rate limit: 20 طلبًا مسموحًا، الطلب 21 أعاد HTTP 429/
  `groqRateLimited` مع `Retry-After`، ومستخدم ثانٍ بقي معزولًا.
- اختبار المعدل استخدم tool-selection المعطل، ولذلك لم يستهلك طلبات Groq.

## الإلغاء ودورة الحياة

نجح الإلغاء الحي العام بعد أول text delta مع صفر late events. كما نجحت اختبارات
widget/unit الخاصة بالمغادرة، ومحادثة جديدة، والإيقاف، وlogout/account switch،
والخلفية/inactive/hidden. كشف اختبار المغادرة تعديل Riverpod تزامنيًا أثناء
dispose؛ أصبح الإلغاء microtask مع `ref.mounted` guard.

الدليل الحي العام لا يساوي تنفيذ كل trigger UI حيًا على جهاز مادي؛ لذلك بقيت
هذه التغطية موضحة في `GROQ_BLOCKERS.csv` بدل المبالغة في الادعاء.

## Flutter والبناء

- `flutter test --no-pub -r compact`: **PASS 1225/1225**.
- `flutter analyze --no-pub`: **PASS، No issues found**.
- `flutter build apk --debug --no-pub` مع App Check وGroq staging defines:
  **PASS**؛ `build/app/outputs/flutter-apk/app-debug.apk`.
- focused lifecycle/UI: 13/13.
- force-stop runner/support Node tests: **PASS 24/24**، وfocused design-system/UI:
  **PASS 18/18**.
- بناء/تثبيت debug APK في تشغيل force-stop الحي: **PASS خلال 21058ms**.
- runner/evaluation Node tests الأخرى: PASS.

## التوجيه النهائي للقدرات

| القدرة | المسار النهائي |
|---|---|
| direct deterministic | محلي |
| general remote text | Groq gateway |
| personal financial explanation | قراءة محلية حتمية ثم Groq 120b عند تفعيل capability |
| financial command extraction | parser محلي حتمي |
| financial execution | workflow محلي محكوم؛ AI execution معطل |
| receipt images | Firebase Vision مؤقتًا |
| Auth / attestation | Firebase Auth + Firebase App Check |
| current web / tool selection | معطلان |
| Firebase ordinary-text fallback | معطل افتراضيًا؛ لا يعمل إلا بعلم صريح منفصل |

## الرصد والتشغيل

السجل المنظم لا يحوي إلا request ID، endpoint، app version، platform، model،
status/error code، durations/TTFT/completion، retry count وrate-limit result.
يمنع prompt/response/UID/Auth/App Check/API key/financial history/receipt text.

يجب إنشاء Cloud Monitoring alerts قبل الإنتاج لـ5xx، وفشل Groq، وارتفاع رفض
Auth/App Check، و429، والمهل، وp95، وفشل startup. التعريفات موثقة، لكن قنوات
الإشعار والسياسات الفعلية تحتاج موافقة مالك المشروع.

## الملفات التي غيّرها هذا السبرنت

الشجرة كانت تحتوي قبل البداية على 370 status entries و489 ملفًا untracked؛
القائمة أدناه هي قائمة الملفات المقصودة الدقيقة لهذا السبرنت (101 ملفًا) ولا
تنسب العمل السابق إليه. أعاد `npm run build` توليد مشتقات `services/cashpilot_ai_gateway/dist/**`؛
هذه نواتج build وليست تعديلات مصدر، وهي مستبعدة من حزمة Cloud Build بواسطة
`.gcloudignore`، لذلك لا تُعد ضمن ملفات المصدر/التقارير الـ101 أدناه.

### إعداد وأدلة وتقارير

- `config/groq_staging.json`
- `docs/qa/groq_completion/GROQ_PRIMARY_COMPLETION_AR.md`
- `docs/qa/groq_completion/GROQ_LIVE_ACCEPTANCE_AR.md`
- `docs/qa/groq_completion/GROQ_MODEL_EVALUATION.csv`
- `docs/qa/groq_completion/GROQ_PERFORMANCE.csv`
- `docs/qa/groq_completion/GROQ_DEPLOYMENT_CONFIG_AR.md`
- `docs/qa/groq_completion/GROQ_ROLLBACK_AR.md`
- `docs/qa/groq_completion/GROQ_BLOCKERS.csv`
- `docs/qa/groq_completion/evidence/android-live-acceptance.txt`
- `docs/qa/groq_completion/evidence/cloud-baseline.txt`
- `docs/qa/groq_completion/evidence/cloud-deployment.txt`
- `docs/qa/groq_completion/evidence/force-stop-reopen.txt`
- `docs/qa/groq_completion/evidence/http-security-matrix.txt`
- `docs/qa/groq_completion/evidence/local-gates.txt`
- `docs/qa/groq_completion/evidence/model-eval-20b.csv`
- `docs/qa/groq_completion/evidence/model-eval-20b-paced.csv`
- `docs/qa/groq_completion/evidence/model-eval-120b.csv`
- `docs/qa/groq_completion/evidence/model-eval-120b-paced.csv`
- `docs/qa/groq_completion/evidence/model-evaluation-summary.txt`
- `docs/qa/groq_completion/evidence/model-verification.txt`
- `docs/qa/groq_completion/evidence/offline-retry.txt`
- `docs/qa/groq_completion/evidence/rate-limit.txt`
- `docs/qa/groq_completion/evidence/worktree-baseline.txt`

### Gateway

- `services/cashpilot_ai_gateway/.dev.vars.example`
- `services/cashpilot_ai_gateway/.gcloudignore`
- `services/cashpilot_ai_gateway/README.md`
- `services/cashpilot_ai_gateway/package.json`
- `services/cashpilot_ai_gateway/scripts/verify-groq-models.ts`
- `services/cashpilot_ai_gateway/src/config.ts`
- `services/cashpilot_ai_gateway/src/contracts/gateway.ts`
- `services/cashpilot_ai_gateway/src/errors.ts`
- `services/cashpilot_ai_gateway/src/groq/groq_client.ts`
- `services/cashpilot_ai_gateway/src/groq/model_router.ts`
- `services/cashpilot_ai_gateway/src/groq/response_parser.ts`
- `services/cashpilot_ai_gateway/src/index.ts`
- `services/cashpilot_ai_gateway/src/routes/diagnostics.ts`
- `services/cashpilot_ai_gateway/src/routes/financial_explanation.ts`
- `services/cashpilot_ai_gateway/src/routes/general_chat.ts`
- `services/cashpilot_ai_gateway/src/routes/health.ts`
- `services/cashpilot_ai_gateway/src/routes/shared.ts`
- `services/cashpilot_ai_gateway/src/routes/tool_selection.ts`
- `services/cashpilot_ai_gateway/src/security/cors_policy.ts`
- `services/cashpilot_ai_gateway/src/security/provider_output_safety.ts`
- `services/cashpilot_ai_gateway/src/security/redaction.ts`
- `services/cashpilot_ai_gateway/src/security/request_limits.ts`
- `services/cashpilot_ai_gateway/src/security/safe_stream_trace.ts`
- `services/cashpilot_ai_gateway/tests/gateway.test.ts`
- `services/cashpilot_ai_gateway/tests/general_chat_safety.test.ts`
- `services/cashpilot_ai_gateway/tests/groq_completion.test.ts`
- `services/cashpilot_ai_gateway/tests/provider_output_safety.test.ts`
- `services/cashpilot_ai_gateway/tests/security.test.ts`

### Flutter وAndroid tests

- `lib/features/ai_assistant/application/agent/ai_agent_orchestrator_impl.dart`
- `lib/features/ai_assistant/application/providers/ai_agent_providers.dart`
- `lib/features/ai_assistant/application/services/ai_connection_diagnostic.dart`
- `lib/features/ai_assistant/data/config/ai_gateway_feature_flags.dart`
- `lib/features/ai_assistant/data/gateway/buffered_sse_decoder.dart`
- `lib/features/ai_assistant/data/gateway/firebase_gateway_token_provider.dart`
- `lib/features/ai_assistant/data/gateway/groq_gateway_client.dart`
- `lib/features/ai_assistant/data/gateway/groq_gateway_data_source.dart`
- `lib/features/ai_assistant/data/gateway/routed_ai_agent_model_gateway.dart`
- `lib/features/ai_assistant/domain/agent/ai_agent_models.dart`
- `lib/features/ai_assistant/domain/agent/general_assistant_policy.dart`
- `lib/features/ai_assistant/domain/entities/ai_capability.dart`
- `lib/features/ai_assistant/domain/gateway/ai_conversation_gateway.dart`
- `lib/features/ai_assistant/presentation/pages/ai_assistant_screen.dart`
- `lib/features/app_shell/presentation/pages/app_shell_page.dart`
- `lib/features/auth/presentation/pages/login_screen.dart`
- `lib/features/auth/presentation/pages/onboarding_screen.dart`
- `lib/features/auth/presentation/pages/welcome_screen.dart`
- `lib/features/dashboard/presentation/pages/dashboard_screen.dart`
- `lib/features/settings/presentation/pages/settings_screen.dart`
- `lib/shared/accessibility/acceptance_semantics.dart`
- `lib/shared/design_system/widgets/cp_bottom_navigation.dart`
- `lib/shared/design_system/widgets/cp_button.dart`
- `lib/shared/design_system/widgets/cp_text_field.dart`
- `integration_test/android_live_groq_acceptance_test.dart`
- `integration_test/android_live_groq_failure_recovery_test.dart`
- `integration_test/android_live_groq_rate_limit_test.dart`
- `integration_test/support/android_live_groq_app_check.dart`
- `integration_test/firebase_ai_smoke_test.dart` (إزالة debris syntax وحيد)
- `test/features/ai_assistant/ai_agent_test.dart`
- `test/features/ai_assistant/ai_agent_ui_test.dart`
- `test/features/ai_assistant/ai_availability_test.dart`
- `test/features/ai_assistant/ai_connection_diagnostic_test.dart`
- `test/features/ai_assistant/ai_gateway_feature_flags_test.dart`
- `test/features/ai_assistant/ai_provider_egress_owner_race_test.dart`
- `test/features/ai_assistant/buffered_sse_decoder_test.dart`
- `test/features/ai_assistant/firebase_ai_agent_model_gateway_test.dart`
- `test/features/ai_assistant/firebase_gateway_token_provider_test.dart`
- `test/features/ai_assistant/groq_gateway_client_test.dart`
- `test/features/ai_assistant/routed_ai_agent_model_gateway_test.dart`

### أدوات القبول والتقييم

- `tool/android_live_groq_runner_support.cjs`
- `tool/android_live_groq_runner_support.test.cjs`
- `tool/run_android_live_groq_acceptance.cjs`
- `tool/run_android_live_groq_failure_recovery.cjs`
- `tool/run_android_live_groq_rate_limit.cjs`
- `tool/android_live_groq_force_stop_support.cjs`
- `tool/android_live_groq_force_stop_support.test.cjs`
- `tool/run_android_live_groq_force_stop_reopen.cjs`
- `tool/run_groq_primary_text_evaluation.cjs`
- `tool/run_groq_primary_text_evaluation.test.cjs`

## العوائق المتبقية والحكم

العوائق الخارجية للإنتاج: لا جهاز مادي، application ID نهائي، release signing،
Play Integrity، سياسات تنبيه فعلية، ومصدر متسخ غير مربوط بcommit بسبب حظر
المستخدم لأي commit/push. Groq Vision مؤجل ولا يمنع النص.

**حكم Groq Daily Use:** `READY_FOR_INTERNAL_DAILY_USE` لبيئة staging على Android
debug emulator. لا يساوي هذا اعتماد release/production؛ الجهاز المادي، package ID
النهائي، التوقيع، وPlay Integrity ما زالت بوابات إصدار خارجية.

تعليمات التراجع التفصيلية في `GROQ_ROLLBACK_AR.md`: إعادة 100% إلى
`cashpilot-ai-gateway-staging-00002-sww` أو تعطيل أعلام Groq مع إبقاء المحلي،
من دون حذف الخدمة أو السر أو السجلات ومن دون fallback نصي صامت.
