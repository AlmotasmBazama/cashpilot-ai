# خطة معالجة P0/P1 لتطبيق CashPilot

## الهدف والقيود

الهدف إغلاق كل P0/P1 مؤكد وغير محجوب، بالحد الأدنى من التغيير وباختبار انحدار سابق للإصلاح كلما أمكن. العمل يحافظ على الـdirty worktree الموجود؛ لا branch أو stash أو commit أو push أو deploy أو reset أو restore أو clean أو حذف لمسارات غير متعقبة. لا بيانات حقيقية ولا أسرار ولا UID خام. جميع أعلام Financial AI تبقى off.

## ترتيب التنفيذ

1. **Phase 0 — الجرد والتصنيف (مكتمل):** تحقق 70/70، baseline، خريطة 12 سببًا، status CSV، وتصنيف live/blocked.
2. **Phase 1 — تبديل A→B (مكتمل محليًا):** AI tool context، policy/health reload، receipt capture، consent، defaults، وكل state/proof/session متأخر. بوابة التكامل: 113/113 والمحلّل بلا أخطاء؛ التحقق الحي الموسوم في CSV ما زال معلقًا.
3. **Phase 2 — الحذف الموحّد (أُعيد فتحه):** نجحت بوابة العملية الواحدة، لكن مراجعة تكامل لاحقة أثبتت أن fence محلي للعملية لا يمنع جهازًا ثانيًا من إعادة الكتابة سحابيًا. يجري إضافة deletion lock خادمي خارج شجرة المستخدم وفرضه في Firestore Rules قبل اعتماد الخروج.
4. **Phase 3 — ledger والحسابات (متوقف مؤقتًا):** لا يبدأ تعديل المنتج حتى إغلاق إعادة فتح Phase 2؛ اكتمل فقط جرد read-only لمسارات الرصيد.
5. **Phase 4 — التحويلات:** exactly two rows، scoped unique group، Decimal FX invariant، atomic status/reverse/cancel، وidempotency.
6. **Phase 5 — confirmation/reconciliation:** proof one-time كامل الربط، fingerprint كامل، وعدم blind retry أو success غير متحقق.
7. **Phase 6 — AI/Groq:** fact registry دقيق، منع الأرقام/ادعاءات التنفيذ، context allowlist، authority/routing، وعدم fallback بعد output.
8. **Phase 7 — DB health/guards وsync privacy:** كل العلاقات المادية، INSERT/UPDATE guards، owner scope بدل UID خام، retention/tombstone/outbox/consent.
9. **Phase 8 — receipts/memory/privacy:** aggregate ذري، guard-on confirmation، retention journal، scoped keys/consent، FX/splits.
10. **Phase 9 — Gateway وإغلاق P1 المتبقية:** test/lint/typecheck/build/secret-scan ثم Firestore emulator، وبعدها P1 reporting/backup/category وغيرها حسب الاعتماد.

## دورة كل دفعة

- الدفعة القصوى نحو ثلاثة IDs تشترك في root واحد.
- ثبّت failure أو gap في test واضح واحفظ evidence sanitized.
- طبّق أصغر تعديل؛ لا refactor تجميلي.
- شغّل focused test ثم الاختبارات المرتبطة.
- شغّل `flutter analyze --no-pub` بعد كل phase.
- حدّث status CSV، السجل، وقائمة الملفات فورًا.
- التقط `git status --short` بعد كل phase للتأكد من عدم لمس عمل المستخدم غير المرتبط.

## بوابات التحقق

- بعد P0: focused suites لكل owner/deletion/finance/AI ثم full Flutter test.
- النهاية المحلية: `flutter analyze --no-pub`، `flutter test --no-pub -r expanded`، Android debug APK، Web build.
- Gateway: `npm.cmd test`، lint، typecheck، build، secret-scan، وproduction dependency audit.
- Firestore: emulator suite عندما تكون البيئة قابلة للتشغيل، مع تمييز deployed parity كـlive.
- لا تتغير بوابات Financial AI/staging/production إلى GO بسبب نجاح محلي فقط.

## معايير التوقف

- أي scope mismatch أو partial financial state يفشل مغلقًا ولا يستمر إلى mutation.
- أي live prerequisite غائب يُسجل `Fixed Pending Live Verification` أو `Blocked` وفق الدليل، لا Pass.
- P2/P3 cosmetic مؤجلة حتى لا يبقى P0/P1 غير محجوب.
