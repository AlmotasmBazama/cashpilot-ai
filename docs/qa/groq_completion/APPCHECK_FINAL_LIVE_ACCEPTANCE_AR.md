# القبول الحي النهائي لـ App Check وGroq على Android

التاريخ: 2026-08-16 (Africa/Tripoli)
الحالة: **PASS — Android Debug**، مع قيود Release المبينة في نهاية التقرير.

## الخلاصة التنفيذية

اكتمل تسجيل سر App Check Debug الحالي للمحاكي `emulator-5554` تلقائيًا، تحت تطبيق Firebase Android الصحيح، بالاسم الآمن `emulator-5554-development`. أعاد التبادل الرسمي النهائي HTTP 200 من دون طباعة السر أو رمز App Check الصادر أو حفظهما.

بعد بناء وتثبيت نسخة Debug الحالية، نجح مسار التطبيق الحقيقي عند تشغيله بالأمر العادي فقط:

```powershell
flutter run -d emulator-5554
```

لم تُمرر `dart-define`، ولم يُستخدم ملف defines أو wrapper للبناء. ثبت حيًا أن المحادثة العامة تستخدم Groq والنموذج `openai/gpt-oss-20b`، وأن Firebase text fallback معطل. كما نجحت المحادثة المحلية القصيرة، والطلب العربي البعيد فور البدء، والطلب الإنجليزي بعد إعادة فتح التطبيق، وتشخيص Settings، والفشل دون شبكة ثم Retry، وإعادة فتح Launcher بعد force-stop.

## خط أساس المستودع وحماية العمل

سُجل خط الأساس قبل العمل بصورة مختصرة وآمنة:

| البند | القيمة |
|---|---|
| الفرع | `master` |
| HEAD | `fd24526f3f21ba0e96ca73dcc4a69f5a11aed632` |
| مدخلات `git status --short` | 401 |
| أسطر `git diff --stat` | 212 |

حُفظت تغييرات المستخدم غير الملتزمة. لم يُنفذ reset أو clean أو restore أو stash أو تبديل فرع أو commit أو push.

## مطابقة Firebase والتطبيق

| البند | النتيجة |
|---|---|
| Firebase project ID | `cashpilot-ai-a6b49` |
| Firebase project number | `102802326815` |
| Firebase Android App ID | `1:102802326815:android:6c62d29c46586279841c2a` |
| Android package | `com.example.cashpilot_ai` |
| الحزمة المثبتة | مطابقة، نسخة واحدة فقط |
| Web API key | موجود؛ لم تُطبع قيمته |
| مزود App Check في Debug/Profile | `AndroidProvider.debug` |
| مزود App Check في Release | `AndroidProvider.playIntegrity` |

لم يوجد خلط بين اسم الحزمة وFirebase Android App ID.

## تسجيل App Check والتحقق الرسمي

استُخدم `tool/register_android_app_check_debug.cjs` لاسترجاع السر الذي تديره Firebase SDK من مساحة التطبيق، في الذاكرة فقط، ثم استخدام اعتماد Firebase المسجل أصلًا على الجهاز لاستدعاء API الرسمي. لم يُكتب السر في ملف أو متغير بيئة أو تقرير، ولم يظهر في stdout.

النتيجة الآمنة النهائية:

```text
secretRetrieved=true
secretPrinted=false
registration=existing
preserved=true
officialExchangeStatus=200
tokenPrinted=false
```

نجح التسجيل تلقائيًا؛ لم تكن هناك حاجة إلى Firebase Console. وأثبت تكرار الأداة بعد التثبيت النهائي أن التسجيل الحالي موجود ومحفوظ، وأن السر الحالي للمحاكي مقبول رسميًا.

