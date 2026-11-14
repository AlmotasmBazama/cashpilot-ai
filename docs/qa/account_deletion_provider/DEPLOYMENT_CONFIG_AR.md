# إعداد نشر مزوّد حذف الحساب

التاريخ: 2026-08-21  
البيئة: Staging فقط

| الحقل | القيمة المثبتة |
|---|---|
| المشروع | `cashpilot-ai-a6b49` |
| الخدمة | `cashpilot-account-deletion-staging` |
| المنطقة | `europe-west1` |
| المراجعة | `cashpilot-account-deletion-staging-00003-q4b` |
| الحركة | 100% إلى المراجعة الأحدث |
| الرابط الثابت | `https://cashpilot-account-deletion-staging-yfgt2ypuvq-ew.a.run.app` |
| صورة الحاوية | digest `sha256:10ea2fd807a1c17ce5906256ae380d222e6880add739e240883ee10af083b938` |
| runtime | Node.js 20+ / TypeScript / Express |
| CPU والذاكرة | 1 CPU، 512 MiB |
| timeout الخاص بـ Cloud Run | 120 ثانية |
| مهلة عملية الحذف الداخلية | 50000 ms |
| المحاولات الداخلية | 2؛ transient فقط |
| concurrency | 4 |
| maximum instances | 2 |
| حجم الجسم | 4096 بايت |
| المعدل | 6 طلبات حذف/دقيقة لكل principal/bucket |
| App Check | مفروض داخل route بواسطة Firebase Admin |
| Firebase Auth | مفروض داخل route، مع revocation check والجمهور الصحيح |
| Cloud Run IAM | `roles/run.invoker` لـ `allUsers` لتطبيق الهاتف؛ لا يساوي تفويض الحذف |
| حساب الخدمة | `cashpilot-deletion-staging@cashpilot-ai-a6b49.iam.gserviceaccount.com` |
| أصل Web المسموح | `https://cashpilot-ai-a6b49.web.app` |
| بصمة مصدر النشر | SHA-256 `92c66b55a1afde5fbd95693a34cfca1a8ae98cac7391063aad8c026d445bf2ac` |

## IAM الأدنى

| الدور | الغرض |
|---|---|
| `roles/datastore.user` | معاملة القفل، recursive delete، والتحقق من فراغ Firestore |
| `roles/firebaseappcheck.tokenVerifier` | التحقق من App Check |
| `projects/cashpilot-ai-a6b49/roles/cashpilotDeletionAuthOperator` | عمليات Auth المحددة اللازمة للقراءة والحذف |

لم تُمنح Owner أو Editor، ولم يُرفع ملف مفتاح. Application Default Credentials
مصدرها هوية Cloud Run نفسها. الخدمة متصلة صراحةً بمشروع Firebase
`cashpilot-ai-a6b49` وقاعدة Firestore الافتراضية المستخدمة من التطبيق.

## حالة النشر

المراجعة Ready وActive، والحاوية أصبحت healthy. نُشرت حزمة
`services/cashpilot_account_deletion` فقط. لم يُنشر Production، ولم تتغير حركة
Groq Gateway، وCloud Functions غير مستخدمة لهذا العقد.

ملف Flutter غير السري `config/groq_staging.json` يحدد رابط الخدمة المستقلة عبر
`CASH_PILOT_ACCOUNT_DELETION_GATEWAY_BASE_URL`. لا يوجد عنوان Production
افتراضي؛ لذلك يبقى Release مغلقاً عند غياب إعداد Production الصريح.

