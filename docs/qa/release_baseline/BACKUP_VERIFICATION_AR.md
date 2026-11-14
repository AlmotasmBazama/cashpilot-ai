# تحقق النسخة الاحتياطية قبل التوحيد

## النتيجة

**PASS** — أُنشئت نسخة خارج المستودع قبل أي تعديل أو staging وتحققت سلامة فتحها وفكها ومطابقة عينات ممثلة.

## الأرشيف الأساسي

- مجلد التشغيل: `C:\Users\pixel\cashpilot_ai_release_backups\pre_consolidation_20260822T000112+0200`.
- الأرشيف: `C:\Users\pixel\cashpilot_ai_release_backups\pre_consolidation_20260822T000112+0200\cashpilot_ai_pre_consolidation_source.zip`.
- الحجم: **15,640,658 bytes**.
- SHA-256: `f687bf6bf7b7f10a7bb5c007e71367eb026a3956234d973ed58ad0fb4eb7cd50`.
- إدخالات ZIP: **2,126**.
- الملفات المصدرية المشمولة: **1,614**.
- مسار فك التحقق: `C:\Users\pixel\cashpilot_ai_release_backups\pre_consolidation_20260822T000112+0200\verification_extract`.

يتضمن الأرشيف manifest لكل ملف مع SHA-256، بيانات الفرع وHEAD وحالة Git، وقاعدة التاريخ في `_baseline/repository-history.bundle`. مرّ `git bundle verify` بنجاح.

## عينات المطابقة بعد الفك

طابقت hashes النسخة العاملة عند الالتقاط لكل من:

- `pubspec.yaml` و`lib/main.dart`.
- `test/widget_test.dart`.
- `config/groq_staging.json`.
- lockfile خدمتي Groq وحذف الحساب.
- تقرير حذف الحساب النهائي.
- إعداد Firebase العام للعميل Android.

## الحجر والاستبعادات

- حُفظ **60** ملفًا، بحجم **40,365,720 bytes**، في `quarantine_sensitive_and_nonrelease/` مع manifest وhashes مستقلة.
- تشمل مواد الحجر 58 لقطة/تفريغ UI محلية قد تعرض بيانات مختبِر، وأرشيفي gateway قديمين. لم تدخل هذه المواد الأرشيف المصدري ولا خطة الالتزام.
- استُبعد من المصدر الأساسي **83** ملف cache/build مثبتة القابلية للتوليد تحت أداة Android Unicode IME.
- بقي تقرير build HTML واحد داخل النسخة الأساسية احتياطًا، لكنه مصنف build output ولن يدخل Git.
- استُبعدت الملفات المحلية الحساسة المعروفة: `.secrets/`، ملفات dart-define المحلية، و`android/local.properties`.

لم تُحذف النسخة الاحتياطية أو مجلد الحجر.
