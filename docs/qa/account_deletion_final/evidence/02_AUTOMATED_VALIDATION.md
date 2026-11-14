# نتائج البوابات المنزوعة الحساسية

| الأمر/المجموعة | النتيجة | الملاحظة |
|---|---|---|
| `flutter analyze --no-pub` | PASS | `No issues found!`؛ 99.8 ثانية |
| `flutter test --no-pub` | PASS | `1694/1694`؛ `All tests passed!`؛ خروج 0 |
| الحذف + نقل إثبات البوابة | PASS | 57 اختباراً |
| Gateway/Coordinator لاستئناف البدء | PASS | 18 اختباراً |
| `test:tools` المكافئ عبر Node المضمّن | PASS | 160/160؛ خروج 0 |
| `flutter build web --no-pub` | PASS | `Built build\web`؛ 134.1 ثانية |
| APK debug الحالي | CONSTRAINED PASS | Gradle نجح وAPK ثُبت بلا مسح بيانات؛ قيد ZipFS منع إثبات الأمر القياسي مستقلاً |
| Firestore emulator | NOT RUN | لا Firebase CLI ولا منافذ 8080/9099/4400 مستمعة |
| account deletion emulator | NOT RUN | يعتمد على Auth/Firestore emulator نفسه |
| Gateway gates | N/A | لا تغيير في Gateway |
| Dart format الكامل | FAIL | 6 ملفات سابقة خارج نطاق هذه المهمة؛ ملفات المهمة نفسها لم تظهر في القائمة |

الملفات الستة في بوابة التنسيق موثقة في التقرير الرئيسي. لا تحتوي هذه الأدلة على stdout مالي أو رسائل AI أو بيانات مصادقة.
