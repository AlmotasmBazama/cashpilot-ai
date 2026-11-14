# قبول Android الحي لتطبيق CashPilot AI

التاريخ: 2026-08-11، المنطقة الزمنية: Africa/Tripoli.

حالة الوثيقة: **نهائي لهذا السبرنت**. نُفذت الخطوات الستون على Android debug، وكانت النتيجة 56 `PASS` و0 `FAIL` و4 `BLOCKED`. كلمة `BLOCKED` تعني أن دليل التنفيذ المحدد لم يكن متاحًا، لا أن التطبيق تعطل.

## 1. حدود الدليل

- لا يتضمن التقرير أسرار App Check أو مفاتيح API أو UIDs أو owner scopes أو بيانات تسجيل الدخول أو نصوص prompts/responses.
- الاختبار الحي يثبت Firebase AI Logic عبر Vertex AI في Android debug فقط؛ لا يثبت Groq أو Web أو إصدار production.
- قياسات الأداء من emulator/debug ومؤشرات instrumentation، وليست profile لإصدار release على جهاز فعلي.
- لم يُستخدم أي إيصال أو بيان مالي حقيقي؛ كل بيانات القبول اصطناعية.

## 2. البيئة والبوابات

| البند | النتيجة النهائية |
|---|---|
| الجهاز | emulator-5554، Android API 37، debug |
| Firebase AI | Vertex AI، location=`global`، model=`gemini-3.6-flash` |
| الاختبار الحي الأساسي | exit 0؛ طلبان محليان وثلاثة طلبات بعيدة؛ نجاح العربية والإنجليزية |
| اختبار الفشل والتعافي | exit 0؛ فشل typed باسم `appCheckUnavailable` أثناء تعطيل الشبكة ثم Retry ناجح |
| Analyzer | 0 issues في 142.7s |
| Flutter full suite | 1187/1187 PASS |
| Android navigation integration | 1/1 PASS |
| Android debug build | PASS في 21.1s؛ APK ‏225344000 بايت |
| Clean-install smoke | install Success؛ COLD Status ok؛ TotalTime ‏4933ms؛ auth/onboarding ظاهر؛ fatal markers=0 |
| Web preflight | build 91.9s؛ Wasm dry-run؛ index/main/sqlite/worker جميعها HTTP 200 |
| Firestore/Auth emulator | exit 0 في 143s |
| Gateway | لم يتغير؛ بوابته السابقة 109/109 |

بصمة APK النهائية: `1C64A74E62200D76B55E5B95A4FE638C671C7992006F1B928EAF2671D36BF0D6`.

## 3. تسلسل القبول اليدوي — 60 خطوة بالضبط

