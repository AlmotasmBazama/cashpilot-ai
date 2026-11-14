# تقرير الإغلاق النهائي لحذف الحساب

التاريخ: 2026-08-21  
الفرع: `codex/production-transformation`  
HEAD: `fd24526f3f21ba0e96ca73dcc4a69f5a11aed632`  
القرار: **Account Deletion Staging GO**، و**Android Release Candidate NO-GO لأسباب إصدار خارجية**.

## الخلاصة التنفيذية

أُغلق حاجب `providerUnavailable`. كان تنفيذ الخادم المستقل وحزمة
`services/cashpilot_account_deletion` موجودين، وكذلك خدمة Staging سابقة؛ لم
يُخترع API ثان. أصل العطل أن التطبيق المنشور سابقاً كان يمرر الحذف إلى مراجعة
Groq بهوية لا تملك Firestore data أو Auth-delete. سجلت تلك المراجعة 503 على
مساري الحذف، ثم طوى mapping القديم فشل Admin إلى `providerUnavailable`.

ثُبت الحد الصحيح كخدمة Cloud Run مستقلة، وأعيد نشر المصدر نفسه إلى:

- الخدمة: `cashpilot-account-deletion-staging`
- المنطقة: `europe-west1`
- المراجعة: `cashpilot-account-deletion-staging-00003-q4b`
- الرابط الثابت: `https://cashpilot-account-deletion-staging-yfgt2ypuvq-ew.a.run.app`

تعمل الخدمة بهوية مخصصة وبأقل IAM لازم، وتتحقق من Firebase Auth مع revocation
والجمهور، وApp Check، وإثبات الحذف، وتشتق الهدف الوحيد من principal المتحقق.
تستخدم recursive delete ثم تحققاً server-side من غياب الجذر والمجموعات الفرعية،
وتحذف Auth أخيراً فقط بعد إثبات السحابة.

أكمل Android حساباً متقطعاً وحساباً نظيفاً. كانت Cloud وDrift والإيصالات
وHive/AI/settings والصفوف الخلفية صفراً، حُذف Auth أخيراً، ولم تعد البيانات بعد
الشبكة وإعادة العمال وفتح التطبيق والانتظار 30 ثانية. بقي A وB بلا تغيير حتى
انتهاء إثبات العزل ثم أُزيلا كـ fixtures اصطناعية.

## السبب الجذري الدقيق

المراجعة `cashpilot-ai-gateway-staging-00005-civ` استخدمت الحساب
`cashpilot-ai-gateway-staging@cashpilot-ai-a6b49.iam.gserviceaccount.com`، الذي
كان يحمل فقط `roles/firebaseappcheck.tokenVerifier` و`roles/firebaseauth.viewer`.
Cloud Logging المقيد أظهر 503 واحدة على `/v1/account-deletion/recursive` واثنتين
على `/v1/account-deletion/auth`. الحساب لا يملك معاملة قفل Firestore،
`recursiveDelete`، أو حذف Auth. بعد نجاح التحقق، أول حد Admin في المسار العودي
هو قفل Firestore، لذلك فشل المسار قبل `cloudDeleted`، وحوّل الكود القديم الفشل
غير المتوقع إلى `providerUnavailable`.

إذن السبب ليس غياب route أو DNS أو App Check أو تبدل المستخدم؛ هو **تشغيل حذف
الحساب تحت هوية Groq غير المخولة، مع mapping قديم أخفى المرحلة الدقيقة**.

## المزود الموثوق وIAM

هوية الخدمة الصحيحة:
`cashpilot-deletion-staging@cashpilot-ai-a6b49.iam.gserviceaccount.com`.

الأدوار:

- `roles/datastore.user`
- `roles/firebaseappcheck.tokenVerifier`
- `projects/cashpilot-ai-a6b49/roles/cashpilotDeletionAuthOperator`

لم تُمنح Owner أو Editor ولم يُستخدم ملف مفتاح. Cloud Run عام على مستوى invoker
لوصول الهاتف فقط؛ داخل route تبقى Auth وApp Check والإثبات إلزامية. المشروع
المقيد هو `cashpilot-ai-a6b49` وقاعدة Firestore الصحيحة.

## السحابة والأمان

المخطط الصارم يقبل `operationId` و`targetOwnerScope` فقط؛ UID والمسارات
العشوائية مرفوضة. UID مشتق من ID token، والتزام owner scope يعاد اشتقاقه. قفل
`accountDeletionLocks/{SHA-256(uid)}` retained وopaque، لا يحوي UID خاماً ولا
بيانات مستخدم، ويمنع التعارض والإحياء.

حُذفت شجرة `users/{verifiedUid}` عودياً، بما فيها المجموعة التجريبية غير
المعروفة `futureContainers/root/children/deep`. تحقق الخادم بعد الحذف من غياب
الجذر وصفر collection IDs. جرد المصدر لم يجد بيانات مستخدم قابلة للاستعادة
خارج الجذر؛ القفل العالمي هو retention safety record وليس retry item يعيد
البيانات.

