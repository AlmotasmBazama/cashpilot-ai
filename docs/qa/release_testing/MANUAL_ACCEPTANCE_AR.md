# نتائج القبول اليدوي اليومية — Android Debug

التاريخ: 2026-08-13. التطبيق: 1.0.0+1 / `com.example.cashpilot_ai`. البيانات المطلوبة صناعية فقط.

الحالة الصريحة: لم تُنفّذ رحلة User A اليدوية الكاملة. نجاح اختبارات integration لا يُسجّل كنجاح يدوي. شوهدت الخطوتان 1 و7 فعليًا على APK العادي؛ بقية الخطوات `NOT EXECUTED`، لا `BLOCKED` بسبب الوقت.

| # | المجال | الخطوة | الحالة | الدليل/ملاحظة |
|---:|---|---|---|---|
| 1 | Startup and Auth | Clean launch | PASS | Cold launch وصل إلى واجهة التطبيق دون crash. |
| 2 | Startup and Auth | Complete onboarding | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 3 | Startup and Auth | Register/login | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 4 | Startup and Auth | Complete profile | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 5 | Startup and Auth | Open Dashboard | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 6 | Startup and Auth | Background/resume | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 7 | Startup and Auth | Force-stop/reopen | PASS | فُرض إيقاف الحزمة ثم فُتحت من launcher؛ MainActivity عادت top-resumed بلا fatal logs. |
| 8 | Accounts | Create Cash account | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 9 | Accounts | Create Bank account | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 10 | Accounts | Create USD account | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 11 | Accounts | Edit account metadata | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 12 | Accounts | Open account details | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 13 | Transactions | Create posted income | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 14 | Transactions | Create posted expense | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 15 | Transactions | Create pending expense | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 16 | Transactions | Edit pending amount | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 17 | Transactions | Edit pending category | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 18 | Transactions | Confirm pending remains balance-neutral | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 19 | Transactions | Change pending to posted | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 20 | Transactions | Confirm balance effect once | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 21 | Transactions | Change posted to pending | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 22 | Transactions | Confirm reversal once | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 23 | Transactions | Repost | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 24 | Transactions | Search | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 25 | Transactions | Filter | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 26 | Transactions | Sort | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 27 | Transactions | Scroll beyond first page | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 28 | Transactions | Open later-page record | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 29 | Transactions | Return and verify state | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 30 | Transfers | Same-currency transfer | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 31 | Transfers | Confirm two account balances | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 32 | Transfers | Cross-currency transfer | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 33 | Transfers | Missing-rate validation | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 34 | Transfers | Duplicate-tap prevention | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 35 | Transfers | Cancel posted transfer | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 36 | Transfers | Confirm both reversals | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 37 | Budgets | Create monthly budget | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 38 | Budgets | Verify progress | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 39 | Budgets | Edit threshold | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 40 | Budgets | Archive | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 41 | Budgets | Restore | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 42 | Goals | Create goal | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 43 | Goals | Add contribution | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 44 | Goals | Verify progress | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 45 | Goals | Pause | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 46 | Goals | Resume | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 47 | Reports | Open monthly report | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 48 | Reports | Open yearly report | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 49 | Reports | Open category report | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 50 | Reports | Open cash flow | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 51 | Reports | Compare totals to Dashboard | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 52 | AI | Send Arabic local greeting | NOT EXECUTED | توجد تغطية integration مستقلة؛ لا تُحوّل إلى manual PASS. |
| 53 | AI | Send Arabic remote prompt | NOT EXECUTED | توجد تغطية integration مستقلة؛ لا تُحوّل إلى manual PASS. |
| 54 | AI | Send English remote prompt | NOT EXECUTED | توجد تغطية integration مستقلة؛ لا تُحوّل إلى manual PASS. |
| 55 | AI | Disconnect network | NOT EXECUTED | توجد تغطية integration مستقلة؛ لا تُحوّل إلى manual PASS. |
| 56 | AI | Verify typed error | NOT EXECUTED | توجد تغطية integration مستقلة؛ لا تُحوّل إلى manual PASS. |
| 57 | AI | Retry | NOT EXECUTED | توجد تغطية integration مستقلة؛ لا تُحوّل إلى manual PASS. |
| 58 | AI | Stop generation | NOT EXECUTED | توجد تغطية integration مستقلة؛ لا تُحوّل إلى manual PASS. |
| 59 | AI | Navigate away during stream | NOT EXECUTED | توجد تغطية integration مستقلة؛ لا تُحوّل إلى manual PASS. |
| 60 | AI | Start new conversation during stream | NOT EXECUTED | توجد تغطية integration مستقلة؛ لا تُحوّل إلى manual PASS. |
| 61 | AI | Force-stop/reopen | NOT EXECUTED | توجد تغطية integration مستقلة؛ لا تُحوّل إلى manual PASS. |
| 62 | AI | Send another remote prompt | NOT EXECUTED | توجد تغطية integration مستقلة؛ لا تُحوّل إلى manual PASS. |
| 63 | Receipt | Select synthetic receipt | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 64 | Receipt | Verify responsive preparation | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 65 | Receipt | Execute remote extraction | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 66 | Receipt | Edit draft | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 67 | Receipt | Test duplicate receipt | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 68 | Receipt | Confirm once | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 69 | Receipt | Verify one transaction | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 70 | Receipt | Test manual fallback after failure | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 71 | Settings and User Switch | Change language | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 72 | Settings and User Switch | Change theme | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 73 | Settings and User Switch | Change base currency | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 74 | Settings and User Switch | Logout | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 75 | Settings and User Switch | Login as User B | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 76 | Settings and User Switch | Verify User A data is absent | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 77 | Settings and User Switch | Open AI and verify correct new-user state | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 78 | Settings and User Switch | Logout and return to User A | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |
| 79 | Settings and User Switch | Verify correct User A state | NOT EXECUTED | لم تُنفذ يدويًا على User A في هذه الجولة. |

## الملخص

- PASS يدوي: 2
- FAIL يدوي: 0
- BLOCKED: 0
- NOT EXECUTED: 77
- قرار الرحلة اليومية: غير مكتملة، ولذلك Gate C = NO.
