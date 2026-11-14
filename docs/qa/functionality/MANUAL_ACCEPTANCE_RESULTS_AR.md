# نتائج القبول اليدوي الوظيفي

التاريخ: 2026-08-11، المنطقة الزمنية: Africa/Tripoli.

حالة الوثيقة: **نهائية لسبرنت Android**. المرجع التفصيلي لكل خطوة هو `ANDROID_LIVE_ACCEPTANCE_AR.md`، ويحتوي 60 صفًا مرقمًا بالضبط.

## النتيجة المختصرة

| الحالة | العدد |
|---|---:|
| PASS | 56 |
| FAIL | 0 |
| BLOCKED | 4 |
| الإجمالي | 60 |

الحجب الأربعة: لا قياس `WARM` حقيقي لأن الأداة أعطت `HOT` فقط؛ لم تُنفذ حقنة transient auth-loading الدقيقة يدويًا؛ لا يوجد Edit لمعاملة pending في شاشة التفاصيل؛ ولم يتوفر fixture واجهة يتجاوز 50 معاملة لاختبار pagination يدويًا.

## بيئة Android

| البند | النتيجة |
|---|---|
| الهدف | emulator-5554؛ Android API 37؛ debug |
| APK النهائي | 225344000 بايت؛ SHA-256 `1C64A74E62200D76B55E5B95A4FE638C671C7992006F1B928EAF2671D36BF0D6` |
| آخر clean-install smoke | install Success؛ COLD Status ok؛ TotalTime ‏4933ms؛ auth/onboarding ظاهر؛ fatal markers=0 |
| ملاحظة retained-state السابقة | COLD ‏3789ms على APK معاد البناء |
| Background/resume | HOT ‏117ms |
| App Check | التسجيل اليدوي الخاص بالسبرنت حُذف بعد الاختبار؛ حُفظ تسجيلان غير تابعين له |
| بيانات الاختبار | اصطناعية فقط؛ حُذف المستخدمان A وB بعد اختبار العزل |

## ملخص الخطوات حسب المجال

| المجال | النتيجة | أهم الدليل |
|---|---|---|
| Startup/Auth | 6 PASS، 2 BLOCKED | cold وresume وlogin/logout/login وعدم blank نجحت؛ true WARM وauth-loading injection محجوبان |
| Dashboard | 4 PASS | الفتح والإجماليات وpull-to-refresh وانتهاء refresh |
| Accounts | 4 PASS | إنشاء نقدي ومصرفي وتعديل metadata والتفاصيل |
| Transactions | 6 PASS، 2 BLOCKED | دخل ومصروف وpending وبحث وفلاتر؛ لا Edit وfixture pagination صغير |
| Transfers | 4 PASS | التحويل وتحديث الرصيدين ومنع double-tap واستبعاد المصدر من الوجهة |
| Budgets | 3 PASS | إنشاء وprogress وتعديل |
| Goals | 3 PASS | إنشاء ومساهمة وprogress |
| Reports | 5 PASS | monthly/yearly/category/cash-flow ولا infinite loading |
| AI | 8 PASS | محلي وعربي بعيد وإنجليزي بعيد وفشل typed وRetry ومغادرة ومحادثة جديدة وتمرير طويل |
| Receipts | 6 PASS | صورة اصطناعية وUI مستجيبة ولا late route وRetry آمن؛ لا live extraction claim |
| Settings | 4 PASS | اللغة والثيم والعودة وثبات الإعداد |
| Owner isolation | 4 PASS | logout ودخول مستخدم ثانٍ وعدم تسرب المال أو سجل AI |

## تفاصيل مالية يدوية

- أُنشئ حسابان اصطناعيان بعملة LYD ثم عُدلت metadata وفتحت التفاصيل.
- أُنشئت معاملات دخل ومصروف posted ومصروف pending؛ نجح البحث والفلاتر والفرز.
- نُفذ تحويل same-currency مرة واحدة رغم الضغط السريع المكرر؛ استبعد picker حساب المصدر من الوجهة.
- احتسبت الميزانية المصروف المنشور فقط واستبعدت pending والتحويل، ثم انعكس تعديل الحد.
- انعكس إنشاء هدف ومساهمة في النسبة والمتبقي.
- عرضت التقارير الدخل والمصروف والفئة وcash flow دون loading لا نهائي. بعض labels داخل عرض السنة ما زالت شهرية، وهي limitation ظاهرة لا فشل تشغيل.