تسمح واجهة Firebase App Check بحد أقصى 20 debug tokens لكل تطبيق وفق [مرجع موارد DebugToken الرسمي](https://firebase.google.com/docs/reference/appcheck/rest/v1/projects.apps.debugTokens) و[مرجع الإنشاء الرسمي](https://firebase.google.com/docs/reference/appcheck/rest/v1/projects.apps.debugTokens/create). عند امتلاء القائمة، حُذف تسجيل قديم واحد فقط من أقدم سجلات `cp-runtime-debug-*`، مؤرخ قبل هذه الجولة، لإتاحة خانة للتسجيل الحالي. لم يُحذف `emulator-5554-development` ولا أي تسجيل حالي مستعمل. الحذف القديم غير قابل للاستعادة، ويمكن إنشاء تسجيل جديد لاحقًا إن كان ذلك الجهاز القديم ما زال مطلوبًا.

يبقى التسجيل `emulator-5554-development` محفوظًا. قد يلزم تسجيل جديد فقط إذا مُسحت بيانات التطبيق، أو تغير الجهاز/المحاكي، أو تغير السر، أو اسم الحزمة، أو Firebase Android App.

## البناء المثبت

| البند | النتيجة |
|---|---|
| وضع البناء | Debug |
| أمر البناء | `flutter build apk --debug --no-pub` |
| النتيجة | PASS |
| APK | `build/app/outputs/flutter-apk/app-debug.apk` |
| الحجم | 204,312,857 bytes |
| SHA-256 | `210E363440DED081F3E05F9954E0E5585EBB64DFF670D1F69C4C3C1772E49558` |
| مطابقة APK المثبت | true |
| عدد حزم Cash Pilot المثبتة | 1 |

بعد القبول بقيت الحزمة مثبتة، وأُوقف التطبيق من دون مسح بياناته.

## نتائج القبول الحي

أدار harness التنسيق وجمع metadata الآمنة فقط؛ لم ينفذ build أو install أو uninstall، ولم ينشئ أو يحذف تسجيل App Check. تشغيل Flutter الفعلي كان بالأمر الحرفي أعلاه.

### 1. المحادثة المحلية القصيرة

| الدليل | النتيجة |
|---|---|
| الفئة الآمنة | `englishSmallTalk` |
| route | `directConversation` |
| اكتمال الرد | true |
| تغير الرسائل | +2 بالضبط: مستخدم + مساعد |
| رد مكرر | false |
| دخول مسار App Check | false |
| Cloud Run traces | 0 |
| مدة إثبات UI | 24,037 ms |

وبذلك ثبت حيًا أن `how are u` يعمل محليًا ولا يطلب App Check أو Cloud Run أو Groq. أما `how r u` والصيغ العربية المطلوبة وحواجز الأسئلة الموضوعية ذات البادئة المشابهة فثبتت في مصفوفة routing المركزة 29/29؛ لم تُرسل كل صيغة منها حيًا على الجهاز. الردود المحلية لا تدّعي أنها صادرة من Groq.

### 2. الطلب العربي البعيد فور البدء

| الدليل | النتيجة |
|---|---|
| الفئة الآمنة | `arabicInflation` |
| route | `generalConversation` |
| حالة الإرسال ثم الاكتمال | شوهدتا |
| تغير الرسائل | +2 بالضبط |
| رد مكرر | false |
| Gateway requests | 1 بالضبط |
| provider | Groq |
| model | `openai/gpt-oss-20b` |
| HTTP | 200 |
| Firebase text fallback | false |
| مدة القبول من الجهاز | 46,459 ms |

لم يظهر خطأ Device Verification، وانتهى loading، وكان الرد غير فارغ. أثبت trace المعزول اكتمال Groq بنجاح. لم يحتفظ harness بقيم منفصلة دقيقة لـtap-to-loading وTTFC على الجهاز؛ احتفظ بحالة sending وبمدة العملية الكاملة، بينما سجل Gateway metadata آمنة فقط. أظهرت مراجعة traces الآمنة ذات الصلة `retryCount=0` للإكمالات الناجحة.

### 3. الطلب الإنجليزي بعد إعادة الفتح

| الدليل | النتيجة |
|---|---|
| الفئة الآمنة | `englishCompoundInterest` |
| الجلسة مستعادة | true |
| اكتمال الرد | true |
| تغير الرسائل | +2 بالضبط |
| رد مكرر | false |
| Gateway requests | 1 بالضبط |
| provider/model | Groq / `openai/gpt-oss-20b` |
| HTTP | 200 |
| المدة | 37,015 ms |

### 4. Settings → AI diagnostics

ثبتت 11 خانة موثوقة عبر resource IDs:

| الخانة | القيمة المثبتة |
|---|---|
| Remote text provider | Groq |
| General conversation model | `openai/gpt-oss-20b` |
| Financial explanation model | `openai/gpt-oss-120b` |
| Local command parser | `cashpilot-local-parser-v1` |
| Receipt Vision | Firebase AI |
| Firebase text fallback | Disabled |
| Gateway | Available |
| Authentication | Ready |
| App Check | Verified |

بدأ الاختبار من `idle`، وشُوهد `testing` ثم `available` بالترتيب. نفذ طلبًا غير محلي واحدًا عبر Groq/20b وأعاد HTTP 200، ولم يستخدم Firebase text AI. المدة الإجمالية لاختبار Settings مع polling الآمن كانت 179,509 ms. ظهور 120b هنا يثبت إعداد مسار الشرح المالي؛ لم يُستدعَ 120b حيًا في هذه الجولة.

### 5. انقطاع الشبكة وRetry

أُثبت انقطاع شبكة المحاكي قبل الإرسال. نتجت حالة typed `offline` مع زر Retry، وانتهى loading، وبقيت رسالة المستخدم، ولم يصل أي طلب إلى Gateway.

| المرحلة | النتيجة |
|---|---|
| Offline | `messageDelta=2`، `gatewayCalls=0`، 19,687 ms |
| Retry بعد استعادة الشبكة | نفس رسالة المستخدم، مساعد واحد جديد، إجمالي +2، بلا تكرار |
| Retry Gateway | طلب واحد، Groq/20b، HTTP 200، 24,457 ms |

لم يحدث loop تلقائي. أعاد Retry فحص readiness من خلال المنسق المشترك.

### 6. Force-stop وإعادة الفتح من Launcher

ثبت توقف PID القديم، ثم تشغيل MAIN/LAUNCHER، ثم ظهور PID جديد مختلف خلال 7,590 ms. استُعيدت الجلسة وإعدادات Groq، ونجح الطلب الإنجليزي البعيد كما هو موضح أعلاه من دون wrapper أو defines أو Firebase fallback.

### 7. الإلغاء والنتائج المتأخرة

أثبت اختبار تكاملي حي عام لمسار النقل:

```text
firstContentReceived=true
subscriptionCancelled=true
rawChunksBeforeCancel=1
responseBytesBeforeCancel=8
completedEvents=0
failureEvents=0
lateEvents=0
cancelCompletionMs=14
```

إذن كانت الأحداث المتأخرة بعد الإلغاء صفرًا، ولم يصل completed أو failure بعد الإلغاء. انتهى جسم اختبار الإلغاء الحي بنجاح؛ إلا أن wrapper الإضافي القديم خرج بعد ذلك بكود 1 بسبب محاولة تسجيل App Check مكررة في postflight، لا بسبب الإلغاء. أُصلح wrapper لاحقًا ليجري exchange أولًا ويحافظ على التسجيل الموجود، وثبت ذلك في الاختبارات، ولم يُعد تشغيله بعد التثبيت النهائي كي لا يولد سرًا جديدًا أو يعرّض التسجيل الحالي للخطر.

نطاق الإثبات الحي هنا هو إلغاء اشتراك النقل العام. أما Navigate away وNew conversation وStop generation كلٌ كفعل UI منفصل أثناء بث Groq حي، فقد ثبتت حماياتها واختبارات discard وعدم اكتمال stream الملغى في مجموعة Flutter الكاملة، لا كثلاث جولات Groq حية منفصلة.

## بوابات التحقق

| البوابة | النتيجة |
|---|---|
| `flutter analyze --no-pub` | PASS، صفر مسائل، 225.5s |
| Flutter full suite | PASS، 1334/1334 |
| focused App Check/Groq/routing/Retry/Settings/lifecycle | PASS، 166/166 |
| small-talk focused matrix | PASS، 29/29، ضمن التغطية المركزة |
| task harness/support focused | PASS، 87/87 |
| جميع اختبارات `tool/*.test.cjs` | PASS، 130/130 |
| `flutter build apk --debug --no-pub` | PASS |
| `git diff --check` | PASS؛ تحذيرات CRLF فقط |
| official App Check exchange | HTTP 200 |

لم تتغير ملفات Gateway، لذلك لم تُعد بوابات Gateway في هذه المهمة.

## التنظيف والحالة النهائية

| البند | الحالة |
|---|---|
| Flutter run processes | 0 |
| app process alive | false |
| package installed | true، نسخة واحدة |
| airplane mode | 0 |
| Wi‑Fi | enabled |
| synthetic Auth user/profile | محذوفان ومؤكدان |
| UI dumps / logs المؤقتة | منظفة |
| App Check registration الحالي | موجود ومحفوظ |
| final official exchange | 200 |

لم يتغير Cloud Run أو traffic أو Secret Manager أو نماذج Groq. بقي provider هو Groq primary، والنموذج الحي للمحادثة العامة `openai/gpt-oss-20b`، وFirebase text fallback معطل، والتنفيذ المالي المدعوم بالذكاء الاصطناعي معطل.

## الملفات التي تغيرت في هذه المهمة فقط

1. `tool/register_android_app_check_debug.cjs`
2. `tool/android_live_groq_force_stop_support.cjs`
3. `tool/android_live_groq_force_stop_support.test.cjs`
4. `tool/android_appcheck_smalltalk_acceptance_support.cjs`
5. `tool/android_appcheck_smalltalk_acceptance_support.test.cjs`
6. `tool/android_live_groq_runner_support.cjs`
7. `tool/android_live_groq_runner_support.test.cjs`
8. `docs/qa/groq_completion/APPCHECK_FINAL_LIVE_ACCEPTANCE_AR.md`

`tool/run_android_appcheck_smalltalk_acceptance.cjs` استُخدم لتشغيل القبول لكنه لم يتغير في هذه المهمة. لم تتغير ملفات Flutter runtime أو Gateway source في هذه الجولة.

## الخصوصية

لم يُحتفظ بأي من الآتي ولم يُدرج في هذا التقرير: App Check debug secret، App Check token الصادر، Firebase ID token، UID، Authorization header، بيانات دخول المستخدم الاصطناعي، نصوص prompts، نصوص الردود، أو UI XML. اقتصرت الأدلة على booleans، حالات typed، أعداد، أزمنة، provider/model، وHTTP status آمن.

## الحكم النهائي والقيود المتبقية

**Android Debug AI: PASS.** التسجيل الحالي صالح ومقبول، وتشغيل Flutter العادي يصل إلى Groq بعد App Check، بينما small talk المطلوب يبقى محليًا.

المتبقي لـRelease/Production:

1. تسجيل Debug هذا للتطوير فقط ولا يثبت Release.
2. لم يُبنَ أو يُوقّع APK/AAB Release في هذه المهمة.
3. لم يُنفذ قبول حي باستخدام Play Integrity وتوقيع Release.
4. سياسة Release التي تتطلب environment=production وHTTPS صريحًا مثبتة في الاختبارات، لكنها لم تُقبل حيًا على بيئة Production في هذه المهمة.
