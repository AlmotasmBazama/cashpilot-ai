# تقرير الجاهزية الوظيفية الشاملة لتطبيق CashPilot AI

التاريخ: 2026-08-11، المنطقة الزمنية: Africa/Tripoli.

حالة الوثيقة: **نهائي لسبرنت الإغلاق الحي على Android**. الحكم يميز صراحةً بين جاهزية Android debug للاستخدام اليومي، وجاهزية Web البرمجية، وجاهزية إصدار production.

## 1. الملخص التنفيذي

أُغلقت بوابات الكود الحالية: Analyzer بلا مشاكل، مجموعة Flutter كاملة 1187/1187، integration للتنقل 1/1، بناء Android debug، بناء Web، واختبارات Firestore/Auth emulator. نفذ القبول اليدوي 60 خطوة بنتيجة 56 نجاحًا و0 فشل و4 خطوات محجوبة. Firebase AI حي على Android debug وجاهز ضمن هذا النطاق. لا يزال إصدار production غير جاهز.

## 2. نطاق الإغلاق

يشمل هذا التقرير الوظائف اليومية على Android، توفر AI الحي، العيوب الخمسة FUNC-015/016/017/018/028، الأداء، العزل بين المالكين، والبوابات النهائية. لا يوسع الدليل إلى Groq أو Web live أو مفاتيح وتوقيع production.

## 3. سلامة المستودع والدليل

حُفظت تغييرات المستخدم الموجودة ولم تستخدم reset أو clean أو restore أو stash أو commit أو push. حساب الجولة عند cutoff هو 55 مسارًا: 47 implementation/test/integration/tool، و7 تقارير، وملف baseline واحد؛ لا يعاد استخدام رقم 111 التاريخي. التقارير لا تحتوي tokens أو API keys أو UIDs أو owner scopes أو بيانات اعتماد أو نصوص prompts/responses.

## 4. سجل العيوب النهائي

يحتوي `FUNCTIONAL_DEFECTS.csv` على 28 عيبًا و18 عمودًا. التوزيع النهائي: 22 `Fixed Pending Manual Verification`، و1 `Fixed Pending External Configuration`، و2 `Verified`، و3 `Blocked`، و0 `Reproduced`. رُقّي FUNC-014 إلى `Verified` بعد إثبات المزود الحي على Android، ورُقّيت العيوب الخمسة المعاد إنتاجها إلى إصلاحات ذات حدود تحقق صريحة.

## 5. السبب الجذري لفشل AI الحي

كانت قائمة history المقدمة إلى Firebase ChatSession ثابتة أو `growable:false`، بينما تضيف SDK إليها بعد الرد. أدى ذلك إلى `UnsupportedError` بعد وصول المزود ثم تصنيف أعلى مضلل نسبيًا. أصبحت كل القوائم growable مع حدود الذاكرة والخصوصية نفسها، وثبت append/remove آليًا ونجح المسار الحي.

## 6. اختيار المزود

المزود المثبت حيًا هو Firebase AI Logic عبر Vertex AI، location=`global`، model=`gemini-3.6-flash`. Groq غير مهيأ خارجيًا ولا يملك دليل طلب حي. قواعد fallback تمنع الانتقال بعد ظهور المحتوى كي لا تمزج ردين.

## 7. فصل قدرات AI

المحادثة المحلية والعامة منفصلتان عن القراءة المالية والمسودات والتنفيذ المؤكد ورؤية الإيصال. تعطيل القدرات المالية لا يعطل التحية أو المحادثة العامة. التحليل المالي الشخصي والتنفيذ المؤكد يبقيان معطلين افتراضيًا ما لم تتوافر السياسة والنطاق والمزود.

## 8. قبول Firebase AI على Android

نجح runner الأساسي بخروج 0: طلبان محليان لم يبدآ Firebase session وثلاثة طلبات بعيدة اكتملت كإجابات مع `firebaseSessions=3`. نجح المحتوى العربي والإنجليزي يدويًا وداخل gate الحي. لم تُحفظ النصوص نفسها.

## 9. الفشل والتعافي

نجح runner مستقل بخروج 0 عند تعطيل الشبكة. السبب typed المرصود كان `appCheckUnavailable` لأن App Check فشل قبل الطلب، وليس `offline` حرفيًا. انتهى loading، مُنع double-send، أعيد الاتصال، ونجح Retry دون تكرار دور المستخدم.

