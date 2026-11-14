# تدقيق الأسرار والمواد المحلية

## النطاق

شمل الفحص ملفات Flutter وDart، إعدادات المشروع، أدوات الاختبار، خدمتي Cloud Run، الوثائق، والملفات untracked المرشحة للالتزام. استُبعدت الملفات الثنائية من قراءة النص، لكنها صُنفت بالمسار والنوع والحجم والـhash في جرد النسخة الاحتياطية.

## النتيجة النهائية

- مفاتيح Groq الفعلية: **0**.
- ترويسات private key: **0**.
- حقول service-account `private_key`: **0**.
- Google refresh tokens: **0**.
- JWTs طويلة: **0**.
- client/signing secrets: **0**.
- شغّل كل من `services/cashpilot_ai_gateway` و`services/cashpilot_account_deletion` أمر `npm run secret-scan` بنجاح في الدفعات المركزة ثم في fresh worktree.
- فحص كل الملفات tracked في fresh worktree أعاد صفرًا لأنماط Groq keys وprivate keys وGoogle tokens وAWS keys وJWTs وclient secrets.
- مسارات credential-risk المتعقبة: **0**، وحالة fresh بعد التثبيت والبناء: صفر diff/staged/untracked.

## الاستثناءات الضيقة المراجعة

- الفحص الأولي وجد نمط `Bearer` في ملفي اختبار. الفحص النهائي لكل المصدر الملتزم وجد **6 أسطر** في خمسة ملفات اختبار تحت الخدمات وFlutter وأداة التقييم؛ كل القيم موسومة صراحةً `synthetic`/`private`/`token-for-owner` أو credential fixture غير قابلة للاستخدام، ولا يظهر النمط في runtime أو التقارير.
- عناوين البريد الموجودة في الملفات المرشحة محصورة في `example.com` و`example.invalid` و`example.test` وحسابات خدمة Firebase الخاصة بالمشروع. لم يظهر نطاق بريد استهلاكي.
- مطابقات الهاتف الليبي محصورة في fixtures اختبارية/false positives، وليست بيانات مستخدم.
- `android/app/google-services.json` إعداد عميل Firebase عام مرتبط بالحزمة الحالية؛ لا يحتوي service-account أو private key، وهو مطلوب للبناء الحالي.

## المواد المحلية

- توجد أسرار تشغيل محلية داخل `.secrets/` وملفات dart-define محلية، وكلها ignored ولم تدخل النسخة المصدرية أو Git.
- `android/local.properties` machine-local وignored.
- حُجرت 58 لقطة/ملف XML لواجهة QA محليًا لأن بعضها قد يعرض هوية مختبِر. لن تُلتزم، وستحميها قواعد ignore ضيقة خاصة بمجلد UI redesign فقط.
- رُصدت **29** إحالة قديمة إلى جذر جهاز محلي في تقارير المنتج وQA النصية عبر الفحصين الأولي وفحص staged. استُبدلت بالرمز `<REPOSITORY_ROOT>`، مع بقاء الأصل غير المعدل في النسخة الخارجية.

لا توجد allowlist عامة. الاستثناءات مبنية على مسارات وأنماط اختبار محددة. انتهى فحص كل دفعة staged وفحص fresh worktree إلى صفر أسرار فعلية.

**القرار: PASS — All repository secret scans: PASS.**
