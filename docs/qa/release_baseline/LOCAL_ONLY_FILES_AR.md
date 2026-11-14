# الملفات المحلية المستثناة

## أسرار وإعدادات جهاز موجودة محليًا

- `.secrets/` ومحتوياتها.
- `.dart-define.appcheck.json`.
- `.dart-define.groq-staging.local.json`.
- `android/local.properties`.

هذه المسارات ignored أصلًا، ولم تدخل archive المصدر أو staging. لا يسجل هذا التقرير قيمها.

## أدلة QA محلية

- `docs/qa/ui_redesign/evidence/**/*.png`.
- `docs/qa/ui_redesign/evidence/**/*.xml`.
- `docs/qa/ui_redesign/screenshots/`.

عددها في خط الأساس: **58**. تبقى محفوظة محليًا وخارجياً في quarantine ولا تدخل Git لأنها قد تعرض بيانات حساب مختبِر أو حالة جهاز. تبقى ملفات text/CSV/Markdown sanitized في Git.

## نواتج قابلة للتوليد

- `tool/android_unicode_ime/.gradle/`.
- `tool/android_unicode_ime/build/`.
- `tool/android_unicode_ime/app/build/`.

عددها في الجرد: **84**. يجوز حذفها فقط بعد إثبات النسخة الاحتياطية؛ يمكن إعادة توليدها من ملفات Gradle ومصدر Java الملتزم.

## أرشيفات غير إصدارية

- `cashpilot_ai_gateway.zip`.
- `cashpilot_ai_gateway_repaired.zip`.

حُفظا في quarantine مع SHA-256، ولا يمثلان مصدرًا موثوقًا لأن أحدهما يجمع `node_modules/dist` والآخر نسخة مصدر قديمة. يجوز حذف النسختين العاملتين بعد التحقق، ولا يُحذف الحجر الخارجي.
