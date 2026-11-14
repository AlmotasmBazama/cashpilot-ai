# خطة توحيد commits

## قرار البنية

خط الأساس التاريخي `v0.9.0-feature-complete` يسبق تغييرات متشابكة في Drift وDI وrouter وlocalization وعقود AI وواجهات الميزات. تقسيم ملفات Flutter حسب الشاشة أو الميزة سيخلق commits وسطية لا تُحلل أو تُبنى من checkout مستقل. لذلك يجمع commit المنتج runtime Flutter في وحدة انتقال واحدة موثقة، بينما تبقى الخدمات، الاختبارات، الأدوات، والوثائق مجموعات منفصلة قابلة للتحقق.

## commits المحلية المنفذة

1. `8d8ba212eec69718cccad7ecb7f312093cf33149` — `feat(gateway): harden the Groq staging service` — **82** مسارًا؛ مرّت 133/133 من الاختبارات وlint/typecheck/build/secret-scan.
2. `2441bb99090942ffc916eec2902e57ce08b7483c` — `feat(deletion): add trusted recursive account deletion provider` — **40** مسارًا؛ مرّت 31/31 من الاختبارات وlint/typecheck/build/secret-scan.
3. `5a9bf788d5ebe9d2a910dcf4bba952a7504c13bb` — `feat(app): consolidate the production Flutter baseline` — **431** مسارًا؛ مصدر التطبيق مع 43 اختبار توافق tracked ومساعدي اختبار جديدين ليثبت checkout مستقل. مرّ analyzer بلا ملاحظات و578/578 اختبارًا وبناء Web في snapshot مطابق للـindex.
4. `4d119f2d86cf18fb5a7161407629180c3ad6025f` — `test(app): consolidate characterization and reproducibility coverage` — **144** مسارًا: 143 مسار اختبار متبقيًا و`.gitattributes` جديدة لضبط LF للأصول التي تتحقق منها الاختبارات بالـhash أو النص الحرفي.
5. `8539fea4f9102214b2c7e0c1ac4d58cff4edb5b5` — `build(tooling): add reproducible release and emulator harnesses` — **79** مسارًا؛ مرّت 160/160 من اختبارات أدوات الجذر و16/16 من اختبارات تقييم Groq.
6. `4dd1603db7f4c38a3b83ea3d45b64715ff2fd48a` — `docs: align product and deployment documentation` — **36** مسارًا بعد تدقيق المحتوى وتعميم مسار جهاز واحد.
7. `ebeeb68094ff7258e798e456beccde7346d67592` — `docs(qa): consolidate sanitized acceptance evidence` — **294** مسارًا نصيًا/CSV فقط؛ لا صور أو XML أو archives، وبعد تعميم كل مسارات الجهاز المكتشفة.
8. `27d7ad636bb9bc5baad9c822ef6fd51e217471cb` — `docs(release): record pre-consolidation audit baseline` — **18** مسارًا؛ جرد ما قبل الدمج، تحقق النسخة، سياسة المولدات، المصفوفة الأولية، وأدلة الحالة الخام.

الأعداد الأصلية في الجرد ذي 1,249 مسارًا كانت 386 لمسارات Flutter و188 للاختبارات. نُقلت 45 من مجموعة الاختبار إلى commit التطبيق لأن snapshot المصدر وحده كشف 89 خطأ API في الاختبارات القديمة ثم احتاج مساعدي الاختبار؛ أبقى ذلك commit التطبيق قابلًا للتحليل والاختبار من checkout مستقل. أضيفت `.gitattributes` أثناء التحقق وليست من المسارات الأصلية. ملفات تقارير release baseline المنشأة في هذه المهمة توثّق في commit تدقيق مستقل بعد إعادة الإنتاج.

## الملفات المختلطة

وُسمت الملفات المركزية مثل `pubspec.*` و`firebase.json` وrouter وقاعدة البيانات وARB وREADME كمختلطة للمراجعة المحافظة. تُراجع diffs كاملة. إذا كانت كل كتلها داخل نفس انتقال المنتج تُلتزم كملف كامل بعد `git diff --cached --check`؛ لا يُجزأ ملف لمجرد تصغير commit عندما يؤدي ذلك إلى checkout غير صالح. لا يوجد hunk مشترك بين خدمتي Cloud Run ومصدر Flutter.

المصفوفة النهائية لكل مسار في `COMMIT_PATH_MATRIX.csv` وُلّدت من `git show`: **1,124** مسارًا ملتزمًا و**144** مسارًا local-only، بلا صف مجهول. يضاف commit إغلاق الأدلة بعد نتائج fresh reproduction؛ لا يحمل تغيير runtime. لم يُستخدم staging قبل اكتمال الجرد وتدقيق السرية والحجر.
