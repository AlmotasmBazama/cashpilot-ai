# فجوات Release Candidate والإنتاج

## القرار المختصر

نسخة Android debug الحالية مناسبة لاستخدام داخلي يومي محدود على المحاكي، وFirebase AI مناسب للمحادثة العامة اليومية على Android المهيأ. لا توجد أدلة كافية لتسمية البناء Release Candidate أو Production.

## فجوات مانعة لـRC

1. **هوية Android النهائية:** `com.example.cashpilot_ai` ما زال معرف تطوير. يجب اختيار applicationId النهائي وتنفيذ migration/registration واعية.
2. **توقيع release:** يلزم keystore إنتاجي محمي وسياسة دوران/نسخ احتياطي وCI secrets؛ لم يُنشأ أو يُطلب في هذه الجولة.
3. **Firebase fingerprints:** تسجيل SHA-1/SHA-256 للبناء النهائي وتحديث client configuration بعد حسم الهوية والتوقيع.
4. **App Check إنتاجي:** Play Integrity للتطبيق النهائي ثم validation قبل enforcement. نجاح debug provider لا يثبت production attestation.
5. **جهاز فعلي:** لا توجد physical-device acceptance على Android release؛ المحاكي لا يغطي الكاميرا/IME/thermal/storage upgrades/Play Integrity.
6. **اختبار التكامل الحي:** `ai_navigation_live_regression_test` ما زال 0/1 بسبب `OwnerScopeException: deletionQuarantined` في fixture المركب. يلزم fixture synthetic clean لا bypass.
7. **قبول يدوي مالي:** 52 من 62 خطوة بقيت BLOCKED في جولة التنقيح بسبب teardown للجلسة وعدم إعادة بيانات مالية حية.

## فجوات Web

1. إنشاء/ربط reCAPTCHA Enterprise site key لتطبيق Web في Firebase App Check.
2. ضبط authorized domains وOAuth redirects وorigins الدقيقة للبيئات المنشورة.
3. تفعيل واختبار gateway CORS على HTTPS origins النهائية.
4. قبول login/database/remote AI/error-recovery في browser حقيقي بعد الإعداد.
5. سياسات caching/versioning للأصول قبل إصدار فعلي.

## فجوات AI

1. الاعتماد الخارجي على Firebase/Vertex/model/quota يبقى جزءًا من التشغيل اليومي.
2. لا يوجد live receipt analysis acceptance على كاميرا/معرض جهاز فعلي.
3. Groq غير مفعّل؛ لا URL/secret/deployment acceptance، وهذا ليس عيبًا ما دام auto يختار Firebase.
4. financial execution يبقى disabled افتراضيًا، ويجب ألا يُفعل قبل قبول مستقل للصلاحيات والتأكيد.

## فجوات الجودة اليدوية

- Arabic RTL الكامل، text scale، screen reader، IME حقيقي، theme change، long-chat scrolling، stop/navigation/new-conversation أثناء live stream.
- ترقية secure storage وSQLite من إصدارات متجر حقيقية.
- airplane/offline startup الكامل بدل حجب network لطلب AI فقط.

## بوابة مقترحة قبل RC

- release config نهائي + signed app bundle.
- `flutter analyze` وfull tests وemulators/gateway كلها خضراء على commit نظيف معروف.
- deterministic live integration خضراء بلا quarantine bypass.
- 62-step physical-device acceptance بنتيجة بلا FAIL، والـBLOCKED محصور في عناصر غير مطلوبة للنطاق.
- Web live acceptance أو استبعاده صراحة من RC.
- secret scan وartifact inventory وrollback plan.

## حكم الإنتاج

**غير موصى به حاليًا.** السبب إعدادات الإصدار الخارجية والقبول الفيزيائي/Web، لا فشل في الاختبارات المحلية الحالية.
