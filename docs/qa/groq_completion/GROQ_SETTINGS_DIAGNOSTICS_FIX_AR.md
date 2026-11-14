# إصلاح إعدادات وتشخيص Groq في Cash Pilot

التاريخ: 2026-08-14
الحالة النهائية: **ناجح محليًا وعلى Android الحقيقي (محاكي مخصص) وعلى Cloud Run المستقر**

## الخلاصة التنفيذية

لم يكن Groq أو نموذج `openai/gpt-oss-20b` غير متاح. كان الخلل مركبًا من جزأين:

1. بطاقة Settings القديمة كانت تستنتج الحالة من `providerMode` ومسار تشخيص قديم خاص بـFirebase، بينما Chat يختار مزوّد المحادثة من مسار routing مختلف. ولأن `providerMode=localParserOnly` مقصود للأوامر المالية الحتمية، عُرض `cashpilot-local-parser-v1` خطأً كأنه نموذج النص البعيد.
2. APK المثبت عند بدء التحقيق لم يحمل إعداد Groq الدائم المطلوب. APKات القبول السابقة كانت تستلم dart-defines من runner متخصص، ولم يوجد أمر staging عادي موحد يمنع الرجوع إلى `auto`/بناء غير مهيأ.

إذًا التصنيف الفعلي هو **C: خطأ في Settings مع APK غير مهيأ لـGroq**. الخدمة السحابية بقيت سليمة ولم تُعدّل في هذه المهمة.

## حالة البناء المثبت قبل الإصلاح

- package: `com.example.cashpilot_ai`
- version/build: `1.0.0+1`
- build mode: Debug
- SHA-256: `85c81df47e4a498e04eab8d6bbf41d006549ffaee518e1f791f91ddfda6f7a5f`
- الحجم: `133,358,663` بايت
- لم يكن رابط Cloud Run المستقر أو Groq flags مثبتًا كمصدر بناء canonical لذلك الـAPK.
- لذلك لا يُنسب إلى ذلك الـAPK إثبات Chat عبر Groq. إثباتات Groq السابقة كانت لبناء قبول متخصص، وهذا يفسر التناقض المرئي في Settings.

## السبب الجذري في Settings

- Chat يمر عبر `aiAgentModelGatewayProvider` و`RoutedAiAgentModelGateway`.
- Settings كانت تستخدم `defaultAiModelIdProvider`/`providerMode` وتشخيصًا provider-specific منفصلًا، لا نفس قرار المحادثة.
- اختبار Settings القديم كان Firebase-centric، ورسائله تفترض أن Firebase Gemini هو مزوّد النص.
- النتيجة القديمة كانت state داخل widget فقط، وليست cache دائمًا على القرص. لم يوجد تسرب نتيجة بين إصدارات التطبيق، لكن النتيجة كانت قابلة للبقاء stale داخل عمر الـwidget ولم تكن مربوطة بالبناء أو الحساب أو App Check.

## المعمارية الجديدة

أصبح `aiGeneralConversationRoutePlanProvider` مصدر قرار واحدًا للمحادثة ولحالة Settings. ويبني `aiRuntimeStatusControllerProvider` لقطة immutable من نوع `AiRuntimeStatusSnapshot` تفصل بوضوح بين:

- مزوّد النص البعيد وحالة تهيئته وتوفره.
- نموذج المحادثة العامة `openai/gpt-oss-20b`.
- مزوّد/نموذج الشرح المالي `openai/gpt-oss-120b`، من دون تمكين التنفيذ المالي.
- المحلل الحتمي المحلي `cashpilot-local-parser-v1`.
- Receipt Vision على Firebase AI.
- سياسة Firebase text fallback.
- Gateway وFirebase initialization وAuth وApp Check.
- مزوّد/نموذج ونتيجة وزمن وفشل typed للاختبار الحي.

الـhealth check آلي ومحدود ولا يرسل prompt أو يختار نموذجًا. أما زر الاختبار فيستخدم Groq gateway الإنتاجي مباشرةً مع Firebase Auth وApp Check وegress guard، ويتطلب streaming completion ومحتوى غير فارغ. لا يستطيع Firebase fallback إرضاء الاختبار أو إخفاء فشله.

## إبطال الحالة القديمة

الحالة تبقى في ذاكرة العملية فقط ولا تُحفظ على القرص. أضيف fingerprint آمن بصيغة SHA-256 يضم version/build، build mode، environment، provider preference، gateway origin/client version، النموذج، flags، fallback policy، Auth session generation وحالة Auth/App Check وخطة routing والمزوّدين المتخصصين.

لا يدخل UID أو token أو prompt أو response في البصمة. يوقف generation/fingerprint guard أي كتابة متأخرة بعد تبدل الإعداد أو الحساب أو App Check. وبعد restart تظهر حالة الاختبار الخاصة بالبناء الحالي بدل إعادة عرض فشل Firebase قديم.

