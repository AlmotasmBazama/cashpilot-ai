# تقرير المعالجة السريعة لعيوب P0

التاريخ: 2026-08-11

## النتيجة التنفيذية

- تمت مراجعة `10` عيوب P0 ضمن المجموعات الخمس المحددة فقط: `OF-002` إلى `OF-009`، و`AI-001`، و`AI-002`.
- الحالة النهائية محليًا: `5 Fixed` و`5 Fixed Pending Live Verification` و`0 Blocked` و`0` إصلاحات كودية متبقية داخل النطاق.
- عولجت أيضًا `10` عيوب مرافقة فقط لأنها تشارك الجذر نفسه وتلزم لإغلاق التدفق: `OF-012` و`OF-032` و`OF-033` و`GW-01` و`GW-02` و`GW-03` و`AI-006` و`AI-007` و`AI-008` و`AI-013`. لا تدخل هذه في عدّ P0.
- لم تتم مراجعة `OF-001` أو أي عيب آخر خارج المجموعات الخمس.
- لم تُفعّل أي قدرة تنفيذ مالي بالذكاء الاصطناعي، ولم تُغيّر أعلام التنفيذ المؤكد أو التحويل أو المسودات أو التنقل أو الخطط متعددة الخطوات أو تحقق مجموعة البيانات المحلية.

## سلامة شجرة العمل

سُجلت الحالة قبل أول تعديل وحُفظت تغييرات المستخدم كما هي:

- الفرع: `master`
- HEAD: `fd24526f3f21ba0e96ca73dcc4a69f5a11aed632`
- إدخالات `git status --short`: `305`
- فرق الملفات المتتبعة عند البداية: `167 files changed, 33620 insertions(+), 5050 deletions(-)`
- لم يُستخدم reset أو clean أو restore أو checkout أو stash أو commit أو push.

## العيوب P0

| المجموعة | المعرّفات | الحالة |
|---|---|---|
| تبديل الحساب | `OF-009` | Fixed |
| تبديل الحساب | `AI-001`, `AI-002` | Fixed Pending Live Verification |
| حذف الحساب | `OF-006`, `OF-007`, `OF-008` | Fixed Pending Live Verification |
| Finance Engine | `OF-002`, `OF-003` | Fixed |
| التحويلات | `OF-004`, `OF-005` | Fixed |

لا توجد عيوب P0 محجوبة كوديًا في النطاق. تفاصيل كل عيب، ملفات سطح الإصلاح، والاختبار المرتبط موجودة في `P0_FAST_STATUS.csv`.

## الأسباب الجذرية والإصلاحات

1. **تبديل الحساب:** كانت بعض العمليات والقيم المعاد تحميلها تعتمد على المالك الحالي بعد بدء الطلب. رُبطت الطلبات والأدوات والذاكرة والإيصالات بسياسة مالك وجيل جلسة ثابتين، وأضيفت فحوص قبل وبعد كل `await`، ومنع startup reconciliation حتى تصبح سياسة وصحة المالك الحالي جاهزتين وآمنتين.
2. **حذف الحساب:** كان بالإمكان إعادة حل مستخدم Auth أو قبول هوية/lease ناقصة لاحقًا، مع غياب fence دائم لكل الكتّاب. أصبح الحذف مسارًا واحدًا بهوية وسياق عملية ثابتين، ومقارنة كاملة للـlease، وحجر دائم للمالك، وتصريف للكتّاب، وحذف سحابي تكراري مثبت، ثم حذف محلي، ثم Auth أخيرًا.
3. **Finance Engine:** كان الرصيد الافتتاحي والحقول المحمية قابلين للتجاوز عند حدود المستودع. أصبح فتح الحساب صفريًا ثم قيدًا posted واحدًا ذريًا، وتُرفض أي محاولة لتغيير الرصيد أو العملة أو النوع أو وقت الإنشاء بخطأ typed ومن دون تغيير جزئي.
4. **التحويلات:** لم تكن علاقة المبلغ/السعر ولا هوية `transferGroupId` وشكل الزوج محمية بالكامل. أصبح التحقق Decimal دقيقًا قبل أي أثر، والزوج ذريًا ومقيدًا بمالك وبصمة payload، مع إعادة idempotent ومصالحة restart ورفض الطرف الثالث أو الطرف المنفرد أو التصادم عبر المالكين.
5. **Groq safety:** كان ممكناً تمرير رقم غير مسند أو ادعاء تنفيذ أو سياق مالي زائد. أضيف grounding دقيق بالأرقام النصية وprovenance، وسياسة مركزية تمنع claims وتؤخر البث حتى التحقق، وallowlist صريح لكل tool. طلبات المال واختيار الأدوات ترسل الرسالة الحالية فقط، من دون history أو compact memory.

## اختبارات الانحدار الجديدة أو المشددة

أضيفت `7` حالات اختبار جديدة:

- logout أثناء بث AI يسقط الأجزاء المتأخرة ويمسح الحالة.
- نتيجة إيصال تصل بعد A→B تُهمل ولا تُحفظ.
- حذف lease بلا `ownerScopeValue` يفشل قبل أي mutation.
- حذف lease بلا `authSessionGeneration` يفشل قبل أي mutation.
- أرقام مالية مختلقة بالعربية والإنجليزية تُرفض على العميل.
- نص المزوّد لا يثبت نجاحًا قبل التأكيد أو بعد فشل محلي أو لمستخدم آخر.
- طلب Groq المالي يحذف history وcompact memory ولا يرسل إلا السؤال الحالي.

