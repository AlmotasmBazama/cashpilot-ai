# تقرير مزوّد الحذف السحابي الموثوق

التاريخ: 2026-08-21  
النطاق: Staging فقط في المشروع `cashpilot-ai-a6b49`  
القرار: **GO لمسار حذف الحساب في Staging**.

## النتيجة

نُقلت حدود الحذف الموثوق إلى خدمة Cloud Run مستقلة باسم
`cashpilot-account-deletion-staging`. لم يُضف أي مسار حذف إلى منطق Groq، ولم
تتغير حركة خدمة `cashpilot-ai-gateway-staging`.

الخدمة المستقلة تطبق عقد Flutter الموجود نفسه:

| العقد | القيمة |
|---|---|
| مفتاح الإعداد | `CASH_PILOT_ACCOUNT_DELETION_GATEWAY_BASE_URL` |
| حذف شجرة Firestore | `POST /v1/account-deletion/recursive` |
| حذف Firebase Auth أخيراً/الاستئناف | `POST /v1/account-deletion/auth` |
| الجسم الصارم | `operationId` و`targetOwnerScope` فقط |
| Auth | `Authorization: Bearer …`، مع `verifyIdToken(..., true)` وفحص الجمهور للمشروع |
| App Check | `X-Firebase-AppCheck`، ويُتحقق منه بخادم Firebase Admin |
| إثبات الحذف | `X-Cashpilot-Deletion-Session`، قيمة 256-bit canonical لا تسجل |
| الاستجابة العودية | `operationId`, `status=completed`, `verifiedEmpty=true`, `deletedDocuments>=0` |
| استجابة Auth | `operationId`, `status=completed`, `authDeleted=true`, `alreadyDeleted` |

لا يقبل الجسم UID أو مسار Firestore أو هوية بديلة. يشتق الخادم UID الوحيد من
Firebase ID token المتحقق، ثم يعيد اشتقاق التزام نطاق المالك ويقارنه بالطلب.
المخطط `strict` يرفض أي UID يضيفه العميل بدلاً من تجاهله بصمت.

## السبب الجذري الدقيق لـ providerUnavailable

كان العميل السابق يرسل العقد نفسه إلى خدمة Groq
`cashpilot-ai-gateway-staging`. في مراجعتها
`cashpilot-ai-gateway-staging-00005-civ` سجل Cloud Run ثلاث استجابات 503 خاصة
بالحذف: واحدة للمسار العودي واثنتان لمسار Auth. كانت هوية المراجعة:

`cashpilot-ai-gateway-staging@cashpilot-ai-a6b49.iam.gserviceaccount.com`

وأدوارها على المشروع كانت فقط:

- `roles/firebaseappcheck.tokenVerifier`
- `roles/firebaseauth.viewer`

لم تكن تملك صلاحية Firestore data للوصول إلى معاملة قفل الحذف، ولا صلاحية حذف
Firebase Auth. بعد نجاح Auth وApp Check والإثبات، أول حد Admin في المسار العودي
هو معاملة Firestore لإنشاء/قراءة قفل العملية. لذلك تعذّر العبور إلى الحذف
العودي؛ والكود المنشور القديم كان يطوي أخطاء Admin غير المتوقعة إلى
`providerUnavailable`/HTTP 503 من دون تسجيل المرحلة الداخلية. اجتماع سجل 503
المقيد بالمسارين، وهوية المراجعة، وقائمة IAM، وترتيب التنفيذ يثبت أن السبب هو
**نشر حذف الحساب تحت هوية Groq غير المخولة لأعمال Firestore/Auth**، وليس DNS أو
غياب route أو App Check أو مشكلة عميل.

## الحد الموثوق الجديد

تعمل الخدمة المستقلة عبر Firebase Admin Application Default Credentials بهوية:

`cashpilot-deletion-staging@cashpilot-ai-a6b49.iam.gserviceaccount.com`

وأدوار المشروع الممنوحة لها فقط هي:

- `roles/datastore.user`
- `roles/firebaseappcheck.tokenVerifier`
- `projects/cashpilot-ai-a6b49/roles/cashpilotDeletionAuthOperator`

