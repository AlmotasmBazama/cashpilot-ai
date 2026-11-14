# خط أساس شجرة العمل قبل توحيد الإصدار

تاريخ الالتقاط: `2026-08-22T00:02:00+02:00`.

## الهوية

- جذر المستودع وقت الالتقاط: `C:\Users\pixel\cashpilot_ai`.
- الفرع: `codex/production-transformation`.
- HEAD التاريخي: `fd24526f3f21ba0e96ca73dcc4a69f5a11aed632`.
- الوسم الموجود عند HEAD: `v0.9.0-feature-complete`.
- لا يوجد remote مضبوط، ولا توجد submodules.

## الأعداد الثابتة قبل أي staging

- مسارات tracked متغيرة: **255**.
- محذوفة: **1**.
- معاد تسميتها: **0**.
- staged: **0**.
- untracked: **994**.
- إجمالي إدخالات porcelain التفصيلية: **1,249**.
- إدخالات `git status --short` المطوية بحسب الأدلة: **542**.
- أسطر مضافة بحسب `git diff --numstat`: **42,977**.
- أسطر محذوفة بحسب `git diff --numstat`: **8,791**.
- ملفات binary في diff المتعقَّب: **0**.

## Git ونهايات الأسطر

- `core.autocrlf=true`.
- `core.eol` و`core.safecrlf` غير مضبوطين.
- لا يوجد `.gitattributes` في خط الأساس.
- `.gitignore` كان ملفًا tracked معدّلًا.
- Git LFS متاح، ولا توجد ملفات متعقَّبة به.
- فحص قاعدة كائنات Git أظهر ستة ملفات قمامة صغيرة باسم `tmp_obj_*`، بحجم إجمالي يقارب 505 KiB؛ لم يُنفّذ حذف أو pruning لأن ذلك ليس مطلوبًا لإنتاج خط الأساس.

## الأدلة

الأوامر المطلوبة ونتائجها الخام محفوظة في `docs/qa/release_baseline/evidence/before/`. النسخة الخارجية تحتوي أيضًا على `repository-history.bundle` صالح، ونسخة غير معدّلة من الأدلة السابقة لإنشاء هذا المجلد.

لم يُنفّذ قبل اكتمال النسخة الاحتياطية أي `reset` أو `clean` أو `restore` أو `stash` أو `rebase` أو `merge`.