أضيفت كذلك مهلة حقيقية مقدارها 10 ثوانٍ لكل من `getIdToken(true)` و`getToken(true)`، مع تحويل التعثر إلى حالة typed وإنهاء `testing` دائمًا حتى لو تعطل plugin أصلي.

## بطاقة Settings بعد الإصلاح

تعرض البطاقة صفوفًا منفصلة ومترجمة للعربية والإنجليزية:

- Remote text provider: Groq
- General conversation model: `openai/gpt-oss-20b`
- Financial explanation model: `openai/gpt-oss-120b`
- Local command parser: `cashpilot-local-parser-v1`
- Receipt Vision provider: Firebase AI
- Provider routing: Groq primary
- Firebase text fallback: Disabled
- Gateway: Available
- Authentication: Ready
- App Check: Verified
- Last live test، latency، timestamp، وtechnical code عند الفشل

الحالات المميزة تشمل: not tested، testing، available، configuration missing، authentication required، App Check unavailable، gateway unavailable، model unavailable، rate limited، offline، timed out، وunavailable.

## إعداد Groq الدائم للبناء

المصدر غير السري الوحيد هو `config/groq_staging.json`. يثبت staging/Groq والبوابة المستقرة، ويُبقي:

- Firebase text fallback = `false`
- Receipt Vision = Firebase
- Groq tool selection = `false`
- current web = `false`
- diagnostics = `false`

لا يحتوي الملف على GROQ API key أو Firebase/App Check token أو signing secret. كما أن الأمر canonical لا يقرأ `.dart-define.appcheck.json` المتجاهل؛ ذلك الملف المحلي بقي بلا تعديل، وقد يحتوي token debug وoverride قديمًا للمزوّد، لذلك لا يجوز دمجه wholesale مع إعداد staging.

الأمر canonical للبناء والتشغيل:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tool\run_android_groq_staging.ps1
```

لجهاز محدد:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tool\run_android_groq_staging.ps1 -DeviceId emulator-5554
```

للبناء فقط أضف `-BuildOnly`، وللتحقق من السياسة فقط أضف `-ValidateOnly`.

أضيفت ملفات VS Code:

- `CashPilot Android — Groq Staging`
- `CashPilot Android — Local Debug`
- `CashPilot Web — Staging`

ملف Web لم يُقبل حيًا؛ localhost قد يحتاج origin إضافيًا في CORS، ولم تُغير إعدادات Cloud في هذه المهمة.

## نتائج الاختبارات والبناء

- `flutter analyze --no-pub`: **PASS — No issues found**.
- `flutter test --no-pub -r compact`: **PASS — 1249/1249**.
- اختبارات Node الخاصة بالبناء والقبول: **PASS — 57/57**.
- اختبار Settings + design system الموجّه: **PASS — 14/14**.
- `flutter build apk --debug --no-pub` عبر `-BuildOnly`: **PASS**.
  - artifact قبل التشغيل device-targeted: `204,270,351` بايت.
  - SHA-256: `319478ba3ee9ebedcf064b3a34d44294f422dc0a0e135821f3a4c2df9fb1066b`.
- التشغيل canonical على `emulator-5554`: **PASS**، من دون uninstall أو reset.
  - package `com.example.cashpilot_ai`, version `1.0.0+1`, Debug، العملية تعمل.
  - APK المثبت يطابق artifact الذي ولّده `flutter run`: `133,358,663` بايت.
  - SHA-256 المطابق: `aa17586a23406120581ead098fe28b4afc70589c1744a33a8953bf5cd9a060e7`.

الاختلاف في حجم/بصمة الملف سببه أن `flutter run` أعاد توليد artifact device-targeted في المسار نفسه بعد build-only؛ البصمة المثبتة طابقت الملف المحلي بعد أمر التشغيل.

لم تُشغّل اختبارات Gateway لأن أي ملف Gateway لم يتغير.

## قبول Android وCloud Run

نُفذ القبول على `emulator-5556` المخصص باستخدام Debug APK وApp Check DebugProvider عبر production widgets/router. لا يمثل ذلك توقيع Release أو Play Integrity.

النتيجة النهائية:

- Chat العربي غير المحلي: اكتمل، Groq محدد، route=`generalConversation`، Firebase fallback=`false`، زمن UI `23,788 ms`.
- Settings قبل restart: تحققت 11 دلالة مطلوبة، ومنها Groq/20b/120b/local parser/Receipt/Fallback/Gateway/Auth/App Check.
- Settings live test: `idle → testing → available`، streaming غير فارغ واكتمال، زمن القبول الكلي `115,854 ms` (يشمل نافذة هدوء ومسح UI).
- force-stop/reopen: اختفى PID القديم وظهر PID جديد مختلف عبر MAIN/LAUNCHER في `11,506 ms`.
- Settings بعد restart: أُعيد فتحها صراحةً وتحققت الحقول نفسها في `77,996 ms`.
- Chat الإنجليزي الثاني بعد استعادة الجلسة: اكتمل عبر Groq وfallback=`false` في `30,349 ms`.
- النتيجة: `completed=true`, `processRestart=true`, `secondQuestion=true`, `cleanup=true`, `settingsBefore=true`, `settingsTest=true`, `settingsAfter=true`.

