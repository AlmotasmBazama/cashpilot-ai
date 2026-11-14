# مصفوفة توفر الذكاء الاصطناعي — CashPilot AI

التاريخ: 2026-08-11.

حالة الوثيقة: **نهائية لسبرنت Android الحي**. النتيجة الأساسية: Firebase AI حي وجاهز على Android debug؛ Groq غير مهيأ؛ Web code/build جاهز لكن AI الحي والقبول المرئي محجوبان خارجيًا.

## ملخص المزود والمنصة

| المسار | Android debug | Web | الحكم |
|---|---|---|---|
| الرد المحلي deterministic | PASS يدويًا وداخل runner؛ طلبان محليان وصفر Firebase sessions | متاح في الكود؛ غير مقبول بصريًا | جاهز على Android |
| Firebase AI العام | PASS حي ويدوي؛ Vertex AI في `global` بالنموذج `gemini-3.6-flash` | لم يُنفذ حيًا | جاهز على Android debug فقط |
| Groq | غير مهيأ ولا يوجد طلب حي | غير مهيأ | `EXTERNALLY_NOT_CONFIGURED` |
| AI failure/Retry | PASS؛ runner مستقل exit 0 وRetry يدوي ناجح | غير منفذ | جاهز على Android ضمن caveat التصنيف |
| Receipt vision | UI safety PASS؛ لا استخراج حي مثبت | غير مقبول حيًا | غير جاهز كـlive extraction |
| التحليل المالي الشخصي | معطل افتراضيًا | معطل افتراضيًا | ليس جزءًا من الجاهزية الحية الحالية |

## مصفوفة القدرات

| القدرة | شرطها | Android الآن | Web الآن |
|---|---|---|---|
| `directConversationAvailable` | لا تحتاج شبكة أو صلاحيات مالية | PASS؛ تحية محلية فعلية | code-ready فقط |
| `generalConversationAvailable` | Firebase Core وAuth وApp Check ومزود صالح | PASS عبر Vertex AI | BLOCKED_EXTERNAL |
| `currentKnowledgeAvailable` | route grounded مستقل | معطلة افتراضيًا | معطلة افتراضيًا |
| `personalFinancialAnalysisAvailable` | owner scope وصلاحية قراءة ومزود مالي | معطلة افتراضيًا | معطلة افتراضيًا |
| `financialDraftsAvailable` | سياسة draft مستقلة | معطلة افتراضيًا | معطلة افتراضيًا |
| `confirmedExecutionAvailable` | تأكيد وسياسة تنفيذ | معطلة افتراضيًا | معطلة افتراضيًا |
| `receiptVisionAvailable` | موافقة ومزود vision وpreflight صالح | مؤهلة شرطيًا؛ لا live extraction مثبت | BLOCKED_EXTERNAL |
| `navigationAvailable` | policy مستقلة | معطلة افتراضيًا | معطلة افتراضيًا |
| `localParserOnly` | محلل أوامر حتمي | متاح لوظيفته؛ ليس نموذج chat | متاح في الكود |

## الدليل الحي على Android

- runner الأساسي خرج 0.
- طلبان محليان اكتملَا دون بدء Firebase session.
- ثلاثة طلبات بعيدة اكتملت كإجابات مع `firebaseSessions=3`.
- نجح الرد العربي والرد الإنجليزي في واجهة Android، وانتهت حالات loading دون رسالة عدم توفر عامة.
- القياس المنقح: العربي أول محتوى 4305ms واكتمال 4747ms؛ الإنجليزي أول محتوى 3530ms واكتمال 4600ms؛ الطلب البعيد الثالث اكتمل في 5144ms.
- لم تُحفظ نصوص الطلبات أو الإجابات في الدليل.

## الفشل والتعافي

عند تعطيل الشبكة فشل App Check قبل وصول الطلب إلى المزود؛ لذلك كان السبب typed الصحيح المرصود `appCheckUnavailable` لا `offline` حرفيًا. انتهى loading، بقي السبب retryable، مُنع double-send، ثم أعيد الاتصال ونجح Retry. بقي دور مستخدم واحد ولم تتكرر الرسالة، وبدأت محادثة جديدة بحالة نظيفة.

## الاستمرارية وNew Conversation

أصلح مساران مرتبطان:

