# إعادة الإنتاج النهائية من worktree جديد

التاريخ: `2026-08-22`، المنطقة: `Africa/Tripoli`.

## الهوية والنظافة

- commit المصدر المختبَر: `fb7301660f56812b8ecfb953a6f47558a6acf070`.
- العنوان: `test(release): make committed-build smoke self-contained`.
- المسار المنفصل: `C:\Users\pixel\cashpilot_ai_release_final_reproduction_fb7301660f56`.
- checkout كان detached ونظيفًا عند الإنشاء. لم تُنسخ إليه `.dart_tool` أو `build` أو `node_modules` أو قواعد محلية أو بيانات محاكي أو credentials؛ جُلبت الاعتماديات من lockfiles فقط.
- `git status --short` كان فارغًا قبل التحقق وبعده؛ نواتج البناء والاعتماديات بقيت ضمن المسارات المتجاهلة المعتمدة.

## الاعتماديات

نجح `flutter pub get`. ونجح `npm ci` للجذر، ولخدمة البوابة، ولمزوّد حذف الحساب، ولأداة تقييم Groq من lockfiles الملتزمة. لم يحدث `npm audit fix` أو تغيير لأي dependency/lockfile.

تعذر تنزيل SQLite Android artifacts مؤقتًا بسبب انقطاع اتصال GitHub من بيئة التنفيذ. جرى جلب الملفات نفسها من عناوين الإصدار الثابتة، والتحقق من hashes المنشورة، ووضعها في cache داخل `.dart_tool` فقط؛ لم يدخل أي ملف منها Git ولم يتغير المصدر.

## البوابات المنفذة

| الأمر/البوابة | النتيجة |
|---|---|
| `flutter analyze --no-pub` | PASS؛ `No issues found`؛ 21.2 s |
| `flutter test --no-pub -r expanded` | PASS؛ **1701/1701**؛ 1 min 12 s |
| `flutter build apk --debug --no-pub` | PASS؛ 63.1 s |
| `flutter build web --no-pub` | PASS؛ 68.9 s |
| `npm.cmd run test:tools` | PASS؛ **162/162** |
| Groq evaluation | PASS؛ **16/16** |
| Gateway tests | PASS؛ **133/133** |
| Gateway lint/typecheck/build/secret-scan | PASS / PASS / PASS / PASS |
| Account-deletion provider tests | PASS؛ **31/31** |
| Account-deletion lint/typecheck/build/secret-scan | PASS / PASS / PASS / PASS |
| Firestore Auth/Rules emulator | PASS؛ **42/42** |
| Account-deletion emulator | PASS؛ **2/2** |

محاكيات Firebase استخدمت المشروع المحلي `demo-cashpilot-ai`؛ لم تُستخدم حسابات أو بيانات إنتاج. لا توجد failures أو analyzer issues.

## مخرجات البناء

- APK الأمر المطلوب حرفيًا:
  - `C:\Users\pixel\cashpilot_ai_release_final_reproduction_fb7301660f56\build\app\outputs\flutter-apk\app-debug-default-baseline.apk`
  - 182,351,567 bytes
  - SHA-256 `3423f8292208bcd9d29f10c4715109f59311b33de40b42d7f97130f625b18f58`
- Web: **50** ملفًا، **45,941,956** bytes.
- تحذيرات غير قاتلة: رسائل Android deprecated/unchecked من dependencies، وتحذير Web wasm dry-run عن CupertinoIcons؛ البناءان اكتملَا بنجاح.

## نسخة قبول الطفرات

البناء العادي أعلاه يحافظ على القيم الآمنة الملتزمة `CASH_PILOT_AI_UPDATE_DRAFTS_ENABLED=false` و`CASH_PILOT_AI_ARCHIVE_DRAFTS_ENABLED=false`، ولذلك يرفض update/delete افتراضيًا. لإكمال Gate F دون تعديل المصدر بُني APK ثانٍ من **نفس commit النظيف** باستخدام الملف الملتزم `config/groq_staging.json`:

`flutter build apk --debug --no-pub --dart-define-from-file=config/groq_staging.json`

النتيجة: PASS خلال 110.6 s؛ المسار `C:\Users\pixel\cashpilot_ai_release_final_reproduction_fb7301660f56\build\app\outputs\flutter-apk\app-debug.apk`، الحجم 182,351,567 bytes، SHA-256 `694826a899f219983f93288554c9695d05eaa86ed3f1cb2e6129d4f0d90174b7`. هذه نسخة قبول staging وليست Android RC.

**Gate E — Fresh Reproduction: PASS** للـcommit `fb7301660f56812b8ecfb953a6f47558a6acf070`.
