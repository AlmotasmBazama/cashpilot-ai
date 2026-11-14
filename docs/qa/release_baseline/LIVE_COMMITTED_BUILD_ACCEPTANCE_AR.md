# قبول Android الحي من build ملتزم

التاريخ: `2026-08-22`. الجهاز: Pixel 6 emulator، `emulator-5554`. commit التشغيل: `fb7301660f56812b8ecfb953a6f47558a6acf070`.

## سلامة البيئة

- `flutter devices` و`adb devices` أثبتا الجهاز الحقيقي المستخدم.
- نافذة ANR كانت من `com.google.android.apps.wellbeing`، version `1.43.912539612 (839927)`. أُغلقت ثم عُمِل force-stop لهذه الحزمة فقط.
- لم تُعطّل Digital Wellbeing. فحص التنظيف: الحزمة enabled، ليست في قائمة disabled، و`dumpsys window` لا يحتوي ANR.
- DNS المحاكي `10.0.2.3` كان يتوقف عن الرد. أضيف DNAT مؤقت ومحدد لـTCP/UDP 53 نحو `8.8.8.8` أثناء القبول فقط. أُزيلت القاعدتان بالترتيب العكسي، وأصبح OUTPUT فارغًا عدا policy، ثم عاد `adbd` non-root.

## artifact والهوية

- APK القبول بُني في fresh worktree من commit أعلاه مع `--dart-define-from-file=config/groq_staging.json` الملتزم.
- المسار: `C:\Users\pixel\cashpilot_ai_release_final_reproduction_fb7301660f56\build\app\outputs\flutter-apk\app-debug.apk`.
- الحجم: 182,351,567 bytes.
- SHA-256: `694826a899f219983f93288554c9695d05eaa86ed3f1cb2e6129d4f0d90174b7`.
- `aapt`: `com.example.cashpilot_ai`، `1.0.0+1`، min 24، target 36.
- التثبيت نجح، وحزمة CashPilot واحدة فقط كانت مثبتة. hash `base.apk` المسحوب طابق artifact.

## المصادقة وعدم الاعتماد على الحالة السابقة

أنشأ harness مستخدمين اصطناعيين فريدين A وB من المسار المعتمد، ببيانات اعتماد في الذاكرة فقط. لم تُكتب credentials أو UIDs أو tokens في Git أو التقرير. نجح الدخول عبر التطبيق الحقيقي، وأثبتت اختبارات harness حالات no-prior-auth وexisting-auth وonboarding وlogin وdialog وsynthetic-create-failure وcleanup وforce-stop/reopen. لم يحدث bypass للمصادقة أو owner scope أو App Check.

## سيناريو المعاملات

1. أُنشئ `CashRelease` برصيد افتتاحي 10000 LYD.
2. أُنشئ `BankRelease` برصيد 0.
3. أُنشئ مصروف يدوي posted بقيمة 30 LYD من CashRelease.
4. الدليل بعده: صافي 9970، delta -30، حسابان، معاملتان؛ الأثر مرة واحدة.
5. `how are u` أكمل directConversation المحلي: message delta=2 وduplicateResponse=false ومن دون استدعاء gateway.
6. `اشرح لي مفهوم التضخم بطريقة بسيطة` أكمل الرد العربي. Cloud Logging الآمن أثبت revision `cashpilot-ai-gateway-staging-00005-civ`، alias `general-primary`، model `openai/gpt-oss-20b`، HTTP 200، 772 ms، retries=0، status completed. Settings أثبت Firebase text fallback disabled.
7. draft دخل 100 LYD أُلغي من زر `إلغاء`؛ بقي صافي 9970/معاملتان.
8. draft راتب 100 LYD إلى BankRelease أُكمل ثم أُكد صراحة؛ ظهر نجاح durable وأصبح صافي 10070/ثلاث معاملات.
9. مسودة غامضة استهدفت opening balance ولم تُؤكد؛ أُلغيت بلا أثر. الصيغة المقيدة `from 100 LYD to 120 LYD` استهدفت BankRelease بدقة.
10. update 100→120 أُكد: صافي 10090/3. Undo أُكد: صافي 10070/3 والدخل 100.
11. محاولة delete بصيغة تحتوي subject hint زائد أعادت `No matching transaction` بلا أثر. الصيغة المقيدة `Delete last 100 LYD income` استهدفت الدخل الصحيح.
12. delete أُكد: صافي 9970/معاملتان. Undo أُكد: صافي 10070/3 والدخل 100.

النتيجة المالية النهائية: CashRelease 9970، BankRelease 100، الإجمالي 10070، ثلاث معاملات. لا duplicate mutation ولا replay ولا نجاح قبل durable write.

## Settings ودورة الحياة

- الصفوف المثبتة: remote Groq، general/financial gateway-managed models، local parser، receipt Firebase، text fallback disabled، gateway available، auth ready، App Check verified.
- الاختبار الحي انتقل من `testing` إلى `available`.
- background/resume: PID بقي `29939` والحالة 10070/3.
- force-stop/reopen: PID القديم `29939` اختفى، والجديد `31632`؛ عادت جلسة المالك والحالة 10070/3 دون تكرار.

## التنظيف

- حذف profile وFirebase Auth للمستخدمين A وB: `userA=true` و`userB=true` و`complete=true`.
- logout داخل التطبيق قبل الحذف رجع `signedOut=false`. لم يُستخدم `pm clear` لأن ذلك قد يمس حالة محلية أوسع من المستخدمين الاصطناعيين. بعد الحذف البعيد أُوقفت عملية CashPilot؛ بقيت السجلات المحلية owner-scoped لمالك لم يعد موجودًا ولا يمكن لمستخدم آخر تبنيها.
- أزيلت ملفات APK المؤقتة المسحوبة وUI dumps، ومُسح logcat، وأزيل DNS DNAT، وأعيد adbd non-root.
- App Check registrations القائمة لم تُحذف، ولم تُحذف الحزمة أو تُغير إعدادات cloud.

**Gate F — Live Committed Build: PASS مع استثناء logout المحلي محسوب بدقة، والتنظيف البعيد مكتمل.**