طابقت سجلات revision `00005-civ` الجولة الأخيرة بثلاثة traces فقط في نافذتها الدقيقة:

1. Chat الأول: HTTP 200، `openai/gpt-oss-20b`، completed، 342 chunks، retry 0، TTFC 364 ms.
2. Settings live test: HTTP 200، `openai/gpt-oss-20b`، completed، 27 chunks، retry 0، TTFC 298 ms.
3. Chat الثاني: HTTP 200، `openai/gpt-oss-20b`، completed، 206 chunks، retry 0، TTFC 304 ms.

كلها سجلت `started → textDelta → completed` وupstream success، بلا typed error. لم تُستخرج IDs أو prompts أو responses أو tokens.

حُذف المستخدم الاصطناعي وملف Firestore وتسجيل App Check المؤقت والحزمة من المحاكي المخصص، ثم أُوقف `emulator-5556`. بقي `emulator-5554` متصلًا والنسخة canonical مثبتة وعاملة. لم تُحذف registration الحالية الخاصة بالمستخدم.

## الملفات التي لمستها هذه المهمة

### Runtime وrouting

- `lib/features/ai_assistant/application/providers/ai_agent_providers.dart`
- `lib/features/ai_assistant/application/providers/ai_runtime_status_providers.dart`
- `lib/features/ai_assistant/application/services/ai_runtime_status_builder.dart`
- `lib/features/ai_assistant/application/services/ai_runtime_status_probe.dart`
- `lib/features/ai_assistant/data/gateway/firebase_gateway_token_provider.dart`
- `lib/features/ai_assistant/data/gateway/routed_ai_agent_model_gateway.dart`
- `lib/features/ai_assistant/domain/entities/ai_runtime_status.dart`
- `lib/features/ai_assistant/domain/services/ai_provider_route_resolver.dart`

### Settings وlocalization

- `lib/features/settings/presentation/pages/settings_screen.dart`
- `lib/features/settings/presentation/widgets/ai_diagnostics_settings_section.dart`
- `lib/shared/design_system/widgets/cp_list_tile.dart`
- `lib/l10n/app_ar.arb`
- `lib/l10n/app_en.arb`
- `lib/l10n/app_localizations.dart`
- `lib/l10n/app_localizations_ar.dart`
- `lib/l10n/app_localizations_en.dart`

### إعداد البناء والأدوات

- `.vscode/launch.json`
- `config/groq_staging.json`
- `tool/android_live_groq_runner_support.cjs`
- `tool/android_live_groq_runner_support.test.cjs`
- `tool/run_android_groq_staging.ps1`
- `tool/run_android_groq_staging.test.cjs`

### dependency وملفات plugin المولدة

- `pubspec.yaml`
- `pubspec.lock`
- `macos/Flutter/GeneratedPluginRegistrant.swift`
- `.flutter-plugins-dependencies` (مولد ومتجاهل)
- `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java` (مولد ومتجاهل)
- `ios/Runner/GeneratedPluginRegistrant.m` (مولد ومتجاهل)

### الاختبارات المركزة

- `test/features/ai_assistant/ai_availability_test.dart`
- `test/features/ai_assistant/ai_provider_route_resolver_test.dart`
- `test/features/ai_assistant/ai_runtime_status_probe_test.dart`
- `test/features/ai_assistant/ai_runtime_status_provider_test.dart`
- `test/features/ai_assistant/firebase_gateway_token_provider_test.dart`
- `test/features/ai_assistant/routed_ai_agent_model_gateway_test.dart`
- `test/features/settings/ai_diagnostics_settings_section_test.dart`

### امتداد قبول Android

- `lib/features/ai_assistant/presentation/pages/ai_assistant_screen.dart`
- `lib/features/app_shell/presentation/pages/app_shell_page.dart`
- `lib/shared/accessibility/acceptance_semantics.dart`
- `test/features/app_shell_acceptance_semantics_test.dart`
- `tool/android_live_groq_force_stop_support.cjs`
- `tool/android_live_groq_force_stop_support.test.cjs`

### التقرير

- `docs/qa/groq_completion/GROQ_SETTINGS_DIAGNOSTICS_FIX_AR.md`

لم يتغير `tool/run_android_live_groq_force_stop_reopen.cjs` في هذه المهمة؛ استُخدم فقط كمدخل runner النهائي. ولم تُلمس ملفات financial logic أو Gateway/Cloud configuration أو Firebase text fallback policy.
