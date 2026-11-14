# خط أساس جولة التحسين الشامل

تاريخ القياس: 2026-08-13، المنطقة الزمنية Africa/Tripoli.

## المستودع والشجرة

- الجذر: `<REPOSITORY_ROOT>`.
- الفرع: `master`.
- HEAD: `fd24526f3f21ba0e96ca73dcc4a69f5a11aed632`.
- جرى حفظ حالة Git قبل أي تعديل خاص بهذه الجولة في مجلد `evidence`.
- كانت الشجرة متسخة مسبقًا بكثافة: 364 مدخل status، منها 198 tracked و166 untracked. لم تُنظف أو تُستبدل أو تُخزّن مؤقتًا.

## البيئة

- Flutter: 3.41.9 stable.
- Dart: 3.11.5.
- DevTools: 2.54.2.
- Java: 21.0.11.
- Node.js: 26.1.0.
- npm: 11.13.0 عبر `npm.cmd`؛ استدعاء PowerShell المباشر محجوب بسياسة النظام فقط.
- Android emulator: `emulator-5554`، Android 17 / API 37.
- Chrome 151 وEdge 151 متاحان.
- نقص مكوّنات Visual Studio C++ يخص Windows desktop فقط، وليس بوابتي Android/Web المطلوبتين.

## التطبيق المثبت

- المنصة الفعلية: Android، وليست Chrome.
- applicationId: `com.example.cashpilot_ai`.
- لا توجد حزمة CashPilot ثانية مثبتة؛ الحزمة الوحيدة third-party هي الحزمة أعلاه.
- versionName/versionCode: `1.0.0` / `1`، ويطابق `pubspec.yaml` (`1.0.0+1`).
- minSdk الفعلي من الحزمة المثبتة: 24؛ targetSdk: 36.
- الحزمة Debuggable.
- SHA-256 للحزمة المثبتة يطابق `build/app/outputs/flutter-apk/app-debug.apk` الحالي؛ لا يوجد APK قديم منفصل يجري تشغيله.

## Firebase وAI وApp Check

- Firebase Core يهيئ التطبيق عبر `DefaultFirebaseOptions.currentPlatform`.
- المشروع المولد: `cashpilot-ai-a6b49`.
- تفضيل المحادثة: `auto`.
- `localParserOnly` باقٍ للمحلل الحتمي، ولا يمثل مزود المحادثة العامة.
- Groq غير مهيأ افتراضيًا؛ المزود المختار فعليًا: Firebase.
- النموذج الفعلي: `gemini-3.6-flash`، backend Vertex AI/location global.
- Android debug يستخدم `AndroidProvider.debug`؛ release يستخدم Play Integrity.
- أداة التسجيل لم تطبع السر. أعادت إنشاء تسجيل debug الحالي وأبقته قائمًا (`registration=created`, `preserved=true`). لم يُحذف التسجيل ولم تُمسح بيانات التطبيق.
- الطلبان البعيدان الحيان المنفذان في هذه الجولة عبر واجهة التطبيق (العربي المحدد حرفيًا ثم إنجليزي اصطناعي) أنهيا markers الآمنة: preference=auto، selectedProvider=firebase، model=gemini-3.6-flash، request=started، request=completed، ولم يسجلا request=failed. اكتمل الطلب العربي في نحو 5.5 ثوانٍ.
- أُدخل النص العربي عبر clipboard الرسمي للمحاكي ثم زر Send الحقيقي؛ تحقق الاختبار من التطابق والطول فقط. لا نص سؤال أو رد محفوظ في الأدلة.

## بوابات baseline

- `flutter analyze --no-pub`: PASS، صفر issues، 270.9 ثانية.
- `flutter test --no-pub -r compact`: PASS، 1189/1189، صفر failed، قرابة 97 ثانية.
- تحذير Drift debug عن أكثر من `AppDatabase` في بعض الاختبارات غير فاشل ومعروف.

## قياسات البداية

- Android cold process launch الحالي: 3930 ms عبر `am start -W -S`؛ القياس السابق الموثق clean-install كان 4933 ms، فلا يُعامل الفرق كتحسين سببي قبل تعديل.
- Dashboard fixture (10,020 صفًا، warm-up ثم خمس عينات): full mapping median 432008 µs؛ bounded window 20 rows مع total=10020 median 2336 µs.
- Transaction fixture الموثق الحالي (10,000 صف): full mapping median 209797 µs؛ أول صفحة 50 صفًا median 1738 µs.
- Budget fixture الموثق الحالي (10,020 صفًا): broad mapping median 179125 µs؛ contributing window 20 صفًا median 1100 µs.
- زمن route usable عبر UIAutomator يُسجل كحد علوي فقط لأن dump نفسه بطيء؛ لا يُقدّم كقياس frame دقيق.

## اختلافات الوثائق المكتشفة

- `docs/firebase_setup.md` ما زال يقول إن Web غير مهيأ، بينما Web FirebaseOptions وmapping وأصول Drift موجودة الآن.
- `docs/receipt_scanning.md` يربط debug المحلي بعدم اختيار Firebase، بينما المصدر الحالي يفصل محلل الأوامر الحتمي عن المحادثة/قدرة receipt البعيدة.
- `docs/ai_tool_registry.md` و`docs/ai_tool_permission_policy.md` يصفان غياب dataset owner-scoped وdurable command store كحد إنتاجي؛ المصدر الحالي يحتوي owner-scoped Drift وdurable action ledger. تبقى أعلام التنفيذ المالي معطلة افتراضيًا، لكن التعليل الوثائقي قديم.

هذه وثيقة baseline وليست حكم إنتاج. التوقيع release، applicationId النهائي، Play Integrity، جهاز فعلي، Web App Check، وقبول Web التفاعلي تبقى خارج الإثبات الحالي.
