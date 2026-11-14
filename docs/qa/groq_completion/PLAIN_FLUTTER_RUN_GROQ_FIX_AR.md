# إصلاح تشغيل Groq تلقائيًا مع `flutter run` — Cash Pilot AI

التاريخ: 2026-08-15  
الحالة النهائية: **ناجح**. تشغيل Debug/Profile العادي بلا `dart-define` يختار Groq Staging، بينما Release بلا إعداد Production صالح يفشل بإغلاق آمن وحالة typed واضحة.

## الخلاصة التنفيذية

أصبح الأمر التالي كافيًا للتطوير اليومي:

```powershell
flutter run -d emulator-5554
```

لا يحتاج الأمر إلى `--dart-define` أو `--dart-define-from-file` أو PowerShell wrapper. الإعداد المحلول هو:

- مزود النص البعيد: Groq primary.
- نموذج المحادثة العامة: `openai/gpt-oss-20b`.
- نموذج الشرح المالي: `openai/gpt-oss-120b`.
- محلل الأوامر المحلي: `cashpilot-local-parser-v1`.
- Receipt Vision: Firebase AI.
- Firebase text fallback: معطل.
- التنفيذ المالي المؤكد والتحويلات والخطط متعددة الخطوات: معطلة.

## السبب الجذري السابق

كانت قيم compile-time المتفرقة تعطي، عند غياب defines، أعلام Groq معطلة أو Gateway URL فارغًا. لذلك كانت تهيئة Staging تصل فقط عبر `config/groq_staging.json` و`tool/run_android_groq_staging.ps1` أو قائمة defines يدوية في runners القبول.

بقي `providerMode=localParserOnly` مطلوبًا أصلًا لاستخراج الأوامر المالية الحتمي، لكنه لا يمثل نموذج النص البعيد. غياب طبقة default موحدة جعل البناء العادي قادرًا على إظهار local parser أو Automatic في Settings بينما لا يملك مسار Groq مهيأ.

## مصدر الحقيقة وترتيب الأولوية

أضيفت `AiEnvironmentDefaults` فوق أنواع الإعداد الحالية، لا كنظام ثانٍ. يقرأ كل من `AiRuntimeConfig.current` و`AiGatewayFeatureFlags.current` و`AiGatewayRuntimeConfig.current` وحالة runtime وApp Control القيمة المحلولة نفسها؛ ثم يستخدم Chat وSettings والـlive probe خطة التوجيه المشتركة نفسها.

ترتيب الأولوية:

1. قيمة `dart-define` الصريحة.
2. Groq Staging الافتراضي في Debug/Profile.
3. Release fail-closed.

يستخدم القارئ `bool.hasEnvironment` لإثبات وجود المفتاح قبل قراءة قيمته، ولذلك يميز بين المفتاح الغائب و`false` الصريحة. أثبت الاختبار أن `false` الصريحة تلغي default `true`.

## Defaults الخاصة بـDebug/Profile

| المفتاح أو السلوك | القيمة |
|---|---|
| `CASH_PILOT_ENVIRONMENT` | `staging` |
| `CASH_PILOT_AI_PROVIDER` | `groq`، وهو Groq primary في النوع الموجود |
| `CASH_PILOT_AI_DIAGNOSTICS` | `false` |
| `CASH_PILOT_AI_GROQ_GATEWAY_ENABLED` | `true` |
| `CASH_PILOT_AI_GROQ_GENERAL_CHAT_ENABLED` | `true` |
| `CASH_PILOT_AI_GROQ_FINANCIAL_EXPLANATION_ENABLED` | `true` |
| `CASH_PILOT_AI_GROQ_ARABIC_SPECIALIST_ENABLED` | `true` |
| `CASH_PILOT_AI_GROQ_TOOL_SELECTION_ENABLED` | `false` |
| `CASH_PILOT_AI_CURRENT_WEB_ENABLED` | `false` |
| `CASH_PILOT_AI_FIREBASE_TEXT_FALLBACK_ENABLED` | `false` |
| `CASH_PILOT_AI_FIREBASE_RECEIPT_VISION_ENABLED` | `true` |
| `CASH_PILOT_AI_GATEWAY_BASE_URL` | `https://cashpilot-ai-gateway-staging-yfgt2ypuvq-ew.a.run.app` |
| `CASH_PILOT_CLIENT_VERSION` | `1.0.0`، ومتزامن مع `pubspec.yaml` |

