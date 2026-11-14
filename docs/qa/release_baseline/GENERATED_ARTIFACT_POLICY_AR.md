# سياسة المصدر المولّد ونواتج البناء

## ما يبقى في Git

- ملفات Drift وjson_serializable ذات الامتداد `*.g.dart` عندما يكون الأصل المقابل ملتزمًا وكان المشروع يتعقب الناتج تاريخيًا.
- `lib/l10n/app_localizations*.dart` لأن المشروع يتعقب ناتج `flutter gen-l10n`; ستثبت fresh reproduction أن التوليد لا يصنع فرقًا غير مفسر.
- Flutter plugin registrants وملفات `generated_plugins.cmake` المتعقبة؛ تغيرها ناتج عن lockfile/dependency حقيقي وتُراجع بعد `flutter pub get`.
- lockfiles لـ Flutter وNode لأنها تثبت إعادة الإنتاج.
- `web/sqlite3.wasm` و`web/drift_worker.js` أصول runtime مطلوبة لنسخة الويب، وليسا build output عابرًا.
- `.gitattributes` تضبط ملفات Dart وregistrants النصية و`web/drift_worker.js` على LF، وتعرّف `web/sqlite3.wasm` كملف binary. أضيفت بعد أن كشف fresh snapshot اختلاف CRLF في مقارنة نص حرفية وفي SHA-256 للـworker؛ لا تغيّر سلوك المنتج.

## ما لا يدخل Git

- `build/app/` و`build/web/` وأي APK/AAB محلي.
- `node_modules/` و`dist/` لكل خدمة وأداة.
- `.dart_tool/` وGradle caches والتغطية والسجلات.
- `tool/android_unicode_ime/.gradle/` و`tool/android_unicode_ime/build/` و`tool/android_unicode_ime/app/build/`.
- أرشيفا gateway القديمان في جذر المشروع.
- لقطات UI وملفات hierarchy XML المحلية.

## Android Unicode IME

المطلوب للإصدار التجريبي هو سبعة ملفات مصدر/تعريف بناء فقط: ملفا Gradle، settings، manifest، مصدرا Java، وXML تعريف input method. صُنفت **84** قطعة داخله cache/build output، إضافة إلى أرشيفي gateway، ليصبح إجمالي build/cache/archive المستبعد من commits **86** ملفًا. أضيفت قواعد ignore ضيقة للأدلة القابلة للتوليد.

لم يُحذف مصدر مولّد متعقَّب. يتحقق fresh worktree من `flutter gen-l10n` ومن عدم ظهور diff متعقَّب غير مفسر بعد جلب الاعتماديات والتوليد.
