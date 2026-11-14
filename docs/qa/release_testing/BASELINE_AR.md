# خط أساس بوابة الاختبار والإصدار

التاريخ: 2026-08-13، المنطقة الزمنية Africa/Tripoli.

## المستودع

- الجذر: `<REPOSITORY_ROOT>`
- الفرع: `master`
- HEAD: `fd24526f3f21ba0e96ca73dcc4a69f5a11aed632`
- عدد إدخالات `git status --short` قبل إضافة مخرجات هذه الجولة: **368**.
- الشجرة متسخة ومشتركة. لم يُستخدم reset/clean/restore/stash/commit/push أو تبديل فرع.
- المخرجات الكاملة للأوامر الستة محفوظة تحت `docs/qa/release_testing/evidence/`.

## البيئة

- OS: Windows 11 Pro 64-bit، build `10.0.26200`.
- Flutter: `3.41.9` stable.
- Dart: `3.11.5`.
- Java CLI: `21.0.11`; Flutter Android toolchain يستخدم JDK 21.0.10.
- Node: `26.1.0`; npm: `11.13.0`.
- Android SDK: 36.1.0؛ build-tools 36.1.0.
- Android emulator: `emulator-5554`, `sdk_gphone64_x86_64`, Android 17 / API 37.
- لا يوجد جهاز Android فعلي متصل.
- Web targets: Chrome 151 وEdge 151.
- Windows desktop toolchain غير مكتمل بسبب غياب Visual Studio C++ workload؛ Windows ليس منصة الإصدار المختارة.

## التطبيق المثبت عند البداية

- foreground package: `com.example.cashpilot_ai/.MainActivity`.
- applicationId: `com.example.cashpilot_ai`.
- versionName: `1.0.0`.
- versionCode: `1`.
- minSdk: 24؛ targetSdk: 36.
- build mode: Debug قابل للتصحيح.

## Firebase وAI من المصدر الحالي

- Firebase project: `cashpilot-ai-a6b49`.
- options: `DefaultFirebaseOptions.currentPlatform`؛ Android وWeb مولدان.
- Android Debug App Check: `AndroidProvider.debug`.
- conversation preference الافتراضي: `auto`.
- Groq غير مهيأ افتراضيًا؛ general remote route يختار Firebase عند نجاح preflight.
- model العام الأولي: `gemini-3.6-flash`، backend Vertex/global.
- التسجيل الحالي لـApp Check يجب الحفاظ عليه؛ لا token أو secret مخزن في الأدلة.

## قدرات البناء والإصدار

- Android debug: متاح.
- Web: متاح؛ أصول Drift Web موجودة.
- release signing الحقيقي: غير متاح/غير معتمد؛ applicationId ما زال development ID.
- Play Integrity production acceptance: غير متاح.
- physical-device release acceptance: BLOCKED لعدم وجود جهاز فعلي.

## الخط الأساس المبلغ عنه المراد إعادة التحقق منه

- analyze: 0 issues.
- Flutter: 1203/1203.
- Android navigation integration: 1/1.
- Firebase emulator: 44/44.
- Gateway: 109/109 مع lint/typecheck/build/secret-scan.
- هذه القيم تاريخية عند بداية هذه الجولة ولا تصبح PASS حاليًا إلا بعد إعادة التشغيل.

## قيود السلامة

- لن تُمسح بيانات المحاكي إلا بسبب مبرر موثق.
- لن يُحذف App Check debug registration.
- لن تُحفظ UID أو owner scope أو tokens أو headers أو prompts/responses الخاصة أو سجلات مالية كاملة أو صور/مسارات إيصالات.