بقيت التحيات وردود الإمكانات محلية، واستخراج الأوامر المالية محليًا وحتميًا. بقي Firebase Authentication وFirebase App Check فعالين.

## Release fail-closed

في Release بلا defines يكون environment=`unspecified` ولا يُقبل أي Staging URL ضمني. يبقى قصد Groq ظاهرًا للتشخيص، لكن URL غير مهيأ وخطة المسار تنتج:

`gatewayUrlMissing → groqNotConfigured → configurationMissing`

لا يُقبل النص البعيد في Release إلا مع `CASH_PILOT_ENVIRONMENT=production` صريح وGateway URL صريح ذي authority وبروتوكول HTTPS وغير تابع لمضيف Staging. رُفضت الحالات الآتية باختبارات مباشرة:

- غياب Production أو غياب URL.
- environment=`staging`.
- Production مع رابط Staging، حتى لو سُمي Production.
- Production مع HTTP.
- `provider=firebase` أو `fallback=true` أو Current Web بلا Production+HTTPS صالحين.

بعد تحقق Production+HTTPS فقط يمكن للـoverrides الصريحة تفعيل مسار Firebase النصي. Android Release يبقى على Play Integrity وليس `AndroidProvider.debug`، كما تُعطل دلالات القبول والـone-shot prompt hook قسرًا عبر `!kReleaseMode`. لم يُبن APK Release ولم يُجر قبول Play Integrity حي في هذه المهمة؛ هذه النقاط مثبتة بالمصدر واختبارات الوحدة.

أضيف تقوية Release الأخيرة بعد القبول الحي، وهي فرع خاص بـ`kReleaseMode` فقط. لم تغير مسار Debug/Profile الذي اجتاز القبول، ثم أُعيدت مصفوفة Debug، والتحليل الكامل، والاختبارات الكاملة، وبناء Debug APK.

## الـoverrides الصريحة

أثبتت الاختبارات أن:

- `CASH_PILOT_AI_GROQ_GATEWAY_ENABLED=false` يلغي default `true` في non-release.
- Gateway HTTPS مخصص يحل محل رابط Staging في non-release.
- provider=`firebase` يغيّر المزود الأولي في non-release.
- diagnostics=`true` يلغي default `false`.
- في Release لا تُقبل overrides النصية البعيدة إلا مع Production+HTTPS صالحين، ولا يمكن استخدامها للالتفاف على حالة configuration-missing.

## اتساق ملف Staging والسرية

يقارن اختبار drift كل القيم غير السرية في `config/groq_staging.json` مع `AiEnvironmentDefaults.resolve()`، ويطابق اختبار مستقل نسخة العميل مع `pubspec.yaml`. بقي ملف الإعداد والـwrapper بلا تعديل في هذه المهمة، وظلا صالحين لـCI والبناء المتكرر واختيار الجهاز.

