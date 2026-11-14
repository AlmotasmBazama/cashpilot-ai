# التغييرات التقنية

## حدود البيانات والـstate

- أبقيت الكتابة المالية داخل `TransactionsRepositoryImpl` وFinance Engine؛ الواجهة لا تعدل الرصيد مباشرة.
- أضيفت invalidation صريحة للتبعيات المخزنة التي يستهلكها Dashboard/Reports.
- حُصّن canonical category seeding ضد التزامن من دون إزالة owner scoping.

## الاستجابة والأداء

- حافظ Dashboard على window+recent bounded query مع count دقيق.
- حافظ transaction history على page-size 50 وquery-level filtering/sorting.
- احتفظ receipt pipeline بالعامل المعزول الموجود، وأضاف stage/cancel contract وlate-result fencing.

## Android وApp Check

- أضيف helper debug آمن: يسترجع SDK secret داخل الذاكرة، يجرب exchange الرسمي أولًا، يسجل فقط عند الرفض، ثم يعيد التحقق.
- helper لا يطبع secret/token ولا يحذف registration. التثبيت النهائي أعاد `exchange=accepted` و`preserved=true`.
- أُصلح اختبار navigation device ليقرأ router الحقيقي من ProviderScope. اختبار device deterministic صار 1/1 PASS.
- اختبار live routed المركب بقي محجوبًا بحالة `deletionQuarantined`; لم يُخف الفشل ولم يُحسب نجاحًا.

## Web

- build/web صالح، أصول Drift موجودة، onboarding/welcome عُرضا تفاعليًا على viewport واسع و320×640 بلا console errors.
- لم يُفعّل Web remote AI إنتاجيًا؛ reCAPTCHA Enterprise/App Check/Auth origins بقيت blockers خارجية.

## التوثيق

- README وFirebase وreceipts وAI tool registry/permission policy صارت متوافقة مع التنفيذ الحالي.

## حصيلة التقنية

تم إغلاق **3 مشكلات تقنية مباشرة**: سباق category seed، helper App Check الآمن/idempotent، وعيب GoRouter في اختبار الجهاز. Pagination صُنّف Verified لا Fix، وlive integration quarantine بقي Blocked.