| # | الخطوة | الحالة | الدليل المختصر |
|---:|---|---|---|
| 1 | Cold start | PASS | آخر clean-install smoke: `Status ok` و`TotalTime=4933ms` وظهرت واجهة auth/onboarding بلا fatal markers؛ قياس retained-state سابق على APK المعاد بناؤه كان 3789ms |
| 2 | Warm return حقيقي | BLOCKED | الأداة أعطت `HOT` فقط؛ لا ادعاء `WARM` |
| 3 | Background/resume | PASS | رجوع `HOT` خلال 117ms بلا crash |
| 4 | لا splash أو blank دائم | PASS | وصلت الواجهة القابلة للاستخدام في كل تشغيل مرصود |
| 5 | Login بمستخدم اصطناعي أول | PASS | نجح الدخول وظهرت بيانات النطاق الأول |
| 6 | Logout | PASS | عادت واجهة المصادقة دون تسريب بيانات |
| 7 | Login مرة أخرى | PASS | عاد المستخدم الأول إلى Dashboard بنجاح |
| 8 | الاحتفاظ بالـroute أثناء transient auth loading محقون يدويًا | BLOCKED | لم تُنفذ حقنة الحالة الدقيقة يدويًا؛ اختبار navigation ‏1/1 يغطي المسار آليًا فقط |
| 9 | فتح Dashboard | PASS | فتح من التنقل الرئيسي |
| 10 | تحميل totals/cards | PASS | ظهرت الإجماليات والبطاقات دون خطأ دائم |
| 11 | Pull to refresh | PASS | قُبل السحب للتحديث |
| 12 | انتهاء refresh | PASS | انتهت حالة التحميل وعادت الواجهة للتفاعل |
| 13 | إنشاء cash account | PASS | أُنشئ حساب نقدي اصطناعي بعملة LYD ورصيد افتتاحي |
| 14 | إنشاء bank account | PASS | أُنشئ حساب مصرفي اصطناعي بعملة LYD ورصيد افتتاحي |
| 15 | تعديل account metadata | PASS | ظهر الاسم المعدل في القائمة |
| 16 | فتح account details | PASS | عرض النوع والرصيد الصحيحين |
| 17 | إنشاء income posted | PASS | ظهرت معاملة دخل اصطناعية في الحساب المختار |
| 18 | إنشاء expense posted | PASS | ظهر مصروف اصطناعي ضمن فئة طعام |
| 19 | إنشاء pending expense | PASS | ظهرت المعاملة بحالة pending |
| 20 | تعديل pending expense | BLOCKED | شاشة التفاصيل الحالية توفر Delete فقط ولا تعرض Edit |
| 21 | بحث المعاملات | PASS | أعاد البحث النتيجة الاصطناعية المطابقة بعد debounce |
| 22 | filters وsort | PASS | Income وExpense وPending وOldest أعطت الحالات المتوقعة |
| 23 | تحميل صفحة يدوية بعد أكثر من 50 صفًا | BLOCKED | fixture اليدوي احتوى سبعة صفوف فقط؛ دلالات pagination وEN/AR خضراء آليًا 2/2 |
| 24 | تحويل بنفس العملة | PASS | نُفذ تحويل واحد بين الحسابين |
| 25 | تحديث رصيدي الحسابين | PASS | نقص المصدر وزاد الهدف مرة واحدة بالقيمة نفسها |
| 26 | منع duplicate tap | PASS | ضغطتان متتاليتان أنشأتا زوج قيود واحدًا فقط ومسحتا المبلغ بعد النجاح |
| 27 | منع source=destination | PASS | حساب المصدر استُبعد من قائمة الوجهة، فمنعت الواجهة الاختيار غير الصالح |
| 28 | إنشاء monthly budget | PASS | أُنشئت ميزانية شهرية اصطناعية لفئة الطعام |
| 29 | تحقق budget progress | PASS | احتسب posted expense فقط؛ استُبعد pending والتحويل |
| 30 | تعديل budget | PASS | انعكس الحد الجديد وتحدث remaining |
| 31 | إنشاء savings goal | PASS | ظهر هدف اصطناعي Active بالقيمة المستهدفة |
| 32 | إضافة contribution | PASS | أضيفت مساهمة اصطناعية واحدة |
| 33 | تحقق goal progress | PASS | ظهرت النسبة والرصيد المتبقي الصحيحان |
| 34 | فتح monthly report | PASS | ظهرت قيم الدخل والمصروف والادخار المنشورة |
| 35 | فتح yearly report | PASS | تغير الاختيار السنوي وعرض بيانات الفترة المتاحة؛ بعض labels داخل اللوحة تبقى شهرية |
| 36 | فتح category report | PASS | ظهرت فئة الطعام وقيمتها المنشورة |
| 37 | فتح cash flow | PASS | ظهر cash-flow بالمعاملات المحلية المنشورة |
| 38 | لا infinite loading في Reports | PASS | اكتملت اللوحات خلال نافذة المراقبة |
| 39 | تحية عربية محلية | PASS | ظهر رد محلي فوري؛ لا Firebase session |
| 40 | طلب عربي بعيد | PASS | ظهر رد عربي حقيقي عبر Vertex AI وانتهى loading |
| 41 | طلب إنجليزي بعيد | PASS | ظهر رد إنجليزي حقيقي عبر Vertex AI وانتهى loading |
| 42 | AI مع تعطيل الشبكة | PASS | انتهى loading بخطأ مؤقت typed قابل للإعادة؛ السبب المرصود `appCheckUnavailable` لا `offline` حرفيًا؛ مُنع الإرسال المزدوج |
| 43 | استعادة الشبكة ثم Retry | PASS | نجح Retry؛ بقي دور مستخدم واحد ولم تتكرر الرسالة |
| 44 | مغادرة AI أثناء streaming | PASS | بقيت الواجهة قابلة للتنقل ولم يظهر رد متأخر على route غير صالح |
| 45 | New Conversation أثناء نشاط سابق | PASS | مُسح السياق المرئي بأمان؛ إصلاح regression مثبت أيضًا بـwidget ‏2/2 واختبار حي |
| 46 | تمرير محادثة طويلة | PASS | أمكن التمرير والعودة إلى أحدث محتوى دون تجمد |
| 47 | فتح receipt scanner | PASS | فتح من Transactions |
| 48 | اختيار صورة اصطناعية | PASS | قبل picker الصورة الاصطناعية دون استخدام إيصال حقيقي |
| 49 | استجابة UI أثناء preparation | PASS | بقيت الواجهة قابلة للتفاعل والتنقل |
| 50 | navigation أثناء preparation | PASS | لم يقع late navigation أو route متأخر بعد المغادرة |
| 51 | Retry بصورة اصطناعية صالحة للتحميل | PASS | انتهت المحاولة إلى failure آمن مع زر Retry؛ لا ادعاء استخراج حي |
| 52 | الخروج من loading في الإيصالات | PASS | لا stuck loading؛ failure المنقح قابل لإعادة المحاولة |
| 53 | تبديل العربية والإنجليزية | PASS | تبدلت لغة الواجهة وطبقت الحالة |
| 54 | تبديل light/dark | PASS | تغير الثيم دون إعادة تشغيل قسرية |
| 55 | العودة للشاشات الرئيسية | PASS | Dashboard وبقية التنقل بقيت قابلة للفتح بعد الإعدادات |
| 56 | ثبات settings | PASS | ظلت اللغة والثيم المطبقان متسقين خلال التنقل |
| 57 | Logout من المستخدم الأول | PASS | خرج النطاق الأول قبل بدء فحص العزل |
| 58 | Login بمستخدم اصطناعي ثانٍ | PASS | بدأ نطاق مالك مستقل |
| 59 | عدم عرض بيانات المستخدم الأول | PASS | لم تظهر الحسابات أو المعاملات أو الميزانية أو الهدف للمستخدم الثاني |
| 60 | حالة AI للمستخدم الثاني | PASS | بدأت محادثة نظيفة دون سجل المستخدم الأول |

