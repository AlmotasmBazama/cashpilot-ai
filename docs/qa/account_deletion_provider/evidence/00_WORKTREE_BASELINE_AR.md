# دليل حماية الـ worktree

نُفذت أوامر الالتقاط المطلوبة قبل التغيير:

- `git branch --show-current` → `codex/production-transformation`
- `git rev-parse HEAD` → `fd24526f3f21ba0e96ca73dcc4a69f5a11aed632`
- `git status --short`
- `git diff --stat`
- `git diff --name-only`
- `git ls-files --others --exclude-standard`

كان الـ worktree متسخاً بكثافة قبل هذه المهمة، tracked وuntracked، وحُفظ كما هو.
لم يُنفذ reset أو clean أو restore أو stash أو commit أو push أو تبديل فرع.

إعادة العد المنقحة قرب النهاية أعطت 542 مدخلة status، و255 ملفاً في tracked
diff، و988 ملفاً untracked. هذه أرقام worktree الكامل وليست تغييرات المهمة؛
لا يجوز نسبها إلى إصلاح الحذف. بقي الفرع وHEAD بلا تغيير.

تحذيرات Git عن LF/CRLF تخص حالة الملفات الحالية ولم يُستخدم أمر كتابة جماعي
أو تطبيع line endings.