وشُددت `3` حالات قائمة: بوابة reconciliation أثناء تحميل سياسة B، رفض OF-003 الذري بدل التجاهل الصامت، وsnapshot الحقول المحظورة `UID/owner/token/database/file/confirmation/history/payee/note/receipt`.

## نتائج الاختبارات المركزة

| النطاق | النتيجة |
|---|---|
| تبديل الحساب والـAI والإيصال، 12 ملفًا، `--concurrency=1` | `76/76` ناجحة |
| الحذف النهائي: lease/order/switch/logout/double/fence/restart/architecture | `101/101` ناجحة |
| حذف/Sync/AI fence إضافي | `119/119` ناجحة |
| Finance Engine والحسابات والتحويلات والإيصال وAI parity | `187/187` ناجحة |
| Group 5 Flutter: grounding/claims/context/routing/reconciliation/flags | `66/66` ناجحة |
| Gateway | `109/109` ناجحة |

حدث في محاولة مبكرة متوازية تعارض نسخ `sqlite3.dll` على Windows، ثم أُعيدت المجموعة نفسها تسلسليًا ونجحت؛ لا يُعد ذلك فشل assertion نهائيًا.

## التحقق النهائي

- `flutter analyze --no-pub`: exit `0` — `No issues found`.
- `flutter test --no-pub -r compact`: exit `1` — `1074` ناجحة و`1` فاشلة.
- الفشل الوحيد المؤكد: `test/features/data_deletion/account_deletion_secure_storage_architecture_test.dart:20`، الاختبار `secure-storage platform requirements are committed`. يتوقع النص الحرفي `minSdk = 23` بينما `android/app/build.gradle.kts:52` يحتوي `minSdk = flutter.minSdkVersion`.
- لم يُعدّل إعداد Android لأن المنصة خارج نطاق هذا sprint بنص التكليف.
- Gateway: `npm test`, `npm run lint`, `npm run typecheck`, `npm run build`, و`npm run secret-scan` كلها exit `0`.
- لم تُنفذ Android/Web builds.
- لم تُنفذ اختبارات جهاز حقيقي أو Firebase staging أو App Check أو Groq live، ولا تُسجل كناجحة.

## الملفات التي عُدلت في هذه الجولة بالضبط

1. `lib/features/accounts/data/datasources/local/accounts_local_data_source.dart`
2. `lib/features/accounts/domain/failures/account_failure_codes.dart`
3. `lib/features/ai_assistant/application/providers/ai_durable_action_providers.dart`
4. `lib/features/ai_assistant/data/gateway/groq_ai_agent_model_gateway.dart`
5. `lib/features/data_deletion/data/datasources/account_deletion_auth_data_source.dart`
6. `test/features/accounts/accounts_financial_integrity_test.dart`
7. `test/features/ai_assistant/ai_owner_scope_epoch_test.dart`
8. `test/features/ai_assistant/phase1_owner_transition_regression_test.dart`
9. `test/features/ai_assistant/ai_response_grounding_test.dart`
10. `test/features/ai_assistant/ai_provider_response_safety_test.dart`
11. `test/features/ai_assistant/groq_ai_agent_model_gateway_test.dart`
12. `test/features/data_deletion/account_deletion_confirmation_lease_tamper_test.dart`
13. `test/features/receipts/receipt_owner_scope_isolation_test.dart`
14. `docs/qa/remediation/P0_FAST_STATUS.csv`
15. `docs/qa/remediation/P0_FAST_REMEDIATION_AR.md`

لم تُعدّل ملفات gateway في هذه الجولة؛ كانت موجودة ضمن شجرة العمل المتغيرة مسبقًا، ولذلك شُغلت كل بواباتها النهائية. يسجل CSV ملفات سطح الإصلاح الكامل لكل defect، مع فصلها عن قائمة التعديلات المنسوبة لهذه الجولة.

## ما تبقى من تحقق P0

- `AI-001`: تبديل A→B وlogout أثناء طلب/بث Firebase وGroq حقيقيين، مع إثبات عدم خروج بيانات B أو payload متأخر.
- `AI-002`: كاميرا/معرض وتحليل إيصال على جهاز حقيقي مع التبديل عند capture/upload/response، وإثبات عدم بقاء صورة أو draft لـA في B.
- `OF-006`: تداخل مستخدمين فعليين في Firebase Auth staging.
- `OF-007`: قواعد منشورة وجهازان مع offline/reconnect لإثبات عدم resurrection.
- `OF-008`: حد Firebase Auth/App Check الحقيقي للـconfirmation lease.

هذه ليست إصلاحات كودية مفتوحة، بل تحقق حي مطلوب قبل أي قرار إصدار.

## قرارات التفعيل والإصدار

- **Financial AI:** يبقى معطّلًا. `DO NOT ENABLE`.
- **Staging:** `NO-GO` كمرشح إصدار. يُسمح فقط ببيئة معزولة لتنفيذ اختبارات التحقق الحي المذكورة.
- **Production:** `NO-GO`. لا توجد مطالبة بالجاهزية الإنتاجية.

أسباب القرار: خمس حالات P0 ما زالت بانتظار تحقق حي، والفحص الكامل يحتوي فشل platform architecture واحد، ولم تُنفذ مصفوفة Firebase/App Check/Groq/device الحية.
