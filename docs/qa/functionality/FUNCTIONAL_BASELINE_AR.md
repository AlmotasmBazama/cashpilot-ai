# خط الأساس الوظيفي لتطبيق CashPilot AI

التاريخ: 2026-08-11، المنطقة الزمنية `Africa/Tripoli`.

## شجرة العمل

- الجذر: `<REPOSITORY_ROOT>`.
- الفرع: `master`.
- HEAD: `fd24526f3f21ba0e96ca73dcc4a69f5a11aed632`.
- شجرة العمل كانت متغيرة على نطاق واسع قبل هذه الجولة. حُفظت القوائم المنقحة في `evidence/git-status-before.txt` و`evidence/git-diff-stat-before.txt`، ولم تُستخدم أوامر reset/clean/restore/stash/commit/push.

## البيئة الفعلية

| البند | القيمة المثبتة |
|---|---|
| Flutter | `3.41.9 stable`، revision `00b0c91f06` |
| Dart | `3.11.5` |
| Java المباشر | `21.0.11 LTS` |
| Java المستخدم بواسطة Flutter/Android Studio | `21.0.10` |
| Node | `26.1.0` |
| npm | `11.13.0` عبر `npm.cmd` |
| Android SDK | `36.1.0`؛ الرخص مقبولة |
| الأجهزة المتصلة | Windows، Chrome 151، Edge 151؛ لا جهاز Android متصل |
| AVD المتاح | Pixel 6، Pixel 7 Pro، Resizable، Small Phone؛ لم يكن أي منها متصلًا عند الالتقاط |
| Windows toolchain | غير مكتمل؛ Visual Studio C++/CMake/Windows SDK غير متاحة |
| إصدار التطبيق | `1.0.0+1` |
| Android application ID | `com.example.cashpilot_ai` (ما زال معرّف تطوير) |
| Android minSdk الفعلي | `24`، لأن Gradle يستخدم `flutter.minSdkVersion` وFlutter 3.41.9 يعرّفه بـ24 |
| Android target/compile SDK | `36` من Flutter |
| Firebase project | `cashpilot-ai-a6b49` |
| FlutterFire platforms | Android فقط |
| `google-services.json` | موجود لـAndroid |
| Firebase Web options | غير موجودة؛ `DefaultFirebaseOptions.currentPlatform` يرمي `UnsupportedError` على Web |
| Drift Web assets | `web/sqlite3.wasm` و`web/drift_worker.js` غير موجودين في خط الأساس |

## إعداد الذكاء الاصطناعي في خط الأساس

- Debug بلا `--dart-define` يختار `AiProviderMode.localParserOnly`؛ هذا محلل أوامر محلي وليس مزود محادثة عامة.
- Profile/Release يختار `firebaseGemini` افتراضيًا، لكن لم يُنفذ طلب حي في هذه الجولة الأساسية.
- أعلام Groq والـgeneral route كلها `false` افتراضيًا، و`CASH_PILOT_AI_GATEWAY_BASE_URL` غير موجود في البيئة؛ لذلك لا توجد بوابة Groq قابلة للاختيار في البناء الأساسي.
- Firebase AI قابل للاختيار صراحة بكلمة `firebaseGemini`، لكنه ليس اختيار debug الافتراضي.
- App Check يستخدم debug provider في non-release، ولم يكن debug token مورّدًا في البيئة. Android release يستخدم Play Integrity. Web release يحتاج site key غير موجود.
- `CASH_PILOT_AI_APP_CONTROL_ENABLED` وconfirmed execution وnavigation/create/update/archive/multistep وlocal dataset verification كلها fail-closed (`false`) افتراضيًا. هذا صحيح ولا ينبغي أن يمنع المحادثة العامة.
- رؤية الإيصال لها flag مستقل default `true` في المصدر، لكنها كانت مرتبطة فعليًا باختيار `firebaseGemini` في UI/controller.
- لم تُشغّل جلسة تفاعلية بعد، لذلك لا توجد مطالبة بأن الحالة الحالية Guest أو Authenticated؛ حالة الحساب الفعلية تعتمد على Firebase Auth المخزنة على الجهاز.
- متغيرات البيئة الآتية كانت غائبة دون قراءة أي قيمة سرية: `GROQ_API_KEY`، `FIREBASE_APP_CHECK_DEBUG_TOKEN`، `FIREBASE_PROJECT_ID`، `GOOGLE_APPLICATION_CREDENTIALS`، emulator hosts، وgateway base URL.

## نتيجة خط الأساس الآلي

| الأمر | النتيجة |
|---|---|
| `flutter analyze --no-pub` | exit 0؛ `No issues found`؛ 29.7 ثانية |
| `flutter test --no-pub -r compact` | exit 1؛ `1074 passed / 1 failed`؛ نحو 59 ثانية |
| الاختبار المركز للفشل | `2 passed / 1 failed`، ونفس الفشل فقط |

الفشل الوحيد هو `secure-storage platform requirements are committed` في `account_deletion_secure_storage_architecture_test.dart`. الاختبار يبحث عن النص الحرفي `minSdk = 23`، بينما المصدر الصحيح يستخدم `minSdk = flutter.minSdkVersion` وقيمته الفعلية في Flutter المثبت هي 24. لا يوجد نقص فعلي في متطلب `flutter_secure_storage` (API 23)؛ العيب هو اختبار هش ومتقادم يفحص تنسيق المصدر بدل القيمة الفعلية.

## العوائق القابلة لإعادة الإنتاج قبل الإصلاح

1. بناء debug الافتراضي لا يملك مزود محادثة عامة: localParserOnly يُرجع فشلًا typed فتظهر رسالة مزود غير متاح للأسئلة غير المحلية.
2. Groq غير مفعّل ولا يملك base URL، لذلك لا يمكنه التعويض.
3. Web لا يملك FlutterFire options، ويؤدي Firebase initialization إلى مسار فشل bootstrap بدل تطبيق محلي قابل للاستخدام.
4. لا يوجد جهاز Android متصل، ولا توجد بيانات اعتماد staging/App Check/Groq؛ الطلب الحي وmanual acceptance غير مثبتين.
5. اختبار minSdk الحرفي يمنع suite كاملة خضراء رغم أن minSdk الفعلي 24.

هذا الملف يصف الحالة قبل تعديلات الجولة الوظيفية فقط؛ نتائج ما بعد الإصلاح تُسجّل في التقرير النهائي والأدلة المنفصلة.