## 10. دورة حياة المحادثة

نجحت مغادرة شاشة AI أثناء البث، محادثة جديدة، وتمرير محادثة طويلة. عيب New Conversation أثناء stream عولج واختباره widget ‏2/2، ثم تحقق حيًا. تُهمل النتائج المتأخرة باستخدام generation ولا تلحق route قديمًا.

## 11. بدء التشغيل ونطاق المالك

آخر clean-install smoke للـAPK النهائي أعطى install Success وCOLD `Status ok` و`TotalTime=4933ms` مع ظهور auth/onboarding و0 fatal markers. قياس retained-state سابق كان 3789ms، وHOT resume كان 117ms. عولج أيضًا سباق startup repair الذي كان يفتح `deletionQuarantined` مؤقتًا ثم يترك providers مخزنة على failure؛ بعد انتهاء الإصلاح الآمن يعاد بناء جلسة قاعدة البيانات فقط للهوية الحالية المطابقة.

## 12. Dashboard

نجح فتح اللوحة وتحميل totals/cards والسحب للتحديث وانتهاء refresh. read model محدود مع COUNT دقيق يمنع تحويل السجل كاملًا. قياس host السابق انتقل من 10020 صفًا و520787µs إلى 20 صفًا و2349µs.

## 13. Accounts

نجح إنشاء حساب نقدي وحساب مصرفي اصطناعيين، تعديل metadata، فتح التفاصيل، وتحديث الرصيدين بعد المعاملات والتحويل. لا توجد بيانات مالية حقيقية في الدليل.

## 14. Transactions

نجح إنشاء دخل ومصروف posted ومصروف pending، ثم البحث والفلترة والفرز. تعديل pending غير متاح في شاشة التفاصيل الحالية فبقيت الخطوة 20 محجوبة. pagination العالمية خضراء آليًا EN/AR، لكن fixture اليدوي لم يتجاوز سبعة صفوف.

## 15. Transfers

نجح تحويل same-currency وتحديث الحسابين مرة واحدة. ضغطتان سريعتان لم تنشئا إلا زوج قيود واحدًا. منع source=destination مثبت باستبعاد حساب المصدر من قائمة الوجهة، ولذلك الخطوة 27 `PASS`.

## 16. Budgets

نجح إنشاء ميزانية شهرية وتحقق progress وتعديل الحد. احتسب posted expense واستبعد pending والتحويل. انتقل fixture الأداء من 10020 صفًا و179125µs إلى 20 صفًا و1100µs، مع بقاء profile الجهاز غير ملتقط.

## 17. Goals

نجح إنشاء هدف ادخار وإضافة مساهمة وعرض الحالة والنسبة والمتبقي بصورة صحيحة ضمن بيانات الاختبار الاصطناعية.

## 18. Reports

نجحت التقارير الشهرية والسنوية والفئة وcash flow بلا loading لا نهائي. لوحظ قيد عرض: بعض labels داخل لوحة التقرير السنوي ما زالت شهرية؛ اختيار الفترة والبيانات عملا ضمن القبول.

## 19. Receipts

نجحت خطوات scanner الست باستخدام صورة اصطناعية: فتح، اختيار، بقاء UI مستجيبة، navigation أثناء التحضير دون late route، Retry، والخروج من loading إلى failure آمن قابل للإعادة. هذا لا يثبت استخراج vision/OCR حيًا. العامل الحسابي مغطى بـ25/25.

## 20. اللغة والثيم وRTL

نجح تبديل العربية والإنجليزية وتبديل light/dark والعودة للشاشات الرئيسية مع ثبات الإعداد. محلل Decimal المحلي يغطي فاصل التجميع العربي والفارسي، لكن لم تُدخل يدويًا كل مصفوفة النماذج المالية RTL.

## 21. عزل المستخدمين

نجح logout للمستخدم الأول ثم دخول مستخدم اصطناعي ثانٍ. لم تظهر حسابات أو معاملات أو ميزانيات أو أهداف أو سجل AI للمستخدم الأول. بعد الاختبار حُذف المستخدمان الاصطناعيان.

## 22. التخزين الآمن