التوزيع النهائي: `PASS=56`، `FAIL=0`، `BLOCKED=4`.

## 4. تفسير الحجب الأربعة

1. الخطوة 2: لا توجد نتيجة `WARM` حقيقية؛ القياس المتاح `HOT` فقط.
2. الخطوة 8: لم تُحقن transient auth-loading الدقيقة يدويًا؛ تغطية integration لا تتحول إلى قبول يدوي.
3. الخطوة 20: تعديل المعاملة pending غير متاح في واجهة التفاصيل الحالية.
4. الخطوة 23: لم يُنشأ fixture واجهة يتجاوز 50 صفًا؛ pagination/search/sort العالمي مغطى آليًا، لا يدويًا.

## 5. أدلة AI الحية

- runner الأساسي: طلبان محليان وثلاثة بعيدة، `firebaseSessions=3` للطلبات البعيدة فقط، والعربية والإنجليزية نجحتا.
- البث العربي أظهر جزأين؛ أول محتوى 4305ms والاكتمال 4747ms. البث الإنجليزي أظهر أربعة أجزاء؛ أول محتوى 3530ms والاكتمال 4600ms. اكتمل الطلب البعيد الثالث في 5144ms.
- runner الفشل والتعافي: انتهى الفشل المؤقت، مُنع double-send، عادت الشبكة، ونجح Retry دون تكرار دور المستخدم.
- نجاح New Conversation أثناء البث مثبت يدويًا وباختبار widget ‏2/2.

## 6. الإيصالات والأداء

- خطوات 47–52 تثبت سلامة UI، الاستجابة، منع late route، والخروج من loading إلى failure قابل لإعادة المحاولة.
- لا تثبت هذه الخطوات نجاح vision/OCR حي، ولا يوجد frame/memory profile فعلي للإيصال.
- snapshot الرسوم: 570 إطارًا، 347 janky بنسبة 60.88%؛ p50=18ms وp90=26ms وp95=34ms وp99=53ms. هذه ملاحظة emulator/debug/instrumentation وليست حكم release.

## 7. التنظيف والخصوصية

- حُذف مستخدما الاختبار الاصطناعيان بعد قبول العزل.
- حُذف تسجيل App Check اليدوي الخاص بالسبرنت فقط، مع الحفاظ على التسجيلين الموجودين غير التابعين له.
- مُسح logcat بعد آخر smoke؛ لم تحفظ prompts أو responses أو tokens أو UIDs أو بيانات دخول في التقرير.

## 8. الحكم

Android debug **جاهز للاستخدام اليومي ضمن حدود السبرنت**: الوظائف الأساسية وFirebase AI الحي والتعافي والعزل نجحت، بلا `FAIL`. تبقى القيود الأربعة أعلاه، وretained-device secure-storage upgrade، واستخراج الإيصال الحي، وperformance profile الحقيقي. هذا لا يساوي جاهزية إصدار production.
