# إعداد نشر بوابة Groq في بيئة Staging

**الحالة:** النشر والترويج مكتملان، محدّثة في 2026-08-14. المراجعة النهائية
`00005-civ` تخدم 100% والرابط الثابت متحقق.

## 1. الحالة المؤكدة قبل النشر

- مسار المصدر هو `services/cashpilot_ai_gateway`، وإصدار الحزمة والخدمة هو
  `0.1.0`.
- نجحت البوابات المحلية الأخيرة: `npm test` بعدد 123/123، و`lint`،
  و`typecheck`، و`build`، و`secret-scan`.
- نموذج المحادثة العامة واختيار الأدوات مثبتان في الخادم على
  `openai/gpt-oss-20b`، ونموذج الشرح المالي مثبت على
  `openai/gpt-oss-120b`. لا يستطيع العميل اختيار نموذج.
- نجح التحقق الحي من Models API باستخدام قيمة Secret Manager في الذاكرة:
  النموذجان `openai/gpt-oss-20b` و`openai/gpt-oss-120b` حالتهما ACTIVE.
- استُخدمت نسخة رسمية مؤقتة ومعزولة من `gcloud 578` مع اعتماد قصير العمر.
  نجحت معاينة الرفع الرسمية: 40 ملفًا/357,576 بايت/صفر ملف محظور، ثم حُذف
  جسر الاعتماد المؤقت وACL directory كاملًا.
- يوجد ملف خدمة محلي `.gcloudignore` يستبعد `node_modules` و`dist` والاختبارات
  والأدلة والتغطية والسجلات وملفات البيئة والأسرار، مع إبقاء ملفات الحزمة
  وTypeScript وESLint و`src` و`Dockerfile` و`scripts` ضمن مصدر البناء.

## 2. وجهة النشر المعتمدة وسجل إنشاء المرشح

| الحقل | القيمة أو الحالة الآمنة |
|---|---|
| المشروع | `cashpilot-ai-a6b49` |
| خدمة Cloud Run | `cashpilot-ai-gateway-staging` |
| المنطقة | `europe-west1` |
| أسلوب إنشاء المراجعة (تاريخي) | مراجعة مرشحة بلا حركة (`--no-traffic`) ثم ترويج مستقل |
| وسم المرشح | `groq-candidate` |
| المراجعة السابقة المخصصة للتراجع | `cashpilot-ai-gateway-staging-00002-sww` |
| اسم مراجعة المرشح | `cashpilot-ai-gateway-staging-00005-civ` |
| وقت إنشاء المرشح | `2026-08-14T10:55:10.505708Z` |
| رابط المرشح الموسوم | `https://groq-candidate---cashpilot-ai-gateway-staging-yfgt2ypuvq-ew.a.run.app` |
| تحويل الحركة | `00005-civ=100%`؛ الترويج نجح في 22.021s |

اختيرت `europe-west1` لاستمرار الخدمة القائمة في منطقتها الحالية وتجنب ترحيل
إقليمي غير لازم. تغيير المنطقة في هذا السبرنت سيضيف اختلافًا تشغيليًا وزمن
استجابة ومسار رجوع جديدًا بلا حاجة مثبتة.

## 3. إعدادات المرشح الآمنة

### إعدادات التطبيق غير السرية

| الإعداد | قيمة Staging المطلوبة |
|---|---|
| `FIREBASE_PROJECT_ID` | `cashpilot-ai-a6b49` |
| `CASH_PILOT_ENVIRONMENT` | `staging` |
| `CASH_PILOT_CLIENT_VERSION` | `1.0.0` |
| `CASH_PILOT_ALLOWED_ORIGINS` | `https://cashpilot-ai-a6b49.web.app`؛ يمنع `*` |
| `MODEL_DIAGNOSTICS_ENABLED` | `false` في المراجعة النهائية المرشحة |
| `CASH_PILOT_AI_GROQ_TOOL_SELECTION_ENABLED` | `false` |
| `PROVIDER_TIMEOUT_MS` | `20000` |
| `MAX_STREAM_MS` | `30000` |
| `MAX_AI_BODY_BYTES` | `32768` |
| `MAX_AI_REQUESTS_PER_MINUTE` | `20` مبدئيًا، ثم يراجع بالقياس |