FUNC-028 أصبح `Fixed Pending Manual Verification`: نجح harness الاصطناعي الدقيق 22/22، بما فيه 6/6 لسجلات legacy الواقعية والفساد وفشل القراءة والتنظيف المحدد. لا يوجد إثبات retained-device upgrade فعلي، ولذلك لا يدعي التقرير migration على جهاز محتفظ بالبيانات.

## 23. العيوب الخمسة المستهدفة

| العيب | النتيجة | الحد المتبقي |
|---|---|---|
| FUNC-015 | 10000→50 و209797→1738µs؛ EN/AR ‏2/2؛ الصفحة الأولى ثابتة أثناء loading/error/retry | fixture يدوي >50 غير متاح |
| FUNC-016 | search/filter/sort عالمي قبل LIMIT؛ manual صغير ناجح | long-history manual غير منفذ |
| FUNC-017 | 10020→20 و179125→1100µs؛ الميزانية اليدوية ناجحة | device performance profile غير ملتقط |
| FUNC-018 | 25/25؛ navigation/retry الآمنان ناجحان | لا live extraction أو frame/memory profile |
| FUNC-028 | synthetic ‏22/22 | retained-device upgrade محجوب |

## 24. الأداء المرصود

أرقام قاعدة البيانات السابقة هي medians على host. في Android debug/emulator رُصدت 570 frames منها 347 janky بنسبة 60.88%، مع p50=18ms وp90=26ms وp95=34ms وp99=53ms. هذه instrumentation/debug caveat وليست شهادة أداء production ولا قياسًا معزولًا لشاشة بعينها.

## 25. Analyzer والاختبارات

- `flutter analyze --no-pub`: 0 issues خلال 142.7s.
- `flutter test --no-pub -r compact`: 1187/1187 PASS.
- `integration_test/ai_navigation_device_regression_test.dart`: 1/1 PASS.
- الأرقام 1126 و1158 وAI ‏88/88 نتائج مراحل سابقة فقط وليست البوابة النهائية الحالية.

## 26. البناء والأصول

- Android debug build: PASS خلال 21.1s؛ APK ‏225344000 بايت؛ SHA-256 `1C64A74E62200D76B55E5B95A4FE638C671C7992006F1B928EAF2671D36BF0D6`.
- Web build: PASS خلال 91.9s؛ Wasm dry-run PASS؛ فحوص HTTP لـindex وmain وsqlite وworker كلها 200.

## 27. قواعد Firebase والبوابة

اختبارات Firestore/Auth emulator نجحت بخروج 0 خلال 143s على البيئة المعزولة. gateway لم يتغير في هذا السبرنت؛ دليله السابق بقي 109/109، ولم يُعاد نسبه خطأ إلى تشغيل حالي.

## 28. القبول اليدوي

التقرير التفصيلي يحتوي 60 صفًا بالضبط: 56 `PASS`، و0 `FAIL`، و4 `BLOCKED`. المحجوب هو true WARM، وحقن transient auth-loading الدقيق يدويًا، وتعديل pending من UI، وfixture pagination يدوي يتجاوز 50.

## 29. تنظيف App Check والسجلات

حُذف تسجيل App Check اليدوي الخاص بالسبرنت فقط، وحُفظ التسجيلان الموجودان غير التابعين له. مسح logcat بعد آخر clean-install smoke. لا يوجد token أو معرف مستخدم في التقارير.

## 30. حكم Android

Android debug جاهز للاستخدام اليومي ضمن حدود القبول: الوظائف المالية الأساسية، التقارير، الإعدادات، العزل، وFirebase AI الحي مع Retry نجحت بلا فشل يدوي. القيود الأربعة، performance profile، retained-device migration، وlive receipt extraction تبقى مصرحًا بها.

## 31. حكم Web وproduction

Web **جاهز من جهة الكود والبناء فقط**؛ التشغيل المرئي وAI الحي محجوبان بإعداد App Check وauthorized domains وجلسة browser/النشر. production release **غير جاهز** حتى applicationId النهائي، keystore والتوقيع وSHA وPlay Integrity/Google Sign-In، إضافة إلى إغلاق متطلبات Web إن كان ضمن الإصدار.

## 32. التوصية النهائية

يمكن اعتماد Android debug للاستخدام اليومي التجريبي مع مراقبة الأداء والقيود المعلنة. لا تنشر production ولا تصف Groq أو Web live أو receipt vision أو retained-device migration بأنها جاهزة قبل إغلاق إعداداتها واختباراتها الخارجية والفيزيائية.