نجح الأمر:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tool\run_android_groq_staging.ps1 -ValidateOnly
```

بالنتيجة الآمنة: `status=valid environment=staging provider=groq fallback=false secrets=false`.

لا يحتوي JSON أو Dart defaults أو Flutter source/assets على `GROQ_API_KEY` أو App Check token أو signing secret، ولا يُضمّن `config/groq_staging.json` كـFlutter asset.

## القبول الحي بأمر Flutter العادي

نافذة القبول النهائية: `2026-08-15T00:48:52.8382293Z` إلى `2026-08-15T01:02:28.6660496Z` على `emulator-5554`.

استُخدم runner للتنسيق الآمن فقط، وكان ممنوعًا من تنفيذ build/install/uninstall بنفسه:

```powershell
node tool/run_android_plain_flutter_acceptance.cjs --execute-live --promotion-confirmed --dedicated-device --plain-runs-confirmed --no-build-install-confirmed --device emulator-5554 --gateway-url https://cashpilot-ai-gateway-staging-yfgt2ypuvq-ew.a.run.app
```

عند كل `READY_RUN` شُغّل argv التالي حرفيًا مرتين:

```powershell
flutter run -d emulator-5554
```

لم تمرر أي defines أو from-file أو wrapper. تحويل stdout إلى `$null` كان redirection في shell لمنع ظهور App Check debug token المحتمل، وليس argument إلى Flutter. أُوقف كل run بـ`q` وتأكد توقفه ضمن مهلة محدودة.

نتيجة الجولة:

- في run 1 نجح تسجيل الدخول، وأُرسل السؤال العربي غير المحلي: «اشرح لي مفهوم التضخم بطريقة بسيطة».
- ظهرت `sending` ثم `answer_complete`، وزاد عدد الرسائل `+2` بالضبط (رسالة مستخدم ورد مساعد)، ثم بقي ثابتًا في خمس snapshots؛ لم يظهر رد مكرر.
- أثبتت Settings في run 1 أحد عشر معرفًا مملوكًا للتطبيق: Groq، 20b، 120b، local parser، Firebase Receipt Vision، fallback disabled، Gateway available، Auth ready، App Check verified، وبطاقة/زر الاختبار.
- بدأ live test في Settings من `idle` ووصل إلى `available`. كان انتقال `testing` أسرع من أول UI dump في run 1، لكن ترتيب state machine `[checking, ready]` مثبت باختبار دقيق وطلب Cloud المقابل مكتمل. في run 2 شوهد `testing → available` صراحة.
- بعد إيقاف run 1 فُتح التطبيق من Android Launcher؛ اختفى PID القديم وظهر PID جديد مختلف، واستعيدت الجلسة والإعدادات.
- بعد Launcher أُرسل السؤال الإنجليزي `Give me three simple saving habits`؛ اكتمل عبر Groq مع `+2` فقط وبلا تكرار.
- شُغّل plain Flutter run للمرة الثانية، وأثبتت Settings القيم نفسها ونجح live test الثاني.
- النتيجة النهائية: `firstChat=true`, `run1Settings=true`, `launcherReopen=true`, `secondChat=true`, `run2Settings=true`, `externalStops=true`, `cleanup=true`, `noBuild=true`, `noInstall=true`, `noUninstall=true` للـharness نفسه. البناء والتثبيت الفعليان كانا من `flutter run` لا من runner.

## دليل Cloud Run المقروء فقط

أعاد استعلام bounded/read-only أربعة traces فقط في نافذة القبول على الخدمة المستقرة والمراجعة `cashpilot-ai-gateway-staging-00005-civ` لمسار `/v1/ai/general-chat`:

| # | الدليل | UTC | النموذج | HTTP | المدة | TTFC | الإكمال | retry | chunks |
|---:|---|---|---|---:|---:|---:|---:|---:|---:|
| 1 | Chat العربي، run 1 | `00:51:18.618898` | `openai/gpt-oss-20b` | 200 | 655 ms | 352 ms | 303 ms | 0 | 320 |
| 2 | Settings probe، run 1 | `00:52:56.343435` | `openai/gpt-oss-20b` | 200 | 178 ms | 178 ms | 0 ms | 0 | 26 |
| 3 | Chat الإنجليزي بعد Launcher | `00:54:59.612598` | `openai/gpt-oss-20b` | 200 | 470 ms | 317 ms | 153 ms | 0 | 112 |
| 4 | Settings probe بعد run 2 | `00:58:59.571181` | `openai/gpt-oss-20b` | 200 | 313 ms | 313 ms | 0 ms | 0 | 22 |

كلها سجلت `started → textDelta → completed`، و`final=completed`، وupstream success من المحاولة الأولى، بلا typed error أو retry. تطابق العدد مع طلبي Chat واختباري Settings ولم توجد محاولة Firebase text fallback. نموذج 120b مثبت في الإعداد وSettings لمسار الشرح المالي، لكنه لم يُستدع حيًا في هذه الجولة لأن الطلبات الأربعة كانت general-chat كما يقتضي القبول.

لم يُستخرج إلى الدليل أي UID أو request ID أو prompt أو response أو token.

## التنظيف وعدم تغيير السحابة

انتهى القبول بـ`FlutterRunProcesses=0` و`AppProcessAlive=false` مع بقاء الحزمة مثبتة. حُذف حساب/profile القبول الاصطناعيان وتأكد signed-out، ونُظفت UI dumps والسجلات المؤقتة.

لم يجد runner تسجيل App Check مطابقًا قبل الجولة؛ أنشأ تسجيلًا مؤقتًا للـdebug secret الموجود على الجهاز ثم حذف التسجيل الذي أنشأه فقط. لم يحذف أو يبدّل أي تسجيل موجود مسبقًا، ولم يضع token في المصدر أو التقرير. التشغيل العادي نفسه لا ينشئ ولا يحذف التسجيلات.

لم يتغير Cloud Run أو traffic أو Secret Manager، وبقيت المراجعة `00005-civ`. لم يُنفذ `reset` أو `clean` أو `restore` أو `stash` أو branch switch أو commit أو push.

## التحقق الآلي والبناء النهائي

| التحقق | النتيجة النهائية |
|---|---|
| `flutter analyze --no-pub` | PASS، `No issues found`، 20.4 s |
| `flutter test --no-pub -r compact` | PASS، `1271/1271` |
| جميع اختبارات أدوات Node في `tool/*.test.cjs` | PASS، `106/106` |
| مصفوفة الإعداد المركزة | PASS، `19/19`؛ تشمل الحالات 1–12، Release HTTPS/Firebase gates، diagnostics، source parity، JSON drift، وversion parity |
| `run_android_groq_staging.ps1 -ValidateOnly` | PASS |
| `flutter build apk --debug --no-pub` | PASS، Gradle `assembleDebug` في 40.0 s |
| artifact | `build/app/outputs/flutter-apk/app-debug.apk` |
| الحجم | `242,656,567` bytes |
| SHA-256 | `975BE1FB311E47E3E4CF71B04778D9FB84B5C18367954E4A9CC2BB63EC59CB11` |
| `git diff --check` على ملفات المهمة | PASS؛ تحذيرات CRLF معلوماتية فقط |

لم تتغير Gateway source، ولذلك لم تُعد Gateway tests وفق شرط الطلب.

## ملفات هذه المهمة فقط

### الإعداد وruntime

1. `lib/core/config/cash_pilot_app_version.dart`
2. `lib/features/ai_assistant/data/config/ai_environment_defaults.dart`
3. `lib/features/ai_assistant/data/config/ai_runtime_config.dart`
4. `lib/features/ai_assistant/data/config/ai_gateway_feature_flags.dart`
5. `lib/features/ai_assistant/data/config/ai_app_control_feature_flags.dart`
6. `lib/features/ai_assistant/application/providers/ai_runtime_status_providers.dart`
7. `lib/app/bootstrap.dart`
8. `test/features/ai_assistant/ai_environment_defaults_test.dart`

### قبول UI الآمن

9. `lib/shared/accessibility/acceptance_semantics.dart`
10. `lib/features/ai_assistant/presentation/pages/ai_assistant_screen.dart`
11. `lib/features/auth/presentation/pages/login_screen.dart`
12. `test/features/app_shell_acceptance_semantics_test.dart`
13. `test/features/ai_assistant/ai_assistant_send_test.dart`
14. `test/features/ai_assistant/ai_agent_ui_test.dart`
15. `test/features/ai_assistant/ai_navigation_regression_test.dart`
16. `test/features/auth/login_acceptance_semantics_test.dart`

### أدوات القبول واختباراتها

17. `tool/android_live_groq_force_stop_support.cjs`
18. `tool/android_live_groq_force_stop_support.test.cjs`
19. `tool/android_live_groq_runner_support.cjs`
20. `tool/android_live_groq_runner_support.test.cjs`
21. `tool/run_android_groq_staging.test.cjs`
22. `tool/android_plain_flutter_run_acceptance_support.cjs`
23. `tool/android_plain_flutter_run_acceptance_support.test.cjs`
24. `tool/run_android_plain_flutter_acceptance.cjs`

### التقرير

25. `docs/qa/groq_completion/PLAIN_FLUTTER_RUN_GROQ_FIX_AR.md`

الملفات المحتفظ بها والمتحقق منها، لكنها ليست ضمن تعديلات هذه المهمة: `config/groq_staging.json` و`tool/run_android_groq_staging.ps1` و`.vscode/launch.json`. أعيد استخدام معمارية route/status/Settings المنجزة في المهمة السابقة ولم تُنسب إلى قائمة التغييرات الحالية.

## ملاحظة عن جولات التشخيص

كشفت المحاولات التمهيدية الآمنة ثلاث مشكلات في harness/UI proof فقط: زر دخول مخفي أو خارج viewport، marker صفري الارتفاع لا يراه UIAutomator، وفشل transient واحد في UI dump بعد Launcher. أضيف bounded scroll، وstate markers typed ذات مساحة فعلية، وretry محدود للأخطاء العابرة فقط. نُظفت كل محاولة، والنتائج أعلاه تخص الجولة النهائية الناجحة.