- يجب ربط `GROQ_API_KEY` من Secret Manager كمرجع وقت التشغيل فقط. يمنع وضع
  قيمته في متغير عادي أو أمر محفوظ أو صورة الحاوية أو Flutter أو تقرير QA.
- حساب التشغيل المخصص هو
  `cashpilot-ai-gateway-staging@cashpilot-ai-a6b49.iam.gserviceaccount.com`؛
  يقرأ secret بمرجع Secret Manager ويستخدم ADC للتحقق. لا تسجل الوثيقة قيمة
  اعتماد أو ID token أو App Check token.
- تبقى تشخيصات المزود معطلة افتراضيًا. إن لزم اختبار تشخيصي، فيكون على مراجعة
  مؤقتة محمية بـFirebase Auth وApp Check، ثم تُنشأ مراجعة جديدة والتشخيص فيها
  معطل قبل أي حركة مستخدمين.
- `/health` لا يستدعي Groq، ويعرض فقط `serviceVersion` و`environment`
  و`supportedClientVersion` وحالة جاهزية آمنة مبنية على وجود الإعدادات.
- طلب Android بلا `Origin` مسموح عند نجاح المصادقة وApp Check، بينما طلبات
  المتصفح مقيدة بقائمة origins الدقيقة.

### حدود Cloud Run

- HTTPS فقط، مع مهلة منصة أعلى من حد البوابة البالغ 30 ثانية؛ القيمة المقترحة
  للمرشح 60 ثانية.
- القيم الفعلية المثبتة: 1 CPU، 512MiB، concurrency=80، timeout=60s،
  max-instances=1، وmin-instances=0/unset.
- يبقى الحد الأدنى للمثيلات على القيمة القائمة. لا يرفع إلى 1 إلا بعد قياس
  cold start وموافقة صريحة على التكلفة.
- يمكن أن يبقى الاستدعاء عامًا على مستوى Cloud Run لحاجة تطبيق الهاتف، لكن
  كل مسارات AI والتشخيص تبقى محمية داخل التطبيق بـFirebase Auth وApp Check.

## 4. تسلسل نشر المرشح بلا حركة

1. سجل وصف الخدمة وتوزيع الحركة الحاليين بصورة منقحة لا تحتوي أي اعتماد.
2. أعد تشغيل البوابات المحلية الخمس، ثم نفذ
   `npm run verify-groq-models` في بيئة خادم مخولة. يجب أن ينجح النموذجان قبل
   النشر، وتُحفظ IDs والحالات الآمنة فقط.
3. شغّل `gcloud meta list-files-for-upload` من مجلد الخدمة وتأكد أن الملفات
   المستبعدة لا تدخل حزمة Cloud Build.
4. انشر من مجلد الخدمة إلى `cashpilot-ai-gateway-staging` في
   `europe-west1` باستخدام `--no-traffic` ووسم `groq-candidate`. استخدم مرجع
   Secret Manager المعتمد من دون إظهار قيمته، ولا تغير IAM ضمنيًا.
5. اقرأ اسم المراجعة ووقت إنشائها ورابط الوسم من وصف Cloud Run، ثم حدّث حقول
   الانتظار أعلاه. لا تكتب أي قيمة اعتماد في الأدلة.
6. اختبر رابط الوسم فقط: `/health`، ورفض Auth/App Check غير الصالحين، ثم طلب
   Android مخول، وSSE عربي وإنجليزي، و`responseMode=json`، والإلغاء، و429 مع
   `Retry-After`، والسجلات الآمنة.
7. أبقِ الحركة الافتراضية كما هي حتى اكتمال القبول الحي وموافقة مالك المشروع.
   تحويل الحركة إجراء مستقل لاحق، وليس جزءًا من إنشاء المرشح.

