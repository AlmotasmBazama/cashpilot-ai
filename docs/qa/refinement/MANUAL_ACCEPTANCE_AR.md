# نتائج القبول اليدوي — جولة التنقيح الشاملة

التاريخ: 2026-08-13. الجهاز المتاح: `emulator-5554`، Android 17 / API 37. لم يتوفر جهاز Android فعلي. الحالات أدناه تخص ما نُفذ حيًا في هذه الجولة فقط؛ نجاح الاختبارات الآلية لا يُحوَّل إلى نجاح يدوي. لم تُسجل prompts أو responses أو tokens أو UIDs أو بيانات مالية في هذا الملف.

| # | الرحلة | الحالة | الدليل/القيد |
|---:|---|---|---|
| 1 | Cold start | PASS | APK debug العادي؛ `LaunchState=COLD`؛ 3120ms على المحاكي. |
| 2 | Warm return | PASS | عودة مع process حي؛ `LaunchState=HOT`؛ 103ms. ليست عينة warm process recreation. |
| 3 | Background/resume | PASS | Home ثم إعادة فتح MainActivity؛ نفس مسار hot return بلا crash. |
| 4 | Offline start | BLOCKED | لم يُنفذ بدء كامل للتطبيق والشبكة مقطوعة؛ تم اختبار انقطاع AI فقط. |
| 5 | Login | BLOCKED | teardown لاختبار التكامل أزال جلسة الجهاز؛ لم يُعد إنشاء مستخدم يدوي نهائي. |
| 6 | Logout | BLOCKED | لا جلسة مستخدم نهائية مهيأة. |
| 7 | Second-user login | BLOCKED | لم تُستخدم هويتان حيتان في هذه الجولة. |
| 8 | Temporary-auth behavior | BLOCKED | اختبار التكامل المركب توقف بسبب `deletionQuarantined`. |
| 9 | Create two accounts | BLOCKED | لم تُعد fixture مالية حية بعد teardown. |
| 10 | Create income | BLOCKED | مغطى آليًا؛ غير منفذ يدويًا في الجولة. |
| 11 | Create expense | BLOCKED | مغطى آليًا؛ غير منفذ يدويًا في الجولة. |
| 12 | Create pending transaction | BLOCKED | مغطى آليًا؛ غير منفذ يدويًا في الجولة. |
| 13 | Edit pending transaction | BLOCKED | الميزة الجديدة خضراء آليًا؛ يلزم fixture مالية حية. |
| 14 | Post pending transaction | BLOCKED | مغطى آليًا؛ غير منفذ يدويًا. |
| 15 | Cancel/reverse posted transaction | BLOCKED | مغطى آليًا؛ غير منفذ يدويًا. |
| 16 | Verify account balances | BLOCKED | لا fixture مالية نهائية. |
| 17 | Load/create more than 50 transactions | BLOCKED | تم التحقق بقاعدة اصطناعية آلية فقط. |
| 18 | Test multiple pages | BLOCKED | 275-row regression PASS؛ لا قبول يدوي حي. |
| 19 | Search later-page record | BLOCKED | regression آلي PASS؛ لا fixture حية. |
| 20 | Filter and sort | BLOCKED | regression آلي PASS؛ لا fixture حية. |
| 21 | Return from details/list state | BLOCKED | لم يُنفذ حيًا. |
| 22 | Same-currency transfer | BLOCKED | لا fixture مالية حية. |
| 23 | Cross-currency transfer | BLOCKED | لا fixture مالية/FX حية. |
| 24 | Missing-rate error | BLOCKED | مغطى آليًا؛ غير منفذ يدويًا. |
| 25 | Duplicate-tap prevention | BLOCKED | مغطى آليًا؛ غير منفذ يدويًا. |
| 26 | Cancel transfer | BLOCKED | مغطى آليًا؛ غير منفذ يدويًا. |
| 27 | Verify both transfer balances | BLOCKED | لا fixture مالية حية. |
| 28 | Create/edit/archive budget | BLOCKED | لم يُنفذ حيًا. |
| 29 | Verify budget progress | BLOCKED | القراءة المحدودة واختبارات الدقة آلية فقط. |
| 30 | Create goal | BLOCKED | لم يُنفذ حيًا. |
| 31 | Add contribution | BLOCKED | لم يُنفذ حيًا. |
| 32 | Pause/resume/archive goal | BLOCKED | لم يُنفذ حيًا. |
| 33 | Verify dashboard totals | BLOCKED | bounded/count regressions PASS؛ لا fixture حية نهائية. |
| 34 | Verify recent transactions | BLOCKED | مغطى آليًا فقط. |
| 35 | Verify budget and goal cards | BLOCKED | لم يُنفذ حيًا. |
| 36 | Verify monthly/yearly/category/cash-flow reports | BLOCKED | labels/recovery 3/3 PASS؛ لا قبول يدوي كامل. |
| 37 | Verify missing exchange-rate behavior | BLOCKED | مغطى آليًا فقط. |
| 38 | Local Arabic greeting | BLOCKED | مسار local خضراء آليًا؛ لم يُعد كخطوة يدوية في هذه الجولة. |
| 39 | Remote Arabic question | PASS | التطبيق المثبت اختار Firebase و`gemini-3.6-flash` واكتمل الطلب الحقيقي (~5.62s). |
| 40 | Remote English question | PASS | استجابة Firebase حقيقية اكتملت (~4.65s). |
| 41 | Offline failure | PASS | حجب شبكة package أظهر فشلًا typed قابلًا للمحاولة خلال زمن محدود. |
| 42 | Retry | PASS | بعد استعادة الشبكة اكتمل Firebase (~5.05s) بلا تكرار user turn. |
| 43 | Stop generation | BLOCKED | خضراء آليًا؛ لم تُنفذ يدويًا في الجولة. |
| 44 | Navigate away during streaming | BLOCKED | اختبار الجهاز deterministic يغطي navigation؛ لا قبول يدوي أثناء stream. |
| 45 | Start new conversation during streaming | BLOCKED | regression آلي PASS؛ لا قبول يدوي. |
| 46 | Long-conversation scrolling | BLOCKED | لم يُنفذ حيًا. |
| 47 | Reopen app from launcher | PASS | force-stop ثم launcher أعاد package الصحيح وواجهة التطبيق. |
| 48 | Another remote response after reopen | PASS | Firebase أكمل طلبًا جديدًا بعد إعادة الفتح (~6.86s). |
| 49 | Open receipt scanner | BLOCKED | لم تتوفر جلسة مستخدم/fixture نهائية بعد teardown. |
| 50 | Select synthetic receipt | BLOCKED | اختبار العامل والـwidget PASS؛ غير حي. |
| 51 | Verify scanner UI responsiveness | BLOCKED | isolate/cancel regressions PASS؛ لا قياس جهاز حي. |
| 52 | Cancel receipt | BLOCKED | cancel regression PASS؛ غير حي. |
| 53 | Retry receipt | BLOCKED | لم يُنفذ حيًا. |
| 54 | Verify draft behavior | BLOCKED | مغطى آليًا؛ غير حي. |
| 55 | Verify manual fallback | BLOCKED | لم يُنفذ حيًا. |
| 56 | Confirm extracted receipt transaction | BLOCKED | لا OCR/provider live acceptance في الجولة. |
| 57 | Change language | BLOCKED | لم يُنفذ على APK النهائي. |
| 58 | Change theme | BLOCKED | لم يُنفذ على APK النهائي. |
| 59 | Test Arabic RTL | BLOCKED | اختبارات widget خضراء؛ لا جولة جهاز كاملة. |
| 60 | Test text scaling | BLOCKED | لم يُنفذ حيًا. |
| 61 | Test small width | BLOCKED | Web 320×640 PASS، لكن خطوة Android المطلوبة لم تُنفذ يدويًا. |
| 62 | Test keyboard interaction | PASS | تم إدخال وإرسال أسئلة AI غير تحية عبر واجهة التطبيق الفعلية. |

## الخلاصة

- PASS: **10**
- FAIL: **0**
- BLOCKED: **52**
- NOT APPLICABLE: **0**

هذه الأرقام لا تعني أن 52 رحلة معطلة في المنتج؛ معظمها لم يُعد يدويًا بسبب إزالة جلسة/بيانات تطبيق الاختبار أثناء teardown وعدم إنشاء بيانات مالية حية جديدة. الاختبارات الآلية النهائية 1203/1203 تغطي كثيرًا منها، لكن بقيت الحالة اليدوية صريحة وغير مُضخمة.