- أصبحت Firebase ChatSession history قابلة للنمو، بما يلائم طفرة SDK بعد الرد.
- أصبحت New Conversation أثناء stream تلغي الجيل السابق وتتجاهل أي نتيجة متأخرة.

التحقق: widget ‏2/2 للمحادثة الجديدة، اختبار حي للمغادرة/المحادثة الجديدة، navigation integration ‏1/1، ومجموعة Flutter النهائية 1187/1187.

## أسباب عدم التوفر typed

| السبب | المعنى الآمن | Retry |
|---|---|---|
| `platformNotConfigured` | المنصة غير مهيأة | بعد إصلاح الإعداد |
| `firebaseNotInitialized` | Firebase Core غير جاهز | حسب مسار الاستعادة |
| `firebaseAiUnavailable` | خدمة Firebase AI غير متاحة مؤقتًا | نعم |
| `appCheckUnavailable` | attestation لم يكتمل | نعم عند الفشل المؤقت |
| `authenticationRequired` | يلزم تسجيل الدخول | بعد تسجيل الدخول |
| `gatewayDisabled` | route أو gateway معطل | بعد تغيير الإعداد |
| `gatewayUrlMissing` | URL المطلوب غير موجود | بعد الإعداد |
| `gatewayUnreachable` | gateway غير قابل للوصول | نعم |
| `providerTimedOut` | انتهت مهلة المزود | نعم |
| `providerRejectedRequest` | رفض المزود الطلب | حسب السبب |
| `modelUnavailable` | النموذج غير متاح | نعم لطلب جديد |
| `offline` | الشبكة غير متاحة بعد وصول التصنيف لهذه الطبقة | بعد عودة الشبكة |
| `financialAccessDisabled` | القراءة/التحليل المالي غير مفعل | لا يمنع chat العام |
| `ownerScopeNotReady` | نطاق المالك غير جاهز | بعد اكتماله |
| `receiptVisionUnavailable` | رؤية الإيصال غير متاحة | لا يمنع النص العام |
| `unknownTemporaryFailure` | فشل مؤقت منقح | نعم |

## Receipt AI

نجحت سلامة واجهة الإيصال بصورة اصطناعية: بقيت UI مستجيبة، لم يحدث late route بعد المغادرة، وانتهى Retry إلى failure آمن قابل للإعادة دون stuck loading. بوابة worker هي 25/25. لا يُحوّل ذلك إلى نجاح extraction أو OCR/vision حي.

## Web

نجح Web build في 91.9s، وWasm dry-run، وأعادت أصول index وmain وsqlite وworker الحالة 200. يبقى التشغيل المرئي وAI الحي محجوبين بسبب App Check للويب وauthorized domains وجلسة browser/بيئة النشر. بناء الكود ليس live AI acceptance.

## البوابات المرتبطة

| البوابة | النتيجة |
|---|---|
| Analyzer النهائي | 0 issues في 142.7s |
| Flutter النهائي | 1187/1187 PASS |
| Android navigation integration | 1/1 PASS |
| Android live AI الأساسي | exit 0 |
| Android live failure/recovery | exit 0 |
| Android debug build | PASS في 21.1s |

بوابة AI ‏88/88 كانت نتيجة سابقة مركزة، وليست بديلًا للعدد النهائي الحالي 1187/1187.

## الخصوصية والتنظيف

حُذف تسجيل App Check اليدوي الخاص بالسبرنت مع الحفاظ على تسجيلين قائمين غير تابعين له، وحذف مستخدما الاختبار الاصطناعيان ومسح logcat. لا تعرض الواجهة أو هذه الوثيقة stack traces أو tokens أو UIDs أو URLs داخلية أو نصوص خاصة.

## الحكم النهائي

- Firebase AI على Android debug: **LIVE READY**.
- المحادثة العربية والإنجليزية على Android: **PASS**.
- failure/Retry/navigation/New Conversation: **PASS** ضمن السيناريوهات المنفذة.
- Groq: **EXTERNALLY NOT CONFIGURED**.
- Web AI: **BLOCKED EXTERNAL/MANUAL** رغم نجاح البناء.
- receipt live extraction والتحليل المالي الشخصي وproduction release: **غير مثبتة/غير جاهزة**.