قالب الأمر أدناه توثيقي ولا يجوز تشغيله قبل استبدال الحقول المنتظرة والتحقق
منها. لا يحتوي القالب قيمة سر أو اعتماد حساب؛ اسم حساب الخدمة معرّف تشغيلي فقط:

```text
gcloud run deploy cashpilot-ai-gateway-staging \
  --project cashpilot-ai-a6b49 \
  --region europe-west1 \
  --source . \
  --no-traffic \
  --tag groq-candidate \
  --service-account cashpilot-ai-gateway-staging@cashpilot-ai-a6b49.iam.gserviceaccount.com \
  --update-env-vars CASH_PILOT_ENVIRONMENT=staging,CASH_PILOT_CLIENT_VERSION=1.0.0,MODEL_DIAGNOSTICS_ENABLED=false,CASH_PILOT_AI_GROQ_TOOL_SELECTION_ENABLED=false \
  --update-secrets GROQ_API_KEY=cashpilot-groq-api-key:latest
```

يجب إضافة origin الدقيق وحدود الموارد والمثيلات بعد قراءتها واعتمادها، لا عبر
قيم مفترضة. لا يُستخدم `--set-env-vars` لتمرير أي سر.

## 5. سجل الإكمال الذي يُحدّث بعد التنفيذ

| الدليل | الحالة الحالية |
|---|---|
| Models API للنموذجين | PASS؛ كلاهما ACTIVE |
| قائمة ملفات Cloud Build | PASS؛ 40 ملفًا/357,576 بايت/صفر محظور |
| إنشاء المراجعة بلا حركة (تاريخي) | PASS؛ بدأت `00005-civ` بحالة Ready و0% |
| وقت النشر UTC | `2026-08-14T10:55:10.505708Z` |
| إعداد CPU/ذاكرة/concurrency/min/max الفعلي | 1/512MiB/80/0/1 |
| ربط Secret Manager | PASS؛ `cashpilot-groq-api-key:latest` بلا قيمة في الأدلة |
| Auth وApp Check على المرشح | PASS حي؛ ويشمل missing/invalid App Check مع valid Auth |
| العربية والإنجليزية وSSE | PASS حي؛ والإلغاء العام حي أيضًا |
| قرار تحويل الحركة | PASS؛ `00005-civ=100%`، health الثابت 331/106/92ms |

## 6. الرصد والتنبيهات المطلوبة

تتوفر الحقول الآمنة في السجلات: endpoint، app version، platform، model، status،
typed code، duration، TTFT، completion، retry وrate-limit. يمنع تسجيل prompt أو
response أو UID أو tokens أو key أو بيانات مالية.

قبل الإنتاج تُنشأ سياسات Cloud Monitoring لـCloud Run 5xx، Groq upstream
failures، ارتفاع رفض Auth/App Check، 429، request/stream timeout، p95 latency،
وفشل container startup. لم تُنشأ notification channels أو alert policies في
هذا السبرنت لغياب موافقة المالك؛ التعريف موثق هنا وفي blockers.

حدود البدء المقترحة، وتُراجع بعد جمع baseline أسبوع:

| الإشارة | شرط التنبيه المبدئي |
|---|---|
| Cloud Run 5xx | أكثر من 2% لمدة 5 دقائق مع 20 طلبًا على الأقل |
| Groq upstream failure | أكثر من 5 أحداث خلال 5 دقائق أو أكثر من 2% |
| Auth/App Check rejection | أكثر من 3 أضعاف baseline لمدة 10 دقائق |
| 429 | أكثر من 10% لمدة 5 دقائق؛ يفرّق limiter المحلي عن Groq upstream |
| request/stream timeout | أكثر من 1% لمدة 10 دقائق |
| p95 TTFC | أكثر من 2500ms لمدة 15 دقيقة على الطلبات الدافئة |
| container startup | أي startup failure؛ أو health غير Ready ثلاث مرات |