الدور المخصص الأخير هو حد Auth الأدنى المطلوب لقراءة حالة المستخدم وحذفه؛ لم
تُمنح Owner أو Editor، ولم يُستخدم ملف service-account JSON أو مفتاح خاص.
السماح `roles/run.invoker` لـ `allUsers` مطلوب لوصول تطبيق الهاتف، لكن لا ينفذ
أي طلب حذف قبل تحقق Firebase Auth وApp Check وإثبات العملية داخل الخدمة.

## الحذف العودي والتحقق من الفراغ

يُنشأ قفل دائم opaque تحت `accountDeletionLocks/{SHA-256(uid)}` قبل الحذف. لا
يحمل اسم المستند UID خاماً، ولا يعد القفل بيانات مستخدم قابلة للاستعادة؛ هو
سياج أمان واحتفاظ يمنع عملية متعارضة أو إعادة إحياء حساب محذوف.

يستخدم الخادم `recursiveDelete` في Firebase Admin على جذر
`users/{verifiedUid}`، لذلك تُحذف الوثيقة الأصلية وكل المجموعات الفرعية المعروفة
وغير المعروفة بلا allowlist ثابتة. بعد ذلك يعيد فحص الوثيقة، ويستدعي
`listCollectionIds` للتأكد من عدم بقاء شجرة فرعية، ثم يثبت النتيجة في القفل.
لا تُعاد `completed` ما لم يكن الجذر غائباً والشجرة فارغة. جرد المصدر لم يجد
بيانات مستخدم قابلة للاستعادة خارج `users/{uid}`؛ المسار العالمي الوحيد الخاص
بالحذف هو القفل retained غير المحتوي على UID خام.

اختبار Android الحي زرع مجموعة مستقبلية غير معروفة متداخلة ثم أثبت أن شجرة
السحابة فارغة. نفذت المراجعة الجديدة عمليتي حذف عوديتين كاملتين، وتحققت أربع
عمليات نهائية (recursive وAuth للحسابين) من الفراغ.

## الأمن والأخطاء

النتائج typed ومغلقة، ومنها: `authenticationRequired`, `appCheckUnavailable`,
`deletionProofInvalid`, `permissionDenied`, `cloudDeleteTimedOut`,
`cloudDeletePartial`, `cloudVerificationFailed`, `providerUnavailable` و
`unknownTemporaryFailure`. لا ينعكس استثناء Admin أو stack trace إلى Flutter.

HTTP الحي أثبت 405 للطريقة غير المسموحة، 415 لنوع المحتوى الخطأ، 400 لـ JSON
غير الصالح، 413 للجسم الأكبر من 4096 بايت، و404 للمسار الغائب. كل الاستجابات
الحساسة تحمل `Cache-Control: no-store`. Auth المفقود/الخاطئ أعاد 401، وApp Check
المفقود/الخاطئ أعاد 401، بينما قبل الطلب الحي الصحيح من Android.

## الرصد الآمن

السجل المنظم يحوي فقط correlation ID، operation ID، revision، stage، المدة،
المحاولة، عدداً آمناً، النتيجة typed، فئة الخطأ الآمنة، HTTP status وقابلية
الإعادة. المراحل المنشورة هي `requestReceived`, `authVerified`,
`appCheckVerified`, `proofVerified`, `deletionStarted`,
`recursiveDeleteCompleted`, `verificationStarted`, `verificationCompleted`,
`responseSent`.

في 73 مدخلة للمراجعة المنشورة، وُجدت 52 مدخلة ذات مرحلة منظمة وصفر حقل باسم
UID أو email أو token أو proof أو Authorization. لم تحفظ التقارير أي اعتماد أو
محتوى مالي أو إيصال.

## الاختبارات

- اختبارات الخادم: **31/31 PASS**.
- lint، typecheck، build، secret scan: **PASS**.
- محاكي حذف الحساب الحقيقي: **2/2 PASS**.
- Firestore rules: **42/42 PASS**، ويستدعي أيضاً محاكي الحذف 2/2.
- مصفوفة الأمن المفصلة: `SECURITY_TEST_MATRIX.csv`.