HTTP الحي أثبت الرفض المغلق لـ Auth وApp Check المفقودين/الخاطئين، ونوع المحتوى
والطريقة والحجم وJSON، ثم قبل طلب Android الصحيح. كل الأخطاء typed و`no-store`،
ولا تعكس استثناء Admin أو UID أو token.

## الحسابان المحجوران من التقرير السابق

عند بداية المهمة لم يعودا موجودين: exact Admin lookup أعاد 0، والتطبيق signed
out ولا يحمل continuation قابلة للاستئناف. لم يحدث manual delete أو bypass.
السجلات السابقة للخدمة المستقلة أظهرت مراحل protected completion، لذلك سُجلت
النتيجة **PASS_ALREADY_CLEAN** لا ادعاء استئناف غير ممكن. أنشأت المهمة C وD
للقبول الكامل، وانتهت كذلك بصفر حساب اصطناعي متبقٍ.

## نتائج التحقق النهائية

| البوابة | النتيجة |
|---|---|
| `flutter analyze --no-pub` | PASS؛ 0 issues |
| `flutter test --no-pub` | PASS؛ 1701/1701 |
| أدوات المستودع | PASS؛ 160/160 |
| Firestore rules emulator | PASS؛ 42/42 |
| Account-deletion emulator | PASS؛ 2/2 |
| اختبارات مزود الحذف | PASS؛ 31/31 |
| backend lint/typecheck/build/secret scan | PASS / PASS / PASS / PASS |
| `flutter build apk --debug --no-pub` | PASS؛ `app-debug.apk` |
| `flutter build web --no-pub` | PASS؛ `build/web`؛ تحذير font غير حاجب |
| HTTP/security acceptance | PASS |
| الحذف المتقطع C | PASS |
| الحذف النظيف D | PASS |
| Cloud/Drift/receipts/Hive live data | 0/0/0/0 |
| Auth deleted last | PASS |
| no resurrection | PASS؛ 30 ثانية بعد الشبكة/العمال/reopen |
| A/B unchanged | PASS قبل تنظيف fixtures |
| synthetic accounts remaining | 0 |

التشغيل الشامل الأول كشف أن ثلاثة اختبارات أدوات واختبار Flutter واحد ما زالت
تثبت قائمة مفاتيح Staging القديمة. حُدثت عقود الاختبار والحارس للمفتاح المنفصل
ثم أعيدت البوابات، وانتهت بالأعداد الخضراء أعلاه.

## ملفات المهمة التي عُدلت فعلياً

لا تشمل هذه القائمة مئات تغييرات worktree السابقة، ولا تدعي أن حزمة الخدمة
المستقلة الموجودة مسبقاً أُنشئت من الصفر:

1. `tool/account_deletion_provider_live_acceptance.cjs`
2. `tool/hive_owner_zero_probe.dart`
3. `tool/android_groq_staging_scenario.ps1`
4. `tool/run_android_groq_staging.test.cjs`
5. `test/features/ai_assistant/ai_environment_defaults_test.dart`
6. `docs/qa/account_deletion_provider/CLOUD_DELETION_PROVIDER_REPORT_AR.md`
7. `docs/qa/account_deletion_provider/DEPLOYMENT_CONFIG_AR.md`
8. `docs/qa/account_deletion_provider/SECURITY_TEST_MATRIX.csv`
9. `docs/qa/account_deletion_provider/LIVE_DELETION_ACCEPTANCE_AR.md`
10. `docs/qa/account_deletion_provider/DATA_ZERO_VERIFICATION.csv`
11. `docs/qa/account_deletion_provider/REMAINING_BLOCKERS.csv`
12. ملفات الأدلة المنقحة تحت `docs/qa/account_deletion_provider/evidence/`
13. `docs/qa/account_deletion_final/ACCOUNT_DELETION_FINAL_REPORT_AR.md`
14. `docs/qa/account_deletion_final/LIVE_ANDROID_ACCEPTANCE_AR.md`
15. `docs/qa/account_deletion_final/DATA_CLEANUP_VERIFICATION.csv`
16. `docs/qa/account_deletion_final/REMAINING_LIMITATIONS.csv`

المصدر المنشور موجود تحت `services/cashpilot_account_deletion/` ولم يُعدّل في
هذه المرحلة؛ طابقت ملفاته الأربعون بصمة المصدر المنشور. إعداد Staging الموجود
`config/groq_staging.json` كان يحتوي مفتاح الخدمة المنفصل واستُخدم للبناء الحي.

## القرار

**Account Deletion Staging: GO.** تحقق الحد السحابي، ترتيب Auth-last، الصفر،
العزل، والاستئناف الحي.

**Android Release Candidate: NO-GO حالياً.** هذا ليس حاجب حذف: Production لم
يُنشر عمداً، ومعرف التطبيق ما زال `com.example.cashpilot_ai`، ولا تزال signing
وSHA registrations وPlay Integrity/App Check release acceptance والاختبار على
جهاز فعلي مسؤوليات إصدار خارجية. يبقى غياب Production endpoint مغلقاً افتراضياً
ولا يجوز نسخه من Staging بلا موافقة نشر مستقلة.