## تفاصيل AI اليدوية

- نجحت التحية المحلية دون Firebase session.
- نجح رد عربي بعيد ورد إنجليزي بعيد عبر Firebase AI Logic/Vertex AI.
- عند تعطيل الشبكة انتهى loading بسبب typed `appCheckUnavailable`؛ لا يُسجل كـ`offline` حرفيًا.
- مُنع double-send، ثم نجح Retry بعد عودة الشبكة دون تكرار دور المستخدم.
- نجحت المغادرة أثناء البث، New Conversation، وتمرير محادثة طويلة. إصلاح New Conversation مثبت أيضًا widget ‏2/2.

## الإيصالات

استخدمت صورة اصطناعية. بقيت الواجهة مستجيبة، وأمكن المغادرة أثناء التحضير دون انتقال متأخر. انتهت إعادة المحاولة إلى failure آمن يعرض Retry ولا يبقى في loading. النتيجة **سلامة UI ناجحة** وليست إثبات استخراج vision/OCR حي.

## عزل المستخدمين

بعد الخروج من المستخدم الأول ودخول المستخدم الثاني لم تظهر حسابات أو معاملات أو ميزانية أو هدف أو سجل AI من النطاق الأول. أُزيل المستخدمان الاصطناعيان بعد الاختبار، ولم تُحفظ identifiers في التقرير.

## نتائج الأداء المرصودة

| القياس | النتيجة | القيد |
|---|---|---|
| Clean-install COLD | 4933ms | emulator/debug؛ القياس النهائي بعد integration |
| Retained-state COLD | 3789ms | ملاحظة سابقة وليست clean install |
| HOT resume | 117ms | لا يساوي WARM |
| Gfx snapshot | 570 frames؛ 347 janky؛ 60.88%؛ p50 18، p90 26، p95 34، p99 53ms | instrumentation/debug emulator؛ ليس production profile |
| Transactions host fixture | 10000→50؛ 209797→1738µs | host median؛ manual >50 محجوب |
| Budgets host fixture | 10020→20؛ 179125→1100µs | host median؛ لا device profile |
| Dashboard prior host fixture | 10020→20؛ 520787→2349µs | prior focused evidence |

## البوابات الآلية النهائية

| البوابة | النتيجة |
|---|---|
| `flutter analyze --no-pub` | PASS؛ 0 issues؛ 142.7s |
| `flutter test --no-pub -r compact` | PASS؛ 1187/1187 |
| Android navigation integration | PASS؛ 1/1 |
| Android debug build | PASS؛ 21.1s |
| Web build | PASS؛ 91.9s؛ Wasm dry-run |
| Web local HTTP | index/main/sqlite/worker كلها 200 |
| Firestore/Auth emulator | PASS؛ exit 0؛ 143s |
| Gateway | لم يتغير؛ النتيجة السابقة 109/109 |

الأرقام 1126 و1158 وAI ‏88/88 تاريخية من بوابات سابقة، ولا تحل محل البوابة النهائية 1187/1187.

## قبول Web

| المجال | النتيجة | السبب |
|---|---|---|
| Code/build | PASS | build وWasm وHTTP preflight خضراء |
| Visual/responsive runtime | BLOCKED | لا جلسة browser موثقة لهذا الإغلاق |
| Auth live | BLOCKED_EXTERNAL | authorized domains/OAuth/App Check غير مغلقة |
| AI live | BLOCKED_EXTERNAL | App Check/runtime origin والقبول الحي غير مغلقة |

لا تتحول نتيجة build إلى قبول يدوي للويب.

## المحاسبة والتنظيف

حساب الجولة عند cutoff هو 55 مسارًا: 47 implementation/test/integration/tool، و7 تقارير، وملف baseline واحد. لا يُعاد استخدام رقم 111 التاريخي. حُذف مستخدما الاختبار وتسجيل App Check الخاص بالسبرنت، ومسح logcat بعد آخر smoke.

## الحكم اليدوي

Android debug مقبول للاستخدام اليومي ضمن الحدود المعلنة: 56 PASS، 0 FAIL، 4 BLOCKED. لا يعني ذلك جاهزية production، ولا يثبت Web live أو Groq أو استخراج الإيصال الحي أو retained-device migration.
