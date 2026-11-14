# 1. تقرير التدقيق الكامل لتطبيق CashPilot AI

تدقيق غير هدّام للتطبيق، الذكاء الاصطناعي، السلامة المالية، عزل المالك، الخصوصية، بوابة Groq، قواعد Firestore، البناء، والاختبارات. يغطي هذا التقرير جميع العيوب التي لوحظت ضمن النطاق والبيئة المنفّذين، ولا يدّعي اكتشاف كل عيب ممكن.

## 2. تاريخ الاختبار

- التاريخ المحلي: 2026-08-09، المنطقة الزمنية `Africa/Tripoli` (`UTC+02:00`).
- نقطة البداية المسجلة: `2026-08-09T23:13:41.376+02:00`.

## 3. Executive Summary

نجح التحليل الساكن وكل assertions الآلية ذات العدّ المؤكد: **604 حالات اختبار مميزة** (517 Flutter + 32 Gateway + 39 Firestore + 16 Groq evaluation)، مع **0 failed assertions** و**0 skipped**. وباحتساب إعادة تشغيل المجموعات المركزة نُفّذ **1,254 test-case invocation على الأقل** ذات عدّ ظاهر. نجح بناء Web وAndroid debug، بينما حُجب Windows بسبب غياب Visual Studio C++ وحُجب iOS على Windows.

هذه النجاحات لا تسمح بالإصدار. ثُبتت مسارات مصدر حتمية تسمح بحذف حساب مالي مع مراجع، إدخال/تعديل الرصيد خارج الدفتر، تحويل غير متسق وتكرار أثر مجموعة تحويل، خلط صلاحيات/بيانات AI عند تبديل المستخدم، حذف Firebase Auth للمستخدم الخطأ في سباق، وإعادة رفع بيانات بعد “الحذف الكامل”. كما أن بوابة Groq تقبل أرقامًا مالية غير مدعومة وادعاءات تنفيذ وهمية وسياقًا ماليًا عامًا أكثر من اللازم. مسار الإيصالات يعاني من عيوب ترتيب وحراسة ورضا خصوصية وذرّية.

**الحكم:** Financial AI = **لا**؛ staging = **غير موصى به**؛ production = **مرفوض** حتى إغلاق P0/P1 وإعادة القبول في staging معزول.

## 4. حالة المستودع والـ commit والفرع

- الجذر: `<REPOSITORY_ROOT>`.
- الفرع: `master`.
- commit: `fd24526f3f21ba0e96ca73dcc4a69f5a11aed632`.
- الإصدار: `1.0.0+1`؛ Dart SDK constraint: `^3.11.5`.
- كان المستودع dirty قبل التدقيق: 242 مدخل porcelain موسعًا؛ 90 ملفًا tracked معدّلًا و152 ملفًا untracked؛ `19,364 insertions / 3,556 deletions` في tracked diff.
- لم تُنسب تغييرات المستخدم إلى التدقيق ولم تُعدّل أو تُرجع. الدليل: `docs/qa/evidence/git-status-before.txt` و`git-status-after.txt`.

## 5. بيئة الاختبار

| المكوّن | النتيجة |
|---|---|
| OS | Windows 11 Pro 64-bit، build `10.0.26200` |
| Flutter | 3.41.9 stable، revision `00b0c91f06` |
| Dart | 3.11.5 |
| Android | SDK 36.1؛ JDK 21.0.11؛ build متاح، لا جهاز متصل |
| Web | Chrome/Edge ظاهرَان؛ build نجح؛ التفاعل حُجب لعدم وجود browser backend داخل الأداة |
| Windows desktop | **Blocked**: Visual Studio Desktop C++ toolchain غير مثبت |
| iOS | **Blocked** على Windows |
| Node/npm | Node 26.1.0؛ `npm.cmd` 11.13.0؛ `npm.ps1` محجوب بسياسة PowerShell |
| Firebase emulator | متاح؛ 39/39 rules tests نجحت |
| Live staging | **Blocked**: لا project/credentials/App Check معزولة ومثبتة |
| Groq live | **Blocked**: `GROQ_API_KEY` غائب؛ لم تُطبع قيمة سرية |

المتغيرات `GROQ_API_KEY`, `GOOGLE_APPLICATION_CREDENTIALS`, `FIREBASE_AUTH_EMULATOR_HOST`, `FIRESTORE_EMULATOR_HOST`, `FIREBASE_APP_CHECK_DEBUG_TOKEN`, `FIREBASE_PROJECT_ID`, `CASH_PILOT_ALLOWED_ORIGINS`, و`MODEL_DIAGNOSTICS_ENABLED` كانت غائبة عند الفحص الآمن.

## 6. نطاق الاختبار

شمل الجرد 69 ملف اختبار Dart، منها 29 تخص AI، و9 integration، واختبارات owner scope، receipts، Finance Engine، transactions/reports، migrations، deletion، sync، RTL/responsive، gateway، Firestore، وGroq evaluation. شمل التدقيق المصدر والوثائق المحددة في الطلب، وركز على 30 invariant مالية/خصوصية، دون استخدام بيانات أو صور إيصالات حقيقية ودون deployment أو mutation خارجي.

## 7. ما تم تنفيذه فعليًا

- baseline وGit/env inventory آمن.
- `flutter analyze --no-pub`: Pass.
- `flutter test --no-pub -r expanded`: 517 Pass؛ ثم 650 invocation مركزة إضافية.
- Gateway test/lint/typecheck/build/secret-scan: Pass؛ production dependency audit نُفذ وأرجع findings.
- Firestore emulator: 39 Pass.
- Groq local evaluation: 16 Pass.
- Web وAndroid debug builds: Pass؛ Windows build attempt: Blocked.
- Android emulator launch/adb discovery، Chrome integration attempt، web-server HTTP smoke، وBrowser runtime discovery.
- probe محلي اصطناعي لعبارات AI العربية/الإنجليزية دون شبكة.
- مراجعة مصدر متقاطعة للرصيد، التحويلات، confirmation/reconciliation، owner scope، deletion/sync، receipts، provider routing، SSE، CORS/Auth/App Check، secrets، RTL/responsive.

## 8. ما لم يتم تنفيذه ولماذا

| الاختبار | الحالة | السبب / شرط القبول المستقبلي |
|---|---|---|
| Android device integration | Blocked | emulator لم يسجل في adb؛ يلزم جهاز/AVD متصل ثم تشغيل ملفات integration الاصطناعية |
| Chrome integration_test | Blocked | Flutter لا يدعم web device لهذا النوع؛ خرج الأمر 1 قبل أي test |
| Manual web UI interaction | Blocked | الخادم المحلي HTTP 200، لكن Browser runtime بلا backend |
| iOS | Blocked | يلزم macOS/Xcode وجهاز أو simulator |
| Windows runtime/build | Blocked | يلزم Visual Studio C++/MSVC/CMake/Windows SDK |
| Live Firebase Auth smoke | Not executed / Blocked | الاختبار ينشئ ويحذف مستخدمًا حقيقيًا؛ يلزم project staging معزول وتنظيف مثبت |
| Live App Check | Not executed / Blocked | debug token/staging registration غائبان |
| Live Firebase AI/Groq | Not executed / Blocked | staging isolation، App Check، وserver-side provider config غير متاحة |
| Deployed Firestore parity | Not executed / Blocked | لم تُثبت هوية staging أو القواعد المنشورة |
| Cloud Run ingress/multi-instance rate limit | Not executed / Blocked | لا deployment staging؛ يلزم اختبار حمولة موزع |
| Real camera/gallery/receipt corpus | Not executed / Blocked | لا جهاز؛ يمنع استخدام صور شخصية؛ يلزم corpus اصطناعي |
| Screen reader/keyboard/physical layouts | Not executed / Blocked | لا runtime تفاعلي؛ يلزم أجهزة ومنصات وصول فعلية |

## 9. ملخص النتائج

| المقياس | العدد | تعريف العدّ |
|---|---:|---|
| Total passed | 604 | حالات آلية مميزة ذات نتيجة مؤكدة |
| Total failed | 0 | failed assertions؛ لا يشمل عيوب source audit |
| Test-case invocations | ≥1,254 | يشمل focused reruns ذات العد الظاهر؛ لا يكرر wrapper Firestore غير المطبوع |
| Blocked major acceptance groups | 12 | الصفوف في القسم 8 |
| Skipped | 0 | في suites ذات العد المطبوع |
| P0 | 11 | Critical |
| P1 | 34 | High |
| P2 | 18 | Medium |
| P3 | 1 | Low |
| P4 | 6 | Informational / technical debt |
| إجمالي findings | 70 | Confirmed أو high-confidence أو limitation موصوفة صراحة |

خروج أوامر غير ناجح لا يعني failed test: Windows build وChrome integration خرجا 1 كـ Blocked؛ `npm audit` خرج 1 لأنه وجد advisory؛ محاولة Firestore wrapper المتكررة الوحيدة اصطدمت بالمنفذ الذي خلّفته العملية الأولى ثم نُظّف.

## 10. أهم عشرة أعطال

1. `AI-001`: طلب AI بدأ للمستخدم A يستطيع قراءة مجاميع B بعد تبديل الحساب وإرسالها للمزوّد.
2. `OF-009`: B قد يرث مؤقتًا سياسة AI/owner-health المسموحة للمستخدم A أثناء Riverpod reload.
3. `AI-002`: إيصال A وسياق B قد يختلطان أثناء تبديل الحساب.
4. `OF-006`: سباق deletion يعيد resolve المستخدم وقد يحذف Firebase Auth للمستخدم B بدل A.
5. `OF-007`: sync متزامن قد يعيد إنشاء بيانات سحابية بعد إعلان الحذف الكامل.
6. `OF-001`: حذف الحساب المالي يمحو الرصيد ويترك معاملات/أهداف/payee defaults يتيمة.
7. `OF-002` و`OF-003`: إنشاء/تحديث الحساب يغيّر الرصيد خارج ledger وFinance Engine.
8. `OF-004` و`OF-005`: تحويل غير متسق أو transferGroupId معاد يمكنه خلق أثر رصيد خاطئ/مكرر.
9. `GW-01` و`GW-02`: gateway يقبل قيمة مختلقة وادعاء “تم الحفظ” دون تنفيذ.
10. `OF-011` و`OF-016`: تأكيد الإيصال يتعارض مع production guards وقد يعرض نجاحًا رغم فشل metadata.

## 11. هل يمكن تفعيل Financial AI الآن؟

**لا.** الحجب مباشر بسبب `AI-001`, `OF-009`, `AI-003`, `AI-004`, `AI-006`, `AI-007`, `AI-008`, `GW-01`, `GW-02`, `GW-03` وعيوب Finance Engine/ledger P0. تبقى flags المحافظة off، ولا يجوز رفعها قبل الإصلاح واختبارات A→B/restart/live staging.

## 12. هل التطبيق جاهز لـ staging؟

**لا يُنصح.** يمكن إنشاء build تجريبي محلي، لكن لا staging acceptance قبل إغلاق كل P0 ومعظم P1، تمكين guards في الاختبارات، وتوفير Firebase/App Check/Gateway staging مع بيانات اصطناعية فقط.

## 13. هل التطبيق جاهز للإنتاج؟

**لا.** production gate مرفوض بسبب عزل المالك، سلامة الرصيد والتحويل، deletion/backup، receipts، AI grounding/claims، configuration hardening، advisory إنتاجي، ومنصات وقبول حي غير منفّذ.

## 14. AI requirement-to-test matrix

| المتطلب | الاختبار/المستوى | التنفيذ | النتيجة | التغطية الناقصة / الدليل |
|---|---|---|---|---|
| Flags fail closed | feature-flag unit | نعم | Pass | لا release-device acceptance؛ `ai-tests-summary.txt` |
| Deterministic routing | router tests + probe | نعم | **Fail** | expense provider-first، receipt/Libyan gaps؛ `AI-003..005,009,010` |
| No invented entity/rate/date | parser/factory unit | نعم | Partial Pass | لا corpus لهجات شامل |
| General/current no private context | routing/source | نعم | Pass/Partial | generic cash-flow misroutes personal؛ `AI-013` |
| Model never execution authority | registry/confirmation tests | نعم | Pass | لا live negative provider test |
| Explicit confirmation | action tests | نعم | Pass | P0 ledger paths خارج AI ما زالت موجودة |
| One-time scoped proof | action tests | نعم | Pass | live A→B/restart غير منفذ |
| Owner-scoped tool reads | source/unit | نعم | **Fail** | execution context لا يربط scope؛ `AI-001` |
| Unsupported number rejected | gateway probes/client source | نعم | **Fail** | `GW-01`, `AI-006` |
| False mutation claim rejected | gateway probes/client source | نعم | **Fail** | `GW-02`, `AI-007` |
| Tool allowlist/limits | unit | نعم | Pass | scope race خارج allowlist checks |
| Idempotency/reconciliation | 76 focused tests + source | نعم | **Fail** | المقارنة ناقصة؛ `AI-008` |
| Memory scoped/bounded/no Firestore | unit/source | نعم | Pass/Partial | deletion key خاطئ؛ `OF-013` |
| Current knowledge grounded | source/stream | نعم | **Fail** | partial text قبل source validation؛ `AI-011` |
| No post-output provider fallback | source | نعم | **Fail** | `AI-012` |
| Receipt consent and review | receipt tests/source | نعم | **Fail** | `OF-010..020`, `AI-002` |
| Safe financial guidance | unit/static | نعم | Pass/Blocked | live provider corpus غير منفذ |

## 15. AI provider-routing matrix

| الفئة | التصميم الحالي | النتيجة |
|---|---|---|
| Greeting/capability | local deterministic | Pass |
| General conversation | Groq عند flags وإلا Firebase | Partial؛ false-claim validator غير شامل |
| Current public | Firebase Google Search عند flag | Fail في stream verification؛ لا Groq current-web (Pass) |
| Personal financial | bounded read tools ثم Firebase/Groq حسب flags | Fail: scope race، generic concept misroute، grounding gaps |
| Financial extraction | يفترض local/deterministic | Fail: expense وبعض الأفعال provider-first |
| Receipt vision | Firebase AI Logic | Fail: مربوط خطأ بوضع general provider (`OF-034`) |
| Provider fallback | قبل emission فقط | Fail: Firebase قد يبدأ fallback بعد partial (`AI-012`) |

## 16. AI feature-flag matrix

| العلم/السياسة | default | النتيجة |
|---|---:|---|
| app control | off | Pass |
| navigation | off | Pass |
| create drafts release | off | Pass |
| confirmed execution | off | Pass |
| transfer/update/archive/multistep | off | Pass |
| local dataset verified | off | Pass |
| account AI policy | off | **Fail during A→B reload** (`OF-009`) |
| audit | on | Pass |
| mutation confirmation bypass | غير مسموح | Pass في unit؛ live blocked |
| malformed/contradictory defines | conservative fallback | Pass في unit؛ release-device blocked |

## 17. AI tool-permission matrix

| الصلاحية | model callable | التحقق | النتيجة |
|---|---:|---|---|
| bounded financial reads | نعم عند flags | allowlist/args/limits | **Fail owner binding** (`AI-001`) |
| deterministic calculations | نعم | bounded validation | Pass |
| create draft | feature-gated | preview/confirmation | Partial؛ extraction provider-first |
| navigation | allowlist فقط | request + response revalidation | Pass للـallowlist؛ language coverage fails |
| executeConfirmedAction | لا | policy rejects | Pass |
| raw DB/Firestore/repository/auth/secret/HTTP/file | لا | غير موجودة في catalog | Pass |
| arbitrary route/model | لا | fixed allowlists | Pass |

## 18. Financial-action confirmation matrix

| التدفق | preview/proof | execution/revalidation | النتيجة |
|---|---|---|---|
| Expense/Income | موجود | use case + proof | Partial؛ parser/type defects |
| Transfer | موجود | proof + paired write | Fail خارج AI بسبب amount/rate وgroup reuse |
| Budget/Goal/Contribution | موجود | durable bridge | Partial؛ reconciliation fields incomplete |
| wrong/expired/reused proof | مغطى unit | rejected | Pass |
| double/concurrent confirm | مغطى unit | rejected | Pass |
| owner/flag/health change | unit جزئي | revalidation | Fail transient reload/scope races |
| provider success/local failure | unit | لا execution claim مفترض | Fail لأن model text قد يدّعي النجاح |

## 19. Idempotency and reconciliation matrix

| الحالة | النتيجة |
|---|---|
| same command/proof reuse/concurrent confirm | Pass في الاختبارات |
| crash-point durable restoration | Pass في fixtures |
| transaction/transfer state exactness | **Fail**: status/date/note/rate وغيرها غير مقارنة (`AI-008`) |
| duplicate transfer group | **Fail** (`OF-005`) |
| duplicate receipt confirmation | Blocked عمليًا بعيوب capture/guard؛ قبول حقيقي غير مثبت |
| UI disconnect/restart on real device | Blocked |
| acknowledged result not repeated | Pass unit |

## 20. Two-user owner-isolation matrix

| السطح | النتيجة |
|---|---|
| Firestore document owner/cross-user rules | Pass محلي 39/39 |
| Drift scoped reads/owner immutability | Pass/Static control |
| default categories | **Fail**: global rows mutable (`OF-021`) |
| AI policy/health switch | **Fail** (`OF-009`) |
| AI in-flight read tool switch | **Fail** (`AI-001`) |
| receipt in-flight switch | **Fail** (`AI-002`) |
| deletion Auth target | **Fail** (`OF-006`) |
| confirmation proof A→B | Pass unit؛ live blocked |
| pending commands/navigation state A→B | Partial unit؛ device blocked |
| legacy NULL-owned data | controls موجودة؛ health ناقص (`OF-031/032`) |

## 21. Conversation-memory privacy matrix

| المتطلب | النتيجة |
|---|---|
| bounded recent messages/summary/12h expiry | Pass unit/source |
| no Firestore/backup | Pass source |
| no tool payload/hidden reasoning | Pass unit/source |
| optional Hive default off/scoped | Pass |
| clear/new conversation resets provider sessions | Pass source/unit |
| auth switch rebuilds sessions/controller | Pass design، لكن in-flight tools remain unsafe |
| full deletion removes correct keys | **Fail** (`OF-013`) |
| corrupted Hive handling/maximum size | Pass unit/Partial |

## 22. Receipt AI matrix

| المرحلة | النتيجة |
|---|---|
| orientation/resize/JPEG re-encode/metadata removal/SHA-256 | Pass source/unit |
| app-private storage/path containment | Pass؛ encryption risk P4 |
| owner-scoped privacy consent | **Fail** (`OF-014`) |
| capture → store → draft | **Fail** (`OF-010`) |
| owner switch during capture | **Fail** (`AI-002`) |
| strict schema/Decimal/local arithmetic | Partial؛ cross-currency/split defects |
| editable review/warnings | Partial |
| parent/items/splits atomic save | **Fail** (`OF-015`) |
| production confirmation guard | **Fail** (`OF-011`) |
| retention choice | **Fail** (`OF-017/018`) |
| duplicate/idempotent confirmation | Not established end-to-end |
| camera/gallery/malicious synthetic corpus | Blocked / missing |

## 23. Groq gateway security matrix

| الضبط | النتيجة |
|---|---|
| health/auth/method/content-type/body/Zod/CORS/no-store | Pass |
| ID token revoked/audience/App Check | Static implementation؛ live Blocked |
| fixed routes/models/no proxy/no mutation | Pass |
| tool allowlist/strict args | Pass |
| numeric grounding | **Fail** (`GW-01`) |
| false execution claims | **Fail** (`GW-02`) |
| provider context minimization | **Fail** (`GW-03`) |
| bounded SSE/output | **Fail** (`GW-04`) |
| client disconnect/timeout classification | **Fail** (`GW-05/06`) |
| PII heuristic | **Fail false positive** (`GW-07`) |
| production config fail closed | **Fail** (`GW-08`) |
| malformed JSON safe 400 | **Fail** (`GW-09`) |
| secret scan | Pass |
| production dependency audit | **Fail advisory** (`GW-10`) |
| distributed rate limit | Limitation (`GW-11`) |

## 24. Firebase/App Check matrix

| المتطلب | النتيجة |
|---|---|
| Local Firestore owner rules | Pass 39/39 |
| unauth/cross-user/anonymous backup denial | Pass محلي |
| collection/list/batch/group queries | Missing coverage |
| deployed rules parity | Blocked |
| real ID token signature/revocation/audience | Blocked؛ source implements checks |
| real App Check valid/invalid/missing | Blocked؛ source implements checks |
| diagnostics operator authorization | Gap (`GW-12`) |
| Auth deletion identity consistency | Fail (`OF-006/008/012`) |

## 25. Complete application feature matrix

| المجال | الآلي | الحكم |
|---|---:|---|
| Startup/auth/routing | unit محدود | Blocked live/device؛ alternate deletion bypass |
| Accounts | included in 517 | Fail ledger/delete boundaries |
| Transactions | focused 44 ضمن finance group | Partial؛ pending validation gap |
| Transfers | focused | Fail consistency/idempotency |
| Budgets/goals | full suite | Partial؛ goal currentAmount boundary |
| Dashboard/reports | focused | Fail special-income/historical FX/timezone cases |
| Categories/payees | full suite | Fail global mutation/reference deletion |
| Backup queue | 15 focused + 39 rules | Fail opt-in/outbox/tombstone/retention |
| Full deletion | 10 focused | Fail identity/race/cleanup/key paths |
| Receipts | 34 focused | Fail core ordering/guard/atomicity/privacy |
| AI assistant | 304 focused | Fail owner/routing/grounding/reconciliation |
| Localization/RTL/responsive | 44 focused | Pass synthetic؛ manual accessibility Blocked |

## 26. Build and platform matrix

| المنصة | الأمر | exit | الحالة |
|---|---|---:|---|
| Analyzer | `flutter analyze --no-pub` | 0 | Pass، no issues |
| Flutter tests | `flutter test --no-pub -r expanded` | 0 | Pass 517 |
| Web build | `flutter build web --no-pub` | 0 | Pass |
| Android debug APK | `flutter build apk --debug --no-pub` | 0 | Pass |
| Windows debug | `flutter build windows --debug --no-pub` | 1 | Blocked toolchain |
| iOS | — | — | Not executed / Blocked |
| Android runtime | emulator/adb | 0/2 | Blocked: no device registered |
| Web UI | local HTTP 200 | — | shell served؛ interaction Blocked |

## 27. Detailed defects

الاختصار `STATIC-AUDIT` يعني أوامر `rg` و`Get-Content` المقيدة لقراءة المصدر، exit 0، كما هو موثق في `docs/qa/evidence/source-audit-summary.txt`. لا توجد screenshots للعيوب المصدرية؛ مسار artifact مذكور لكل سجل. `Deterministic` يعني أن مسار الكود حتمي عند تحقق الشروط، و`Race` يعني أن interleaving مطلوب. جميع السجلات التالية تتضمن الحقول الإلزامية.

### OF-001 — حذف الحساب يسبب فقدًا ماليًا غير قابل للمصالحة / Account deletion causes unreconciled financial data loss

- **Area / Severity / Confidence / Status / Test type / Environment:** Accounts/ledger؛ P0؛ Confirmed؛ Open؛ source audit؛ local Windows/repository؛ Deterministic؛ كل مستخدم يملك حسابًا ذا رصيد أو مراجع.
- **Preconditions & exact reproduction:** أنشئ حسابًا ومعاملة/هدف/payee default مرتبطة، ثم نفّذ delete من `delete_account_dialog`؛ لا يوجد فحص رصيد أو references قبل hard delete.
- **Expected / Actual:** المتوقع archive/controlled close أو رفض؛ الفعلي حذف صف الحساب وضياع balance anchor مع بقاء مراجع يتيمة.
- **Evidence / command / log / artifact / source:** `STATIC-AUDIT` exit 0؛ excerpt: `delete(...accounts)..id.equals(id)`؛ `docs/qa/evidence/source-audit-summary.txt`؛ لا screenshot؛ `accounts_local_data_source.dart:37-51`, `accounts_repository_impl.dart:37-49`, `delete_account_dialog.dart:72-90`.
- **Impact:** المستخدم يفقد سجل الرصيد/تتلف التفاصيل؛ أثر مالي مباشر وفقد بيانات؛ لا تسريب بحد ذاته؛ كل الحسابات المشار إليها؛ deterministic. السبب: hard delete بلا FK/reference guard. الإصلاح الأدنى: archive أو close ذري بعد تسوية الرصيد وفحص كل dependent table؛ الملفات المذكورة وschema guards.
- **Regression / acceptance / dependencies / gates:** اختبر balance وكل transactions/goals/payee defaults ثم تأكد رفض الحذف أو migration آمن بلا orphan؛ لا dependency خارجية. Blocks Financial AI: Yes؛ staging: Yes؛ production: Yes.

### OF-002 — الرصيد الافتتاحي يتجاوز الدفتر / Opening balance bypasses the ledger

- **Metadata:** Accounts/Finance Engine؛ P0؛ Confirmed؛ Open؛ source audit؛ local؛ Deterministic؛ كل حساب جديد برصيد غير صفري.
- **Reproduction:** أنشئ حسابًا من `AddAccountBottomSheet` وأدخل `100`؛ تابع إلى insert.
- **Expected / Actual:** حساب صفر + posted opening transaction ذري؛ الفعلي `balance=100` يُكتب مباشرة بلا ledger event.
- **Evidence:** `STATIC-AUDIT` exit 0؛ excerpt: account DTO carries opening balance into insert؛ artifact `source-audit-summary.txt`؛ لا screenshot؛ `add_account_bottom_sheet.dart:150-181`, `accounts_local_data_source.dart:29-33`.
- **Impact/root/fix:** يختفي مصدر الرصيد من history/reversal/audit ويكسر invariant؛ أثر مالي لكل حساب جديد؛ لا أثر خصوصية. السبب تمثيل opening balance كحقل account. أنشئ حسابًا بصفر ومعاملة افتتاحية posted في transaction واحدة عبر Finance Engine؛ عدّل UI/use case/repository.
- **Regression/acceptance/gates:** create 100 ⇒ صف معاملة واحد وأثر balance مرة واحدة؛ rollback كامل عند الفشل. Financial AI: Yes؛ staging: Yes؛ production: Yes.

### OF-003 — تحديث الحساب يستطيع إعادة كتابة الرصيد والعملة / Account update can rewrite balance and currency

- **Metadata:** Accounts/repository boundary؛ P0؛ Confirmed؛ Open؛ source audit؛ local؛ Deterministic؛ أي caller للمستودع.
- **Reproduction:** اقرأ Account ثم `copyWith(balance: 999, currencyCode: 'USD')` ومرره إلى update repository.
- **Expected / Actual:** metadata-only update يحفظ protected fields؛ الفعلي whole DTO update يكتب balance/currency؛ قفل UI ليس boundary.
- **Evidence:** `STATIC-AUDIT` exit 0؛ excerpt: `update(...).write(account.toCompanion())`؛ artifact source summary؛ `accounts_local_data_source.dart:85-100`, `accounts_repository_impl.dart:80-89`.
- **Impact/root/fix:** تعديل رصيد/عملة بلا ledger/rate، فساد مالي لكل caller مخترق/buggy؛ لا تسريب. السبب API update واسع. companion/use case محدود للاسم/icon/color/archive/payment metadata مع DB trigger يمنع protected columns.
- **Regression/acceptance/gates:** malicious repository test يجب أن يرفض balance/currency ويتركهما byte-identical. Financial AI: Yes؛ staging: Yes؛ production: Yes.

### OF-004 — تحويل متعدد العملات يقبل amount/rate متناقضين / Cross-currency transfer accepts inconsistent amount and rate

- **Metadata:** Transfers/Finance Engine؛ P0؛ Confirmed؛ Open؛ source audit؛ local؛ Deterministic؛ caller يرسل targetAmount وexchangeRate معًا.
- **Reproduction:** source `100`, target `999`, rate `2` بعملتين مختلفتين ثم process/post.
- **Expected / Actual:** رفض أو اشتقاق `target=source×rate` وفق minor units؛ الفعلي debit 100 وcredit 999.
- **Evidence:** `STATIC-AUDIT` exit 0؛ excerpt: supplied target wins and validation checks only currencies/positive rate؛ `transfer_processor.dart:139-190`, `finance_validation_service.dart:96-118`; artifact source summary.
- **Impact/root/fix:** أرصدة وإجماليات FX خاطئة مباشرة لكل transfer caller؛ لا privacy impact. السبب عدم invariant عددي. اقبل قيمة مشتقة واحدة أو تحقق Decimal مع rounding للعملة.
- **Regression/acceptance/gates:** cases consistent/inconsistent/rounding/negative/missing rate؛ لا balance effect on reject. Financial AI: Yes؛ staging: Yes؛ production: Yes.

### OF-005 — إعادة transferGroupId تضاعف أثر الرصيد / Reused transfer group duplicates balance effects

- **Metadata:** Transfers/idempotency؛ P0؛ Confirmed؛ Open؛ source audit؛ local؛ Deterministic؛ transaction IDs جديدة وgroup ID قائم.
- **Reproduction:** أنشئ pair posted، ثم pair ثانية بنفس `transferGroupId`؛ افحص الصفوف والأرصدة ثم حاول update/delete group.
- **Expected / Actual:** رفض/idempotent replay قبل mutation؛ الفعلي أربعة صفوف وأثر ثان ثم pair operations تفشل.
- **Evidence:** `STATIC-AUDIT` exit 0؛ excerpt: no existing-group check before writes؛ `create_transfer_command.dart:8-37`, `transactions_repository_impl.dart:87-141,338-377`; artifact source summary.
- **Impact/root/fix:** duplicate execution ورصيد خاطئ؛ كل retry/caller؛ لا privacy. السبب idempotency غير مربوط بالـgroup. unique scoped group constraint + payload idempotency قبل Finance Engine.
- **Regression/acceptance/gates:** concurrent/restart/retry same group: exactly two rows and one balance effect. Financial AI: Yes؛ staging: Yes؛ production: Yes.

### OF-006 — سباق تبديل الحساب قد يحذف مستخدم Auth الخطأ / Auth-switch deletion TOCTOU

- **Metadata:** Auth/full deletion/owner isolation؛ P0؛ High confidence؛ Open؛ concurrency source audit؛ Firebase staging required؛ Race؛ مستخدمان A/B.
- **Reproduction:** ابدأ reauth/deletion لـA، أوقف بعد reauth، بدّل current user إلىB، ثم أكمل `deleteCurrentUser`.
- **Expected / Actual:** كل مرحلة مربوطة immutable UID=A وتفشل عند التبديل؛ الفعلي المرحلة الأخيرة تعيد resolve current user ويمكن حذف B.
- **Evidence:** `STATIC-AUDIT` exit 0؛ excerpt: reauth captures one currentUser while delete resolves another؛ `account_deletion_auth_data_source.dart:36-40,75-79`; artifact source summary؛ لا screenshot/live run بسبب staging blocker.
- **Impact/root/fix:** حذف حساب B وفشل حذف A؛ data loss وowner bypass؛ مستخدمو تبديل الجلسة؛ intermittent/race. استخدم deletion session/UID/user object ثابتًا وأعد التحقق قبل كل مرحلة.
- **Regression/acceptance/gates:** controlled A→B interleaving في Auth emulator؛ لا حذف لأي UID غير A، ويفشل safe عند mismatch. Financial AI: No؛ staging: Yes؛ production: Yes؛ dependency: isolated Auth emulator/staging.

### OF-007 — المزامنة قد تعيد البيانات بعد الحذف الكامل / Sync can resurrect data after full deletion

- **Metadata:** Deletion/backup؛ P0؛ High confidence؛ Open؛ concurrency source audit؛ emulator/staging؛ Race؛ backup enabled + pending upload.
- **Reproduction:** اجعل SyncManager يلتقط queue، أوقفه؛ احذف cloud collection؛ اسمح برفع doc بعدها ثم أكمل deletion/Auth.
- **Expected / Actual:** deletion fence يلغي/drains writers ويثبت recursive emptiness؛ الفعلي doc المعاد لا يُزار ثانية ويبقى orphan cloud.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `data_deletion_repository_impl.dart:32-125`, `sync_manager.dart:40-75`, `cloud_user_data_deletion_data_source.dart:37-45`; log concept: previously captured pending list continues؛ artifact source summary.
- **Impact/root/fix:** إعلان حذف كاذب واحتفاظ بيانات مالية؛ كل مستخدم backup أثناء deletion؛ privacy/data-loss-of-control؛ race. أضف scoped deletion epoch/fence، cancel/drain، privileged recursive server deletion ثم verify.
- **Regression/acceptance/gates:** deterministic scheduler test لكل collection؛ zero cloud docs/writes after fence. Financial AI: No؛ staging: Yes؛ production: Yes؛ يحتاج emulator/server job.

### OF-008 — طلب الحذف يثق بـ userId/isAnonymous من caller / Deletion trusts caller identity flags

- **Metadata:** Deletion/Auth boundary؛ P0؛ Confirmed؛ Open؛ source audit؛ local/Firebase؛ Deterministic؛ caller يستطيع إنشاء request.
- **Reproduction:** session مسجل، مرر UID الحالي مع `isAnonymous:true` ثم delete.
- **Expected / Actual:** auth datasource يشتق الهوية والحالة؛ الفعلي child backup deletion يُتخطى بينما root/local/Auth تحذف.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `data_deletion_request.dart:1-15`, `data_deletion_repository_impl.dart:58-63,87-89`, `cloud_user_data_deletion_data_source.dart:37-45`; artifact source summary.
- **Impact/root/fix:** نسخ مالية سحابية orphan وowner/auth boundary bypass؛ كل caller داخلي/معدل؛ deterministic. أزل fields غير الموثوقة واربط session ثابتًا بالـAuth.
- **Regression/acceptance/gates:** forged UID/anonymous mismatch must fail before any deletion; correct request removes all. Financial AI: No؛ staging: Yes؛ production: Yes.

### OF-009 — صلاحيات وصحة AI تتسرب مؤقتًا بين A وB / AI policy and health leak across account reload

- **Metadata:** AI owner isolation/feature flags؛ P0؛ Confirmed framework behavior، runtime test missing؛ Open؛ source/framework audit؛ local؛ Race؛ A permissive/safe وB off/unsafe.
- **Reproduction:** أخّر loading لإعدادات/health B، بدّل A→B، اقرأ `effectiveAiAppControlPolicyProvider` وstartup reconciliation خلال reload.
- **Expected / Actual:** fail closed حتى AsyncData مربوط بـB؛ الفعلي `.value` يستطيع رؤية previous A value وفق Riverpod reload semantics.
- **Evidence:** `STATIC-AUDIT` exit 0؛ excerpt: policy reads `settings.value`/`health.value`؛ `ai_app_control_providers.dart:121-130`, `ai_durable_action_providers.dart:87-100`; artifact source summary.
- **Impact/root/fix:** B قد يحصل على reads/drafts/confirmed capability دون consent أو يتجاوز unsafe health؛ cross-user authorization؛ transient. pattern-match current-scope `AsyncData`, reject loading/reloading، bind scope epoch، `unwrapPrevious`.
- **Regression/acceptance/gates:** delayed provider-container A→B must expose zero capabilities and no reconciliation until B current data. Financial AI: Yes؛ staging: Yes؛ production: Yes.

### OF-010 — التقاط الإيصال يفشل قبل التحليل / Receipt capture fails before analysis

- **Metadata:** Receipts؛ P2؛ Confirmed؛ Open؛ source audit؛ local؛ Deterministic؛ receipt feature enabled/image prepared.
- **Reproduction:** ابدأ capture؛ controller ينشئ object فقط ثم يستدعي `storeLocalImage` قبل `createAnalysisDraft`.
- **Expected / Actual:** draft row exists before owned image store؛ الفعلي repository returns not-found/failure، فلا يصل التحليل.
- **Evidence:** `STATIC-AUDIT` exit 0؛ excerpt: lines 198-214 store then create؛ `receipt_providers.dart:171-220`, `receipt_repository_impl.dart:189-205`; artifact source summary.
- **Impact/root/fix:** scanning core flow unusable، workaround إدخال يدوي؛ لا mutation مالية؛ كل receipt users؛ deterministic. أعد ترتيب create→store→update مع transaction/cleanup.
- **Regression/acceptance/gates:** guard-enabled repository integration: synthetic image yields persisted draft/reference and cleanup on each failure. Financial AI: No؛ staging: Yes؛ production: Yes.

### OF-011 — تأكيد الإيصال يصطدم بحارس قاعدة الإنتاج / Receipt confirmation conflicts with production guards

- **Metadata:** Receipts/DB integrity؛ P1؛ Confirmed؛ Open؛ source audit؛ production-style Drift؛ Deterministic؛ valid reviewed draft.
- **Reproduction:** confirm؛ use case يحجز transaction ID ويربطه بالإيصال قبل إنشاء transaction؛ فعّل production triggers.
- **Expected / Actual:** atomic transaction exists عند link أو reservation field منفصل؛ الفعلي trigger يرفض linked ID غير الموجود.
- **Evidence:** `STATIC-AUDIT` exit 0؛ excerpt: reserve at 49-63 vs trigger abort 802-812؛ `confirm_receipt_transaction.dart`, `receipt_repository_impl.dart`, `app_database.dart`; artifact source summary. 34 receipt tests Pass لكن custom executor guards off.
- **Impact/root/fix:** confirmation reliably fails in production رغم tests؛ core receipt financial workflow؛ لا privacy. السبب order/schema mismatch. create-and-link atomically أو field reservation غير FK.
- **Regression/acceptance/gates:** run exact flow with owner guards enabled; one transaction, linked receipt, no partial rows. Financial AI: No؛ staging: Yes؛ production: Yes.

### OF-012 — مسار Auth قديم يتجاوز الحذف الكامل / Legacy Auth controller bypasses full deletion

- **Metadata:** Auth/deletion؛ P1؛ Confirmed؛ Open؛ source audit؛ Firebase/local؛ Deterministic؛ caller يستخدم public `AuthController.deleteAccount`.
- **Reproduction:** استدع المسار القديم على مستخدم ببيانات backup/Drift/receipt/Hive.
- **Expected / Actual:** pipeline الكامل مع reauth/cloud children/local files/prefs/Auth-last؛ الفعلي root doc + Auth فقط وبعض AI cleanup.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `firebase_auth_data_source.dart:284-294`, `auth_providers.dart:106-109,257-272`; artifact source summary.
- **Impact/root/fix:** بيانات مالية/صور/ذاكرة تبقى دون حساب؛ privacy/compliance؛ كل caller للمسار البديل. أزل API أو delegate حصريًا للمستودع الكامل.
- **Regression/acceptance/gates:** enumerate every public delete entry and assert one orchestrator/stage order/complete cleanup. Financial AI: No؛ staging: Yes؛ production: Yes.

### OF-013 — الحذف الكامل يشتق مفاتيح AI الخطأ / Deletion derives wrong AI storage keys

- **Metadata:** AI memory/privacy/deletion؛ P1؛ Confirmed؛ Open؛ source audit؛ local؛ Deterministic؛ persistent memory/app policy exists.
- **Reproduction:** خزّن عبر runtime canonical owner scope، نفّذ deletion بالـraw UID، ثم افحص production keys.
- **Expected / Actual:** نفس key derivation المركزي ويحذف memory/policy؛ الفعلي runtime double-hash يختلف عن deletion single-hash؛ القيم تبقى. الاختبار الحالي يكرر derivation الخاطئ.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `owner_scope.dart:65-87`, `settings_local_data_source.dart:87-120`, `ai_agent_providers.dart:165-183`, `ai_app_control_providers.dart:30-33`, `deletion_preferences_data_source.dart:19-31`, test lines 153-224؛ artifact source summary.
- **Impact/root/fix:** رسائل/سياسة AI محلية تبقى بعد deletion وقد تظهر لاحقًا؛ privacy لكل persistence-enabled user. وحّد typed key API واستخدم actual owner scope.
- **Regression/acceptance/gates:** production store writes then full deletion asserts every exact key absent؛ wrong-hash fixture must not mask. Financial AI: Yes؛ staging: Yes؛ production: Yes.

### OF-014 — رضا خصوصية الإيصال عالمي بين المستخدمين / Receipt consent is global across users

- **Metadata:** Receipt privacy/owner isolation؛ P1؛ Confirmed؛ Open؛ source audit؛ shared device؛ Deterministic؛ A consents ثم B signs in.
- **Reproduction:** A يفعّل remote receipt؛ sign out/in B؛ افتح capture.
- **Expected / Actual:** B يحتاج consent مستقل owner-scoped؛ الفعلي global boolean يبقى ويُستخدم للرفع.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `settings_keys.dart:10`, `receipt_privacy_consent_store.dart:10-18`, `receipt_capture_screen.dart:105-121`; artifact source summary.
- **Impact/root/fix:** صورة B يمكن إرسالها دون رضاه؛ privacy/cross-user؛ كل جهاز مشترك؛ deterministic. اربط key بالـopaque scope وامسحه/تعطيله عند auth transition.
- **Regression/acceptance/gates:** A=true→B must read false and block provider before bytes leave. Financial AI: No؛ staging: Yes؛ production: Yes.

### OF-015 — حفظ مراجعة الإيصال غير ذري ولا يحفظ الأطفال / Receipt review save is non-atomic

- **Metadata:** Receipts/persistence؛ P1؛ Confirmed؛ Open؛ source audit؛ local؛ Deterministic/failure-injection؛ draft مع items/splits.
- **Reproduction:** عدّل parent/items/splits، inject child save failure، اضغط save.
- **Expected / Actual:** replace parent/items/splits atomically أو rollback؛ الفعلي parent يحفظ منفصلًا، update لا يحفظ children، نتيجة line items تُهمل وsplits لا تحفظ مع success UI.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `receipt_repository_impl.dart:42-72`, `receipt_review_screen.dart:652-723`; artifact source summary.
- **Impact/root/fix:** مراجعة المستخدم تضيع أو metadata قديمة قبل confirmation؛ مالية/UX، لا cross-user؛ كل edited receipts. أضف repository transaction واحدة وpropagate كل failure.
- **Regression/acceptance/gates:** inject failure at every child write ⇒ no state change/success; success ⇒ exact replacement. Financial AI: No؛ staging: Yes؛ production: Yes.

### OF-016 — الواجهة تعلن نجاح الإيصال رغم فشل metadata / Receipt confirmation reports success on metadata failure

- **Metadata:** Receipts/false execution result؛ P1؛ Confirmed؛ Open؛ source audit؛ local؛ Deterministic عند finalize failure؛ كل confirmations.
- **Reproduction:** اسمح بإنشاء transaction ثم اجعل `finalizeConfirmation` يفشل؛ راقب result/UI.
- **Expected / Actual:** partial failure/reconciliation واضح ولا success navigation؛ الفعلي `AppSuccess(metadataPersisted:false)` والواجهة تعرض created وتغادر.
- **Evidence:** `STATIC-AUDIT` exit 0؛ excerpt `metadataPersisted: false` داخل success؛ `confirm_receipt_transaction.dart:91-116`, `receipt_review_screen.dart:780-789`; artifact source summary.
- **Impact/root/fix:** المستخدم يعتقد أن receipt/link/splits/retention اكتملت؛ transaction قد يوجد وحيدًا؛ privacy إذا retention مختلف؛ كل failure. السبب success type لا يعكس commit contract. durable retry أو typed partial state مع UI blocking.
- **Regression/acceptance/gates:** finalize failure must never show full success; retry idempotently completes metadata. Financial AI: No؛ staging: Yes؛ production: Yes.

### OF-017 — فشل حذف صورة الإيصال يُتجاهل / Receipt image deletion failure is ignored

- **Metadata:** Receipt privacy/retention؛ P1؛ Confirmed؛ Open؛ source audit؛ local filesystem؛ Deterministic عند IO failure؛ مستخدم اختار delete.
- **Reproduction:** اختر “delete after extraction”، inject file delete error أثناء confirm.
- **Expected / Actual:** تحذير/فشل وcleanup retry؛ الفعلي failure مهمل وsuccess ظاهر بينما JPEG يبقى.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `confirm_receipt_transaction.dart:111-115`, `receipt_repository_impl.dart:209-231`; artifact source summary؛ لا screenshot.
- **Impact/root/fix:** انتهاك اختيار retention واحتمال بقاء صورة حساسة؛ لا أثر balance؛ كل IO failure. propagate result واحفظ cleanup job/tombstone durable.
- **Regression/acceptance/gates:** denied/locked file ⇒ visible partial state + later cleanup; success only after deletion verified. Financial AI: No؛ staging: Yes؛ production: Yes.

### OF-018 — حذف draft قد يترك صورة حساسة يتيمة / Draft deletion can orphan receipt image

- **Metadata:** Receipts/files؛ P1؛ Confirmed؛ Open؛ failure-injection source audit؛ local؛ Deterministic عند IO failure.
- **Reproduction:** draft له image reference؛ اجعل file delete يفشل بعد DB delete.
- **Expected / Actual:** reference/tombstone يبقى حتى cleanup؛ الفعلي DB row يحذف أولًا فتفقد full-deletion وسيلة اكتشاف الملف.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `receipt_repository_impl.dart:109-137`; artifact source summary.
- **Impact/root/fix:** صورة خاصة غير قابلة للإدارة/الحذف عبر التطبيق؛ privacy؛ كل draft deletion failure. اعكس الترتيب بأمان أو journal cleanup transactionally.
- **Regression/acceptance/gates:** inject crash/IO failure at each step; eventual no file ولا orphan row. Financial AI: No؛ staging: No بعد إصلاح P0/P1؛ production: Yes.

### OF-019 — مبلغ وسعر إيصال متعدد العملات غير مترابطين / Receipt FX amount and rate are independently trusted

- **Metadata:** Receipt/FX؛ P1؛ Confirmed؛ Open؛ source audit؛ local؛ Deterministic؛ receipt currency ≠ account currency.
- **Reproduction:** total 100، account amount 999، rate 2، confirm review.
- **Expected / Actual:** derive/check `accountAmount=receiptTotal×rate` واتجاه العملات/rounding؛ الفعلي الحقول تتحقق منفردة فقط.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `build_receipt_transaction_draft.dart:70-123`, `receipt_review_screen.dart:749-778`; artifact source summary.
- **Impact/root/fix:** posted transaction amount خاطئ؛ كل cross-currency receipt؛ لا privacy. السبب missing invariant. اشتق قيمة واحدة واستخدم Finance Engine FX validator.
- **Regression/acceptance/gates:** valid/inverted/zero/mismatched/minor-unit cases؛ reject has zero balance effect. Financial AI: Yes؛ staging: Yes؛ production: Yes.

### OF-020 — توزيع التقريب قد يصنع split سالبًا / Split rounding can produce a negative final split

- **Metadata:** Receipts/splits/money؛ P1؛ Confirmed؛ Open؛ deterministic source example؛ local.
- **Reproduction:** total `.02`، أربعة shares `.005`؛ شغّل allocator.
- **Expected / Actual:** four nonnegative minor-unit allocations summing `.02`؛ الفعلي أول ثلاثة `.01` والآخر `-.01` مع مجموع صحيح ظاهريًا.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `receipt_split_allocator.dart:70-101`, `transaction_split.dart:15-32`; artifact source summary.
- **Impact/root/fix:** negative category split وتقارير فاسدة؛ كل small totals/many parts؛ deterministic. largest-remainder in integer minor units + entity nonnegative invariant.
- **Regression/acceptance/gates:** property tests لكل currencies/shares: nonnegative, exact sum, bounded rounding. Financial AI: Yes؛ staging: Yes؛ production: Yes.

### OF-021 — الفئات الافتراضية المشتركة قابلة للتعديل عبر المستخدمين / Shared default categories are globally mutable

- **Metadata:** Categories/owner isolation؛ P1؛ Confirmed؛ Open؛ source audit؛ shared local DB؛ Deterministic؛ مستخدمان.
- **Reproduction:** A يعدّل/يؤرشف default owner-null؛ B يقرأ categories.
- **Expected / Actual:** globals immutable أو copies لكل owner؛ الفعلي update يسمح owner-null default وB يرى التغيير؛ UI يعرض edit/archive.
- **Evidence:** `STATIC-AUDIT` exit 0؛ excerpt owner scope OR global default in update؛ `categories_local_data_source.dart:77-100,123-180`, `categories_screen.dart:218-270,444-475`; artifact source summary.
- **Impact/root/fix:** cross-user financial reference mutation وتقارير/تصنيف B تتغير؛ privacy لا، integrity نعم؛ كل مستخدمي نفس DB. امنع update/archive في UI/repo/trigger أو انسخ لكل owner.
- **Regression/acceptance/gates:** A operations rejected; B default byte-identical; custom categories remain scoped. Financial AI: Yes؛ staging: Yes؛ production: Yes.

### OF-022 — حذف الفئة يترك مراجع مالية معلقة / Category deletion leaves dangling references

- **Metadata:** Categories/data integrity؛ P1؛ Confirmed؛ Open؛ source audit؛ local؛ Deterministic؛ category referenced.
- **Reproduction:** custom category مرتبطة transaction/budget/split/payee/receipt؛ hard delete.
- **Expected / Actual:** block/archive/reassign atomically؛ الفعلي row يحذف بلا reference checks/FKs.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `categories_local_data_source.dart:47-68`; artifact source summary.
- **Impact/root/fix:** تقارير وتصنيف وتحرير قد يفقد labels أو يفشل؛ مالي لكل reference؛ لا privacy. أضف dependency query/guards واستخدم archive.
- **Regression/acceptance/gates:** كل dependent table يمنع delete؛ unreferenced delete safe. Financial AI: Yes؛ staging: Yes؛ production: Yes.

### OF-023 — تدفقات خاصة تُحسب دخلًا عاديًا / Special inflows counted as normal income

- **Metadata:** Dashboard/reporting؛ P1؛ Confirmed؛ Open؛ source audit؛ local؛ Deterministic؛ refund/reimbursement/externalTransfer.
- **Reproduction:** أنشئ posted income لكل enum ثم احسب dashboard income.
- **Expected / Actual:** استبعاد/عرض خاص؛ الفعلي policy يستبعد loanProceeds فقط ويضم الثلاثة كearned/normal income.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `income_reporting_policy.dart:6-11`, `income_source_type.dart:43-50`, `dashboard_providers.dart:133-143`; artifact source summary.
- **Impact/root/fix:** income/cash-flow/savings guidance مبالغ فيه؛ كل مستخدم بهذه التدفقات؛ deterministic. exhaustive enum policy وtyped reporting buckets.
- **Regression/acceptance/gates:** table-driven all enum+null matches policy; dashboard exact totals. Financial AI: Yes؛ staging: Yes؛ production: Yes.

### OF-024 — الإدخال اليدوي لا يصنف الدخل الخاص / Manual income lacks special-inflow classification

- **Metadata:** Transactions UI/reporting؛ P1؛ Confirmed؛ Open؛ source/UI audit؛ local؛ Deterministic؛ manual refund/loan/etc.
- **Reproduction:** افتح income form وأدخل refund/reimbursement/loan؛ لا selector لـ`incomeSourceType`.
- **Expected / Actual:** explicit classification أو safe unclassified؛ الفعلي null ويُعامل normal income.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `transaction_form_sheet.dart:426-459`; artifact source summary.
- **Impact/root/fix:** تقارير وAI analysis خاطئة؛ كل manual special inflow؛ no privacy. أضف selector/validation ولا تعتبر null normal بلا policy.
- **Regression/acceptance/gates:** UI/domain tests لكل type/null؛ displayed totals correct. Financial AI: Yes؛ staging: No بعد P0/P1؛ production: Yes.

### OF-025 — أسعار اليوم تعيد كتابة التقارير التاريخية / Current FX mutates historical reports

- **Metadata:** Dashboard/FX؛ P1؛ Confirmed؛ Open؛ source audit؛ local؛ Deterministic؛ historic transaction بلا embedded rate.
- **Reproduction:** احسب شهرًا سابقًا، غيّر latest stored rate، أعد الحساب.
- **Expected / Actual:** نفس historical total أو missing-rate warning؛ الفعلي fallback لأحدث rate يغير الماضي.
- **Evidence:** `STATIC-AUDIT` exit 0؛ TODO/fallback في `dashboard_providers.dart:426-468`; artifact source summary.
- **Impact/root/fix:** تقارير/AI trends غير مستقرة؛ مالي لكل multi-currency history؛ no privacy. خزّن transaction-date rate أو dated lookup ولا fallback صامت.
- **Regression/acceptance/gates:** later rate update leaves old period invariant; missing dated rate sets partial warning. Financial AI: Yes؛ staging: Yes؛ production: Yes.

### OF-026 — تفعيل النسخ لا يلتقط البيانات القديمة / Backup opt-in misses existing data

- **Metadata:** Backup؛ P1؛ Confirmed؛ Open؛ source audit؛ local/Firestore؛ Deterministic؛ مستخدم قديم بلا pending mutations.
- **Reproduction:** أنشئ بيانات والنسخ off، فعّل backup واضغط Backup Now.
- **Expected / Actual:** snapshot/reconciliation كامل scoped؛ الفعلي settings فقط تُqueue وmanager يعالج pending فقط، فلا تُرفع البيانات القديمة.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `sync_mutation_queue.dart:97-109`, `backup_sync_settings_section.dart:133-151`, `sync_manager.dart:40-75`; artifact source summary.
- **Impact/root/fix:** backup ناقص وfalse confidence؛ مالي/availability لا local loss؛ كل late opt-in. initial versioned snapshot/reconciler مع progress/completeness marker.
- **Regression/acceptance/gates:** mature fixture opt-in ⇒ كل supported docs exactly once. Financial AI: No؛ staging: Yes؛ production: Yes.

### OF-027 — إيقاف النسخ لا يمنع رفع pending / Backup opt-out not enforced at execution

- **Metadata:** Backup consent/privacy؛ P1؛ Confirmed؛ Open؛ source audit؛ local/Firestore؛ Deterministic/race؛ pending exists ثم disable.
- **Reproduction:** queue mutation while on؛ disable؛ trigger SyncManager/controller.
- **Expected / Actual:** cancel/purge and hard consent check before every upload؛ الفعلي manager لا يقرأ backupEnabled وpending يبقى ويرتفع.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `sync_manager.dart:16-38`, `sync_providers.dart:85-109`, `backup_sync_settings_section.dart:139-151`; artifact source summary.
- **Impact/root/fix:** بيانات مالية تُرفع بعد سحب consent؛ privacy لكل pending user؛ deterministic given trigger. consent gate inside manager + purge/cancel generation token.
- **Regression/acceptance/gates:** disable at every interleaving ⇒ zero post-disable network writes. Financial AI: No؛ staging: Yes؛ production: Yes.

### OF-028 — outbox الأفضل-جهد يسقط mutations بصمت / Best-effort outbox loses backup mutations

- **Metadata:** Backup durability؛ P1؛ Confirmed؛ Open؛ failure-injection source audit؛ local؛ Deterministic عند enqueue failure.
- **Reproduction:** commit transaction ثم اجعل queue insert يرمي؛ شغّل retries.
- **Expected / Actual:** business write وoutbox ذريان أو dirty scan؛ الفعلي exception تُبتلع والrecord لا يُنسخ أبدًا.
- **Evidence:** `STATIC-AUDIT` exit 0؛ excerpt catch-all best effort؛ `sync_mutation_queue.dart:27-59`, `transactions_repository_impl.dart:61-68,550-560`; artifact source summary.
- **Impact/root/fix:** backup ناقص بلا تحذير؛ مالي/availability؛ كل local queue failure. outbox في نفس Drift transaction أو durable version reconciler.
- **Regression/acceptance/gates:** injected enqueue failure rolls back أو reconciles later; observable status. Financial AI: No؛ staging: Yes؛ production: Yes.

### OF-029 — tombstone السحابي يحتفظ بالحقول الحساسة / Merge tombstones retain sensitive fields

- **Metadata:** Backup privacy/deletion؛ P1؛ Confirmed؛ Open؛ source audit؛ Firestore؛ Deterministic؛ existing full doc.
- **Reproduction:** seed synthetic doc with amount/note/account؛ sync delete؛ read document.
- **Expected / Actual:** delete doc أو overwrite minimal tombstone؛ الفعلي `set(..., merge:true)` يضيف `isDeleted` ويترك الحقول القديمة.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `firestore_sync_data_source.dart:52-70`; artifact source summary؛ live read blocked، source deterministic.
- **Impact/root/fix:** احتفاظ مالي بعد delete وprivacy/compliance؛ كل deleted backed-up doc. استخدم delete أو non-merge minimal schema وTTL.
- **Regression/acceptance/gates:** emulator seeded sensitive fields absent after delete; rules remain owner-only. Financial AI: No؛ staging: Yes؛ production: Yes.

### OF-030 — queue تخزن UID خامًا وpayload ماليًا بلا حد / Sync queue retains raw UID and payloads indefinitely

- **Metadata:** Local privacy/data retention؛ P1؛ Confirmed؛ Open؛ source audit؛ local Drift؛ Deterministic؛ backup mutations processed.
- **Reproduction:** enqueue upsert، mark synced، enqueue tombstone؛ query queue.
- **Expected / Actual:** opaque scope + bounded/purged/redacted rows؛ الفعلي raw Firebase UID وfull JSON يبقيان بعد sync/delete.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `sync_queue_table.dart:5-8`, `sync_mutation_queue.dart:103-125`, `sync_queue_repository.dart:175-190`; artifact source summary.
- **Impact/root/fix:** توسع سطح PII وبيانات مالية محلية وتناقض deletion؛ كل backup user؛ deterministic. استخدم owner scope، retention TTL، purge/redact success rows.
- **Regression/acceptance/gates:** after success/deletion no raw UID or financial payload beyond documented bound. Financial AI: No؛ staging: No بعد P0/P1؛ production: Yes.

### OF-031 — owner health قد يعلن safe رغم مراجع فاسدة / Owner-scope health has incomplete coverage

- **Metadata:** Owner health/AI gate؛ P1؛ Confirmed؛ Open؛ source audit؛ local؛ Deterministic؛ corrupt logical references.
- **Reproduction:** أدخل mismatch في transfer group/payee default/category parent/receipt child/split/goal link/AI child ثم شغّل health.
- **Expected / Actual:** unsafe مع سبب؛ الفعلي queries لا تفحص هذه العلاقات وقد تعيد safe.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `owner_scope_health_service.dart:37-48,56-109,117-127`; artifact source summary.
- **Impact/root/fix:** Financial AI قد يقرأ/ينفذ فوق dataset غير معزول؛ integrity/privacy لكل legacy/corrupt DB. وسّع health إلى كل logical FK وfail closed on query errors.
- **Regression/acceptance/gates:** fixture مستقل لكل relation يجب unsafe؛ clean scope only safe. Financial AI: Yes؛ staging: Yes؛ production: Yes.

### OF-032 — حارس transfer group مفقود في UPDATE / Transfer-group owner guard missing on update

- **Metadata:** Drift owner isolation/transfers؛ P1؛ Confirmed؛ Open؛ source audit؛ local؛ Deterministic؛ update/legacy claim.
- **Reproduction:** أنشئ group لـB، حدّث/claim row لـA إلى group نفسه عبر UPDATE.
- **Expected / Actual:** trigger يرفض cross-scope collision؛ الفعلي INSERT guard موجود لكن UPDATE لا يحقق group ownership، وhealth لا يكتشفه.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `app_database.dart:674-708`, `owner_scope_health_service.dart:80-109`; artifact source summary.
- **Impact/root/fix:** pairs عبر owners/فساد transfer reconciliation؛ financial/privacy؛ legacy/updated rows؛ deterministic. أضف UPDATE trigger + migration audit.
- **Regression/acceptance/gates:** cross-scope update aborts، same-scope passes، legacy collision blocks claim/AI. Financial AI: Yes؛ staging: Yes؛ production: Yes.

### OF-033 — رصيد افتتاحي سالب يصنع حسابًا لا يُصلح / Negative opening balance creates unrecoverable account state

- **Metadata:** Accounts/overdraft policy؛ P1؛ Confirmed؛ Open؛ source audit؛ local؛ Deterministic؛ negative opening.
- **Reproduction:** UI يقبل balance سالب؛ repository maps policy defaults false/zero؛ حاول credit يصلحه.
- **Expected / Actual:** reject أو persist account overdraft/credit policy؛ الفعلي negative account موجود وvalidator يرفض حتى الإصلاح، والجدول لا يخزن policy domain.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `add_account_bottom_sheet.dart:150-181`, `drift_account_balance_repository.dart:18-35`, `finance_validation_service.dart:11-45`, `accounts_table.dart`; artifact source summary.
- **Impact/root/fix:** حساب core غير قابل للاستخدام وأرصدة خاطئة؛ كل negative/credit account. امنع negative opening أو خزّن/mapping السياسة فعليًا بما يشمل credit card.
- **Regression/acceptance/gates:** negative cash rejected؛ configured credit account works within limit؛ repair credit allowed. Financial AI: Yes؛ staging: Yes؛ production: Yes.

### OF-034 — رؤية الإيصال مربوطة خطأ بمزوّد المحادثة / Receipt vision coupled to general provider mode

- **Metadata:** Receipt/provider routing؛ P2؛ Confirmed؛ Open؛ source/doc audit؛ local؛ Deterministic؛ Firebase receipt flag on + Groq general selected.
- **Reproduction:** اختر Groq general ثم اطلب remote receipt analysis.
- **Expected / Actual:** Firebase vision مستقل حسب dedicated flag/consent؛ الفعلي `firebaseEnabled` يعتمد `aiProviderTypeProvider==firebaseGemini` فيحوّل إلى manual review.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `receipt_capture_screen.dart:110-130`, `receipt_providers.dart:100,223-225`, mismatch مع `docs/ai_financial_agent_architecture.md:5-7,247-248`; artifact source summary.
- **Impact/root/fix:** receipt AI unavailable في configuration مدعومة؛ لا balance/خصوصية مباشرة؛ كل Groq-mode user. افصل capability/provider selection.
- **Regression/acceptance/gates:** routing matrix لكل flag/provider؛ receipt bytes only Firebase with consent. Financial AI: No؛ staging: No بعد P0/P1؛ production: Yes.

### OF-035 — حذف محلي يزيل الصور قبل DB transaction / Local full deletion removes files before DB commit

- **Metadata:** Deletion/receipts؛ P1؛ High confidence؛ Open؛ crash source audit؛ local؛ Race/crash؛ receipt rows exist.
- **Reproduction:** ابدأ local delete، احذف الملفات، inject DB failure/crash قبل transaction completion.
- **Expected / Actual:** durable staged cleanup/consistent rollback؛ الفعلي rows تبقى وتشير لصور مفقودة.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `local_user_data_deletion_data_source.dart:24-31`; artifact source summary.
- **Impact/root/fix:** فقد صورة/عدم اتساق partial deletion؛ data loss؛ كل crash/DB failure. journal مراحل، DB tombstone ثم post-commit retry أو recoverable trash.
- **Regression/acceptance/gates:** crash at every stage resumes to complete or preserves accessible data؛ no broken reference. Financial AI: No؛ staging: Yes؛ production: Yes.

### OF-036 — allowlist ثابت لا يضمن حذف كل subcollection / Fixed cloud allowlist cannot guarantee full deletion

- **Metadata:** Cloud deletion/compliance؛ P1؛ High confidence؛ Open؛ source/emulator acceptance missing؛ Firestore؛ Deterministic لcollection غير معروفة.
- **Reproduction:** أنشئ child collection تاريخية/جديدة خارج القائمة ثم full delete.
- **Expected / Actual:** recursive privileged delete لجميع descendants؛ الفعلي تسع collections ثابتة ثم parent، والطفل يبقى لأن Firestore parent delete غير recursive.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `cloud_user_data_deletion_data_source.dart:19-29,40-45`; artifact source summary.
- **Impact/root/fix:** احتفاظ غير مرئي ببيانات مستخدم؛ privacy/compliance؛ كل schema evolution. server-side recursive callable/job + verification.
- **Regression/acceptance/gates:** unknown nested collection is removed in staging emulator/project; audit logs sanitized. Financial AI: No؛ staging: Yes؛ production: Yes.

### OF-037 — حذف مستخدم يمسح إعدادات عالمية لمستخدمين آخرين / Full deletion wipes global device settings

- **Metadata:** Deletion/shared-device UX؛ P2؛ Confirmed؛ Open؛ source audit؛ local shared device؛ Deterministic.
- **Reproduction:** B له base currency/remember-me/receipt consent device state؛ احذف A.
- **Expected / Actual:** scoped A keys فقط أو global-reset policy صريح؛ الفعلي base currency، remember-me، consent العالمية تُحذف.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `deletion_preferences_data_source.dart:22-31`; artifact source summary.
- **Impact/root/fix:** B يفقد تفضيلاته وقد يُعاد ضبط UX؛ لا رصيد؛ cross-user local state. صنّف keys global/scoped وامسح فقط scoped، أو لا تسمح multi-user retained globals.
- **Regression/acceptance/gates:** A deletion leaves B/global approved settings intact. Financial AI: No؛ staging: No؛ production: Yes.

### OF-038 — سجل owner migration يبقى بعد الحذف / Owner migration audit survives deletion

- **Metadata:** Deletion/privacy؛ P2؛ Confirmed؛ Open؛ source audit؛ local؛ Deterministic؛ migration audit exists.
- **Reproduction:** full delete ثم query `owner_scope_migration_audits`.
- **Expected / Actual:** حذف/إخفاء أي owner-identifying audit وفق retention policy؛ الفعلي table omitted من deletion transaction.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `owner_scope_migration_audits_table.dart`, omission in `local_user_data_deletion_data_source.dart:31-88`; artifact source summary.
- **Impact/root/fix:** metadata ownership يبقى؛ privacy limited، no financial total؛ migrated users. أضف scoped cleanup أو documented anonymized retention.
- **Regression/acceptance/gates:** deletion leaves no owner-resolvable audit row unless policy/legal retention explicitly tested. Financial AI: No؛ staging: No؛ production: Yes.

### OF-039 — فترات التقارير تخلط local time وUTC / Report periods use inconsistent timezones

- **Metadata:** Dashboard/reporting؛ P2؛ Confirmed؛ Open؛ source audit؛ all platforms؛ Deterministic قرب month boundary.
- **Reproduction:** transaction قرب منتصف الليل/نهاية الشهر في timezone غير UTC؛ قارن headline وsix-month trend.
- **Expected / Actual:** policy زمنية واحدة؛ الفعلي current period local وtrend UTC فتنتقل الحركة بين أشهر مختلفة.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `dashboard_providers.dart:116-131,334-359`; artifact source summary.
- **Impact/root/fix:** totals/charts متناقضة وAI قد يكررها؛ مالي محدود عند الحدود؛ no privacy. centralized reporting clock/timezone.
- **Regression/acceptance/gates:** Tripoli and DST/timezone boundary fixtures agree across widgets. Financial AI: Yes؛ staging: No؛ production: Yes.

### OF-040 — pending transaction يتجاوز تحقق المبلغ/العملة / Pending path skips amount and currency validation

- **Metadata:** Transactions/domain boundary؛ P2؛ Confirmed؛ Open؛ source audit؛ local؛ Deterministic؛ repository caller bypasses UI.
- **Reproduction:** persist pending with zero/negative amount أو unsupported currency.
- **Expected / Actual:** entity/repository invariant يرفض؛ الفعلي pending path writes while UI-only validation hides issue.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `transactions_repository_impl.dart:448-460`, `transaction.dart:42-88`; artifact source summary.
- **Impact/root/fix:** invalid drafts/search/report state؛ لا balance قبل posting لكن لاحقًا خطر؛ all callers. enforce typed Money/currency validation in domain/repository.
- **Regression/acceptance/gates:** zero/negative/unsupported pending rejected at boundary; posted behavior unchanged. Financial AI: Yes؛ staging: No؛ production: Yes.

### OF-041 — currentAmount للهدف قابل للتزوير خارج contribution ledger / Goal balance can bypass contribution ledger

- **Metadata:** Goals/financial integrity؛ P2؛ Confirmed؛ Open؛ source audit؛ local؛ Deterministic؛ repository caller.
- **Reproduction:** create/update Goal مع arbitrary `currentAmount` دون contribution.
- **Expected / Actual:** currentAmount مشتق/محمي ويُغيّر فقط atomic contribution/reversal؛ الفعلي whole entity accepted.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `goal.dart:37-117`, `goal_repository_impl.dart:63-89,198-215`; artifact source summary.
- **Impact/root/fix:** progress/net saved guidance خاطئ؛ كل caller/AI draft path؛ no privacy. metadata-only goal updates + derive from contribution ledger/DB guard.
- **Regression/acceptance/gates:** direct currentAmount rewrite rejected; contribution exact-once changes it. Financial AI: Yes؛ staging: No؛ production: Yes.

### OF-042 — سياسة rounding النقدية غير موحدة / Monetary rounding policy is inconsistent

- **Metadata:** Money/formatting/FX/splits؛ P2؛ Confirmed؛ Open؛ source audit؛ local؛ Deterministic حسب scale/currency.
- **Reproduction:** قيم بأكثر من minor units وعملات scale مختلف؛ قارن calculation, reciprocal, format, split.
- **Expected / Actual:** currency-aware quantization policy واحدة؛ الفعلي arbitrary Decimal scale، reciprocal scale 12، raw format، split ثابت 2 decimals.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `money.dart`, `balance_calculator.dart:64-80`, `finance_formatters.dart:7-17`, `receipt_split_allocator.dart:8-10`; artifact source summary.
- **Impact/root/fix:** فروق cent/display/reconciliation؛ مالي عبر currencies؛ no privacy. MoneyContext/minor-unit registry and boundary quantization with explicit rounding mode.
- **Regression/acceptance/gates:** property/golden tests LYD/USD and 0/2/3 minor-unit cases، exact ledger conservation. Financial AI: Yes؛ staging: No؛ production: Yes.

### OF-043 — حماية الصور تعتمد على sandbox دون تشفير تطبيقي / Receipt files rely on platform storage protection

- **Metadata:** Receipt at-rest privacy؛ P4؛ Medium confidence/conditional risk؛ Open؛ source/platform review؛ device-dependent؛ Deterministic implementation، exploitability environment-dependent.
- **Reproduction:** inspect storage implementation and device backup/root policy؛ files are JPEG under app-private directory without app-layer encryption.
- **Expected / Actual:** documented threat model and encrypted-at-rest control where required؛ actual path containment/private directory are good, encryption absent.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `receipt_local_image_store.dart:13-19,45-48`; artifact source summary؛ device security test Blocked.
- **Impact/root/fix:** only compromised/rooted/backup scenarios may expose images؛ no financial mutation؛ receipt users. Decide threat model؛ use OS encrypted storage/exclude backup or app-layer key encryption.
- **Regression/acceptance/gates:** verify backup exclusion/file protection on Android/iOS and encrypted bytes if mandated. Financial AI: No؛ staging: No؛ production: No alone, but security sign-off required.

### OF-044 — test executors يعطلون حراس الإنتاج بصمت / Custom DB executors disable production guards

- **Metadata:** Test infrastructure/DB guards؛ P4؛ Confirmed؛ Open؛ source/test audit؛ tests؛ Deterministic.
- **Reproduction:** construct `AppDatabase(executor: memory)` without explicit guard flag؛ inspect trigger setup.
- **Expected / Actual:** guards on by default or tests opt out loudly؛ الفعلي custom executor defaults off، فتمر flows تفشل production (`OF-011`).
- **Evidence:** `STATIC-AUDIT` exit 0؛ 517 tests Pass مع warning؛ `app_database.dart:49-55`; artifacts `flutter-test-summary.txt`, source summary.
- **Impact/root/fix:** false confidence/missed integrity regressions؛ no direct user impact until release؛ broad test suite. اجعل guards default on وأضف test-only explicit factory.
- **Regression/acceptance/gates:** all persistence/receipt/owner tests run guards on; opt-out isolated and named. Financial AI: Yes indirectly؛ staging: No؛ production: Yes as gate-quality issue.

### OF-045 — migration tests لا تعيد schemas قديمة أصلية / Migration tests use synthetic current schemas

- **Metadata:** Migration automation؛ P4؛ Confirmed؛ Open؛ test-source audit؛ local؛ Deterministic coverage gap.
- **Reproduction:** راجع fixture: create v16، drop selected future tables، set `user_version` قديم؛ columns/indexes المستقبلية قد تبقى.
- **Expected / Actual:** golden DB لكل إصدار فعلي ثم migrate؛ الفعلي simulation لا يكشف add-column/index conflicts الواقعية.
- **Evidence:** `STATIC-AUDIT` exit 0؛ 11 migration tests Pass؛ `app_database_migration_test.dart:430-502`; artifacts test/source summaries.
- **Impact/root/fix:** upgrades حقيقية قد تفشل رغم green tests؛ data-loss risk غير مثبت؛ legacy users. خزّن sanitized schema fixtures v8-v15 واختبر data invariants/rollback.
- **Regression/acceptance/gates:** each authentic fixture migrates to v16 with rows/constraints verified. Financial AI: No؛ staging: No؛ production: Yes as release gate.

### GW-01 — بوابة grounding تقبل أرقامًا مالية مختلقة / Financial grounding accepts unsupported numeric forms

- **Metadata:** Groq gateway/financial grounding؛ P1؛ Confirmed runtime probe؛ Open؛ mocked integration/security probe؛ Node 26 local؛ Deterministic.
- **Reproduction:** facts=`100` والرد يحتوي `٩٩٩`؛ أو facts=`9007199254740992` والرد `9007199254740993`؛ أو facts تحوي 1 و9 والرد `1e9`.
- **Expected / Actual:** reject/correct كل رقم غير مدعوم بدقة Decimal؛ الفعلي الحالات الثلاث `accepted=true; unsupportedCount=0`.
- **Evidence:** gateway probe command exit 0 ضمن audit؛ excerpts في `gateway-test-summary.txt`؛ لا screenshot؛ `response_parser.ts:39-48,64,90`.
- **Impact/root/fix:** AI يختلق مبلغًا ويجتاز control؛ financial users؛ لا cross-user، لكن integrity عالية. السبب `Number` binary + ASCII regex. canonical decimal strings، Arabic/Persian normalization، reject exponent/unsafe integer.
- **Regression/acceptance/gates:** digits/separators/grouping/negative/percent/2^53/scientific/correction exhaustion all exact. Financial AI: Yes؛ staging: Yes؛ production: Yes.

### GW-02 — ادعاءات تنفيذ وهمية تمر عبر البوابة / False execution claims pass gateway-wide

- **Metadata:** Gateway/AI truthfulness؛ P1؛ Confirmed runtime؛ Open؛ mocked HTTP probe؛ local؛ Deterministic.
- **Reproduction:** provider returns `Your transaction has been recorded.` أو `تم تسجيل...` عبر general chat/passive form دون local execution.
- **Expected / Actual:** block/replace قبل display؛ الفعلي HTTP 200، `claimForwarded=true; completed=true`، وregex الضيق لا يلتقط forms.
- **Evidence:** probe exit 0؛ artifact `gateway-test-summary.txt`؛ `response_parser.ts:116-122`, `routes/general_chat.ts:56`; no screenshot.
- **Impact/root/fix:** المستخدم يصدق mutation غير موجود؛ مالي وثقة، لا privacy؛ كل provider routes. policy مركزي semantic/phrase coverage مع buffering قبل irreversible stream display.
- **Regression/acceptance/gates:** passive Arabic/English/chunk split/tool clarification/general/personal claims fail unless verified receipt. Financial AI: Yes؛ staging: Yes؛ production: Yes.

### GW-03 — schema السياق يسمح بصفوف معاملات خاصة / Financial context schema forwards arbitrary private fields

- **Metadata:** Gateway/data minimization؛ P1؛ Confirmed runtime؛ Open؛ authenticated synthetic probe؛ local؛ Deterministic؛ modified client.
- **Reproduction:** أرسل `toolId=dump_transactions` وسياقًا فيه merchantName/note/amount synthetic.
- **Expected / Actual:** server allowlist exact schemas rejects unknown tool/fields؛ الفعلي HTTP 200، providerCalls=1 والحقول forwarded.
- **Evidence:** probe exit 0؛ artifact gateway summary؛ `contracts/gateway.ts:23-35`, `groq/prompts.ts:93`; no real data/screenshot.
- **Impact/root/fix:** untrusted client يرسل private transaction-like rows إلى Groq؛ privacy لكل مستخدم modified client. server-owned per-tool DTOs، reject unknown، byte/list caps، forbid IDs/notes/history.
- **Regression/acceptance/gates:** every unknown tool/key/list/row rejected before provider; approved aggregates only. Financial AI: Yes؛ staging: Yes؛ production: Yes.

### GW-04 — حدود SSE/output قابلة للتجاوز / SSE and output limits are bypassable

- **Metadata:** Gateway availability/resource bounds؛ P2؛ Confirmed runtime؛ Open؛ synthetic stream probe؛ Node local؛ Deterministic.
- **Reproduction:** multi-chunk 1.2MB SSE event و1.2M output chars مع `maxTokens=1`.
- **Expected / Actual:** cancel at per-frame/cumulative/event/output bounds؛ الفعلي accepted and forwarded.
- **Evidence:** probe exit 0؛ `aggregateSseFrame:bytes=1200083...accepted`, `forwardedChars=1200000`؛ artifact gateway summary؛ `groq_client.ts:233-314`.
- **Impact/root/fix:** memory/bandwidth/cost DoS؛ لا financial value مباشرة؛ جميع gateway users. combined frame + cumulative bytes/chars/events + JSON body response limits، cancel reader.
- **Regression/acceptance/gates:** boundary±1 tests stream/nonstream and upstream abort verification. Financial AI: Yes until hardened؛ staging: No بعد critical fixes؛ production: Yes.

### GW-05 — فصل العميل لا يلغي upstream / Client disconnect does not abort provider request

- **Metadata:** Gateway cancellation/cost؛ P2؛ Confirmed real local HTTP probe؛ Open؛ local؛ Race after body complete.
- **Reproduction:** افتح request ثم أغلق response socket بعد اكتمال body؛ راقب provider signal 120ms.
- **Expected / Actual:** signal aborted فور premature close؛ الفعلي `upstreamSignalAbortedAfter120ms=false`.
- **Evidence:** probe exit 0؛ gateway summary؛ `routes/shared.ts:99-112`; no screenshot.
- **Impact/root/fix:** provider work/cost يستمر ولا استجابة؛ all disconnects؛ no privacy addition. listen to response `close` + request `aborted`, dispose listeners.
- **Regression/acceptance/gates:** actual socket-disconnect before/after headers aborts exactly once. Financial AI: No alone؛ staging: No؛ production: Yes.

### GW-06 — Abort أثناء stream يصنف malformedSse / Mid-stream timeout is misclassified

- **Metadata:** Gateway errors/fallback؛ P2؛ Confirmed probe؛ Open؛ local؛ Deterministic on AbortError midstream.
- **Reproduction:** provider starts SSE then abort signal.
- **Expected / Actual:** typed timeout/cancel؛ الفعلي `code=malformedSse`.
- **Evidence:** probe exit 0؛ artifact gateway summary؛ `groq_client.ts:317`; excerpt `midStreamAbort:code=malformedSse`.
- **Impact/root/fix:** retry/fallback/telemetry خاطئة وقد تعرض error غير مناسب؛ no direct balance/privacy. preserve AbortError and signal reason.
- **Regression/acceptance/gates:** timeout before headers/after partial/body parse classify consistently and never duplicate output. Financial AI: No alone؛ staging: No؛ production: Yes.

### GW-07 — مرشح الهاتف يرفض مبالغ 7 أرقام / Phone heuristic rejects valid money

- **Metadata:** Gateway privacy filter/availability؛ P2؛ Confirmed probe؛ Open؛ local؛ Deterministic.
- **Reproduction:** prompt/context `1000000 LYD` أو Arabic-Indic ungrouped؛ قارن `1,000,000 LYD`.
- **Expected / Actual:** currency token يُعامل amount؛ الفعلي ungrouped rejected phone-like، grouped accepted.
- **Evidence:** probe exit 0؛ `asciiUngrouped:false`, `asciiGrouped:true`؛ `security/redaction.ts:25`; artifact gateway summary.
- **Impact/root/fix:** تحليل قيم كبيرة يفشل بلا اتساق؛ financial users؛ filter يحمي PII لكنه false positive. typed context + currency-aware tokenizer بدل 7-digit blanket.
- **Regression/acceptance/gates:** phones still blocked، money formats/digits pass only in typed amount fields. Financial AI: Yes for affected values؛ staging: No؛ production: Yes.

### GW-08 — إعدادات production لا تفشل مغلقة / Production configuration fails open

- **Metadata:** Gateway deployment/security؛ P2؛ Confirmed config probes؛ Open؛ local config parser؛ Deterministic.
- **Reproduction:** misspelled environment، HTTP staging origin، `null` production origin، HTTP/arbitrary `GROQ_BASE_URL`.
- **Expected / Actual:** startup rejection؛ الفعلي accepted، typo becomes development، server key يمكن إرساله إلى base URL غير آمن.
- **Evidence:** probes exit 0؛ artifact gateway summary؛ `config.ts:46`, `groq_client.ts:506`; no secret printed.
- **Impact/root/fix:** CORS/transport/key destination misconfiguration؛ security لكل deployment. strict enum، HTTPS exact origins، reject null، pin/allowlist official provider host، bound numeric config.
- **Regression/acceptance/gates:** production matrix rejects every unsafe/unknown value before listening. Financial AI: Yes؛ staging: Yes؛ production: Yes.

### GW-09 — JSON التالف يظهر 503 providerUnavailable / Malformed JSON maps to provider outage

- **Metadata:** Gateway error semantics؛ P3؛ Confirmed HTTP probe؛ Open؛ local؛ Deterministic.
- **Reproduction:** POST malformed JSON مع headers صحيحة.
- **Expected / Actual:** safe 400 invalid request ولا provider call؛ الفعلي 503 `providerUnavailable`, calls=0.
- **Evidence:** probe exit 0؛ artifact gateway summary؛ `index.ts:117`, `errors.ts:54`; no screenshot.
- **Impact/root/fix:** client retry/monitoring مضلل؛ لا مالي/خصوصية؛ كل malformed client. map `entity.parse.failed`/SyntaxError to 400 closed schema.
- **Regression/acceptance/gates:** malformed/truncated/deep JSON returns safe 400, zero calls/log leakage. Financial AI: No؛ staging: No؛ production: No alone.

### GW-10 — advisory مرتفع في dependency إنتاجية / Production dependency advisory

- **Metadata:** Gateway dependency security؛ P4؛ Confirmed audit؛ Open؛ `npm audit`؛ Node local؛ reachability unproven.
- **Reproduction:** `npm.cmd audit --omit=dev --json`.
- **Expected / Actual:** 0 high/critical release gate؛ الفعلي exit 1، five affected package entries، one underlying brace-expansion DoS advisory، fix 5.0.9.
- **Evidence:** command exit 1؛ artifact gateway summary؛ `package.json:33`, `package-lock.json:1700`; no exploit/log secret.
- **Impact/root/fix:** potential DoS through dependency chain؛ no demonstrated attacker-controlled glob؛ all deployments conditional. update override/lockfile without unrelated upgrades and CI audit.
- **Regression/acceptance/gates:** audit 0 high/critical + gateway 32 tests/lint/type/build pass on Node20. Financial AI: No alone؛ staging: No؛ production: Yes as dependency gate.

### GW-11 — rate limiting داخل instance فقط / In-memory rate limiting is not distributed

- **Metadata:** Gateway architecture؛ P4؛ Confirmed limitation، not runtime defect؛ Open؛ source review؛ Cloud Run multi-instance untested.
- **Reproduction:** deploy ≥2 instances and distribute same UID requests؛ كل process له Map مستقل.
- **Expected / Actual:** global quota إذا requirement إنتاجي؛ الفعلي per-instance only.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `security/rate_limit.ts:7`; artifact gateway summary؛ live load Blocked.
- **Impact/root/fix:** aggregate abuse/cost قد يتجاوز الحد؛ no direct financial/privacy؛ scaled deployments. استخدم distributed store/API Gateway quota أو وثّق multiplier.
- **Regression/acceptance/gates:** multi-instance staging load proves global threshold if adopted. Financial AI: No؛ staging: No؛ production: No alone، architectural acceptance required.

### GW-12 — diagnostics بلا operator authorization / Diagnostics lacks operator-level authorization

- **Metadata:** Gateway diagnostics/security؛ P4؛ Confirmed hardening gap؛ Open؛ source/doc audit؛ enabled staging؛ Deterministic.
- **Reproduction:** فعّل diagnostics؛ أي user صحيح Auth+AppCheck يستدعي route دون custom claim/IAM.
- **Expected / Actual:** operator-only حسب documented workflow؛ الفعلي normal authenticated user accepted subject to ordinary checks.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `routes/diagnostics.ts:19`; artifact gateway summary؛ live disabled/Blocked.
- **Impact/root/fix:** كشف readiness/model diagnostic metadata وزيادة abuse surface؛ لا secrets مثبتة؛ enabled environments. أضف custom claim/IAM/operator allowlist وkeep default off.
- **Regression/acceptance/gates:** user gets 403، operator passes، disabled always unavailable، safe schema. Financial AI: No؛ staging: No؛ production: No alone.

### AI-001 — قراءة AI قيد التنفيذ قد تنتقل من A إلى B / In-flight financial tool reads current user's scope

- **Metadata:** AI tools/owner isolation/provider privacy؛ P0؛ High confidence؛ Open؛ concurrency source audit؛ local/provider؛ Race؛ A starts request ثم B becomes current.
- **Reproduction:** أخّر model tool call بعد start under A، بدّل إلىB، ثم نفّذ read tool مثل dashboard.
- **Expected / Actual:** request carries immutable scope A and aborts on mismatch؛ الفعلي `AiToolExecutionContext.accountScope=null/verified=false`، permission policy لا يتحقق منه، وgateway يقرأ current Riverpod provider (B).
- **Evidence:** `STATIC-AUDIT` exit 0؛ `ai_tool_contracts.dart:49-64`, `ai_agent_orchestrator_impl.dart:826-832`, `governed_ai_tool_registry.dart:22-110,150-191`, `riverpod_financial_agent_data_gateway.dart:23-64`; artifact source summary.
- **Impact/root/fix:** مجاميع B قد تُرسل في session/request بدأه A؛ UI generation guard يمنع late display لكنه لا يمنع provider disclosure؛ cross-user leak لكل switch أثناء tool loop. اربط scope/epoch بالrequest/context/handler، abort/cancel، verify قبل وبعد await.
- **Regression/acceptance/gates:** delayed A→B tool test asserts zero B repo reads/provider payload and safe cancellation. Financial AI: Yes؛ staging: Yes؛ production: Yes.

### AI-002 — التقاط إيصال أثناء تبديل الحساب يخلط الصورة والسياق / Receipt capture has owner-switch TOCTOU

- **Metadata:** Receipt AI/owner privacy؛ P0؛ High confidence، currently masked by OF-010؛ Open؛ concurrency source audit؛ device/provider؛ Race.
- **Reproduction:** ابدأ camera/import تحت A، بدّل إلىB بعد image prepare أو بين repository awaits، ثم تابع remote analysis بعد إصلاح ترتيب OF-010.
- **Expected / Actual:** immutable owner session؛ cancel/delete prepared bytes on change؛ الفعلي controller لا watches scope ويعيد قراءة repositories/categories/accounts/provider عبر awaits، فيمكن جمع صورة A مع سياق B.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `receipt_providers.dart:161-264`, `analyze_receipt_image.dart:69-76`; artifact source summary؛ live device Blocked؛ current early failure OF-010 masks upload.
- **Impact/root/fix:** cross-user receipt/image/category leakage إلى provider/state؛ financial draft may attach wrong owner؛ shared-device users؛ race. bind ownerScopeId+generation، pre/post-await checks، cancel provider/upload and purge bytes.
- **Regression/acceptance/gates:** controlled switch at every await yields no upload/no B context/no retained A state; OF-010 fixed simultaneously. Financial AI: No؛ staging: Yes؛ production: Yes.

### AI-003 — الأرقام العربية المركبة/العشرية تُقصّر / Arabic decimal and compound amounts are truncated

- **Metadata:** AI local parser/financial actions؛ P1؛ Confirmed runtime probe؛ Open؛ deterministic local probe؛ local؛ Deterministic.
- **Reproduction:** parse `مصروف ١٢٫٥٠` و`مصروف خمسة وعشرين` بحساب واحد.
- **Expected / Actual:** 12.50 و25؛ الفعلي drafts بمبلغ 12 و5.
- **Evidence:** `dart run docs/qa/evidence/ai_behavior_probe.dart` exit 0؛ artifact `ai-behavior-probe-output.txt`; `financial_command_parser.dart:380-446,451-477`; no screenshot.
- **Impact/root/fix:** preview/mutation بمبلغ خاطئ إذا أكده المستخدم؛ Arabic/Libyan users؛ لا privacy؛ deterministic. normalize `٫/٬`، parse compound number grammar، exact Decimal.
- **Regression/acceptance/gates:** full Latin/Arabic/Persian digits، comma/decimal، compound words، negatives/ambiguity; exact preview and persisted amount. Financial AI: Yes؛ staging: Yes؛ production: Yes.

### AI-004 — كلمة «مصروف» تُنشئ income draft / Expense token is classified as income

- **Metadata:** AI parser/transaction type؛ P1؛ Confirmed runtime probe؛ Open؛ local؛ Deterministic؛ Arabic expense containing مصروف.
- **Reproduction:** parse أي من probe prompts `سجللي مصروف 25.50...`.
- **Expected / Actual:** `TransactionType.expense`؛ الفعلي `income` لأن `مصروف` ضمن incomeTokens.
- **Evidence:** probe exit 0؛ جميع الحالات output `type:income`؛ artifact AI probe؛ `financial_command_parser.dart:296-351` line 320.
- **Impact/root/fix:** يزيد الرصيد بدل خفضه عند confirmation؛ financial users Arabic؛ no privacy؛ deterministic. انقل token إلى expense lexicon واستخدم precedence/token boundaries/semantic tests.
- **Regression/acceptance/gates:** corpus expense/income including allowance meaning requests clarification when ambiguous; Finance Engine effect correct. Financial AI: Yes؛ staging: Yes؛ production: Yes.

### AI-005 — أوامر مالية تُرسل للمزوّد قبل التحليل المحلي / Financial extraction is provider-first

- **Metadata:** AI architecture/privacy/determinism؛ P2؛ Confirmed source + probe؛ Open؛ source audit؛ local/remote provider؛ Deterministic حسب route.
- **Reproduction:** expense route (`isDeterministic=false`) أو transfer/budget/goal؛ trace `CreateAiActionDraft`.
- **Expected / Actual:** local normalize/resolve typed args first؛ الفعلي local-first only deterministic income/expense، ثم `_draftFromAi` يرسل prompt مع account/category context قبل fallback parser.
- **Evidence:** `STATIC-AUDIT` exit 0؛ probe shows expense deterministic=false؛ `ai_intent_router.dart:124-128`, `create_ai_action_draft.dart:129-205,225-280`; artifacts source/AI probe.
- **Impact/root/fix:** provider influences extraction and receives labels unnecessarily early؛ confirmation remains a control، لذا لا unconfirmed mutation؛ all financial action users. اجعل كل supported action deterministic typed parser، provider فقط clarification غير سلطوية وبـminimal context.
- **Regression/acceptance/gates:** provider spy receives zero call for complete commands; ambiguous only bounded hints; IDs/rates re-resolved locally. Financial AI: Yes؛ staging: Yes؛ production: Yes.

### AI-006 — Flutter لا يتحقق من الأرقام المالية في model text / Client lacks numeric grounding validation

- **Metadata:** AI response safety/personal finance؛ P1؛ Confirmed source؛ Open؛ source/unit gap؛ Firebase/Groq client؛ Deterministic given model output.
- **Reproduction:** tool fact=100، model returns personal analysis containing 999؛ compose final response.
- **Expected / Actual:** reject/correct unsupported numeric claim against exact tool facts؛ الفعلي `DefaultAiAgentResponseComposer` chooses `modelText` verbatim.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `ai_agent_support.dart:95-153`, `ai_agent_orchestrator_impl.dart:634-650`; artifact source summary؛ gateway probes separately prove analogous bypass.
- **Impact/root/fix:** fabricated totals displayed؛ financial decisions/trust؛ all personal analysis providers. exact Decimal claim extractor/allowlist and fallback deterministic composer; validate before streaming/display.
- **Regression/acceptance/gates:** unsupported ASCII/Arabic/scientific/grouped values rejected; supported values/citations pass. Financial AI: Yes؛ staging: Yes؛ production: Yes.

### AI-007 — Flutter يعرض ادعاء حفظ بلا execution receipt / Client lacks false-mutation-claim validation

- **Metadata:** AI truthfulness/execution؛ P1؛ Confirmed source + gateway runtime analogue؛ Open؛ source/security؛ Firebase/general/personal؛ Deterministic given model output.
- **Reproduction:** Firebase model returns `تم تسجيل المصروف` أو passive English في general/personal turn دون local receipt.
- **Expected / Actual:** block/replace unless verified local execution result bound to command؛ الفعلي general and composer return model text directly.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `ai_agent_orchestrator_impl.dart:614-650`, `ai_agent_support.dart:137-139`; `gateway-test-summary.txt` shows actual false-claim pass; artifact source summary.
- **Impact/root/fix:** user believes mutation saved/transferred؛ financial trust؛ all provider routes؛ no privacy. centralized client policy keyed to execution receipts، buffer sensitive streams.
- **Regression/acceptance/gates:** Arabic morphology/passive/chunked claims fail; only exact verifiedSucceeded command can state success. Financial AI: Yes؛ staging: Yes؛ production: Yes.

### AI-008 — reconciliation يعلن نجاحًا دون مقارنة الحالة كاملة / Reconciliation verifies incomplete business state

- **Metadata:** AI durable execution/idempotency؛ P1؛ Confirmed source؛ Open؛ source/test-gap؛ local restart؛ Deterministic with crafted row.
- **Reproduction:** بعد crash أنشئ transaction/transfer بنفس IDs/amounts لكن pending/wrong date/note/income source أو wrong status/rate metadata؛ reconcile.
- **Expected / Actual:** compare complete normalized command/business effect؛ الفعلي transaction check omits status/date/note/income fields، transfer omits status/date/category/payment/rate consistency ثم returns verifiedSucceeded.
- **Evidence:** `STATIC-AUDIT` exit 0؛ 76 reconciliation tests Pass لكن negative fields غائبة؛ `durable_ai_action_bridge.dart:402-461,538-545`; artifacts AI/source summaries.
- **Impact/root/fix:** UI may claim confirmed wrong/pending operation؛ may suppress needed recovery؛ all crash recovery؛ financial integrity. canonical operation fingerprint + complete row/effect verification.
- **Regression/acceptance/gates:** mutate every field one-at-a-time ⇒ inconsistent/manual review; exact state succeeds once. Financial AI: Yes؛ staging: Yes؛ production: Yes.

### AI-009 — عبارات الإيصال المطلوبة لا تُوجّه ولا تفتح scanner / Receipt intent phrases and navigation fail

- **Metadata:** AI routing/receipt UX؛ P2؛ Confirmed runtime/source؛ Open؛ local probe؛ Deterministic.
- **Reproduction:** route `Scan this receipt` و`امسح هذه الفاتورة`؛ وكذلك recognized `scan receipt` ثم inspect response.
- **Expected / Actual:** `receiptAction` ثم approved `/receipts/scan` navigation؛ الفعلي المثالان `generalConversation`، والreceipt response الآخر `kind=navigation` بلا `navigationPath/tool` فلا تجتاز UI policy.
- **Evidence:** probe exit 0؛ artifact AI probe؛ `ai_intent_router.dart:409-416`, `ai_agent_orchestrator_impl.dart:566-573`, `ai_assistant_screen.dart:418-431`.
- **Impact/root/fix:** المستخدم لا يصل للماسح وقد يسمع “Opening” كاذبة؛ no financial mutation/privacy؛ Arabic/English receipt users. phrase grammar + deterministic approved navigation result.
- **Regression/acceptance/gates:** exact required phrases/mixed wording navigate once; no implicit transaction creation. Financial AI: No؛ staging: No؛ production: Yes.

### AI-010 — «افتحلي التقارير» لا تُعرف كتنقل / Libyan fused navigation verb is missed

- **Metadata:** AI localization/navigation؛ P2؛ Confirmed probe؛ Open؛ local؛ Deterministic؛ Libyan dialect.
- **Reproduction:** route `افتحلي التقارير`.
- **Expected / Actual:** `appNavigation/navigate_reports`؛ الفعلي `generalConversation` لأن verb matcher يحتاج token `افتح` منفصلًا.
- **Evidence:** probe exit 0؛ artifact AI probe؛ `assistant_navigation_policy.dart:72-93,95-123`.
- **Impact/root/fix:** navigation dialect requirement fails؛ no financial/privacy؛ Libyan Arabic users. normalize clitics/fused forms with bounded explicit verb rules.
- **Regression/acceptance/gates:** `افتح`, `افتحلي`, English valid; ambiguous/non-verbs/admin/URL remain blocked. Financial AI: No؛ staging: No؛ production: Yes.

### AI-011 — grounded current text يظهر قبل تحقق المصادر / Grounded text streams before source verification

- **Metadata:** AI current knowledge/truthfulness؛ P2؛ Confirmed source؛ Open؛ streaming source audit؛ Firebase؛ Deterministic when first chunks lack sources.
- **Reproduction:** stream current-knowledge text chunks ثم end بلا grounding sources/error.
- **Expected / Actual:** buffer until source metadata valid أو label pending غير ظاهر؛ الفعلي partial answer yielded lines 137-151، ثم final failure after source check 586-600.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `ai_agent_orchestrator_impl.dart:84-164,586-611`, `firebase_ai_agent_model_gateway.dart:197-233`; artifact source summary؛ live blocked.
- **Impact/root/fix:** unsupported current fact flashes/يُقرأ قبل replacement؛ guidance trust، no private data. buffer grounded route or stream only verified segments with sources.
- **Regression/acceptance/gates:** no source ⇒ zero answer text ever; sources ⇒ text and citations atomically valid. Financial AI: No؛ staging: Yes for current-web feature؛ production: Yes.

### AI-012 — Firebase يبدأ fallback بعد partial output / Cross-model fallback can occur after emission

- **Metadata:** AI provider routing/streaming؛ P2؛ Confirmed source؛ Open؛ failure-injection؛ Firebase؛ Race/error after partial.
- **Reproduction:** primary emits chunk ثم throws؛ fallback configured.
- **Expected / Actual:** propagate safe failure/no fallback after any emission؛ الفعلي `yield* primary` داخل catch ثم `yield* fallback` بلا emitted guard.
- **Evidence:** `STATIC-AUDIT` exit 0؛ `firebase_ai_agent_model_gateway.dart:183-194`; artifact source summary؛ explicit required test missing.
- **Impact/root/fix:** نص متداخل/متناقض، duplicate claims، extra provider use؛ all streaming users. track emitted flag and fallback only before first yield; reset session safely.
- **Regression/acceptance/gates:** errors before output may fallback once؛ after output never cross-model; cancellation respected. Financial AI: No alone؛ staging: No؛ production: Yes.

### AI-013 — سؤال مالي عام يقرأ بيانات شخصية / Generic financial concepts route to personal analysis

- **Metadata:** AI routing/data minimization؛ P1؛ Confirmed runtime probe/source؛ Open؛ local probe؛ Deterministic؛ سؤال مثل cash flow.
- **Reproduction:** route `What is cash flow?`.
- **Expected / Actual:** generalConversation بلا private tools؛ الفعلي `personalFinancialAnalysis`, `financialPipeline=true` لأن broad topic/question lists.
- **Evidence:** probe exit 0؛ artifact AI probe؛ `ai_intent_router.dart:217-222,334-374`; no real provider call.
- **Impact/root/fix:** مجاميع شخصية قد تُقرأ وتُرسل دون حاجة لسؤال تعليمي؛ privacy/cost؛ all concept questions. distinguish possessive/personal signals from concept definitions; default general/no tools.
- **Regression/acceptance/gates:** concept corpus triggers zero tool/provider financial context؛ “my spending” remains personal. Financial AI: Yes؛ staging: Yes؛ production: Yes.

## 28. Security and privacy findings

- أعلى المخاطر: cross-user races `AI-001`, `AI-002`, `OF-006`, `OF-009`؛ resurrection/identity deletion `OF-007/008/012/036`؛ global consent/defaults `OF-014/021`؛ retained/tombstone/queue data `OF-013/017/018/029/030/038`؛ gateway context/config `GW-03/GW-08`.
- الضوابط الجيدة المثبتة: لا Groq secret في Flutter؛ gateway secret-scan Pass؛ لا tracked secret-shaped credential file؛ Firebase client identifiers فقط في config المعتاد؛ fixed routes/models؛ strict schemas؛ CORS/no-store؛ Firestore local cross-user rules Pass؛ receipt path containment/re-encoding.
- لم يُثبت live: token signature/revocation/audience، App Check، ingress، deployed rules، device at-rest/backup protection.

## 29. Financial-integrity findings

- P0 ledger/balance: `OF-001..005`.
- تقارير/تصنيف: `OF-023..025`, `OF-039`, `OF-042`.
- pending/goals/references: `OF-022`, `OF-031..033`, `OF-040/041`.
- AI financial correctness: `AI-003..008`, `AI-013`, `GW-01/02/07`.
- ضوابط ناجحة: Decimal في core money، posted effects ضمن Drift transactions، pending عادة لا يؤثر balance، reversal قبل normal update/delete، goal contribution atomic، budget progress يبرز missing-rate partiality. هذه الضوابط لا تعالج المسارات البديلة المذكورة.

## 30. Localization, RTL, responsive, and accessibility findings

- 44 widget tests RTL/responsive نجحت، بما فيها AI assistant، transaction form، receipt capture/review، وsettings layouts.
- runtime probe أكد فشل Arabic-Indic decimal/compound words (`AI-003`)، misclassification لكلمة مصروف (`AI-004`)، `افتحلي` (`AI-010`)، وعبارة الفاتورة (`AI-009`).
- لم تُرصد assertion failure في RTL، لكن لا حكم Pass للـscreen reader، keyboard focus، 320px physical device، large text، contrast، landscape، أو streaming visual stability لأنها Blocked/Not executed.

## 31. Flaky tests

- لا test assertion flaky ثبت بعد إعادة التشغيل؛ كل suites ذات العد اجتازت.
- لوحظ Drift warning عن multiple `AppDatabase` instances تشترك في `QueryExecutor` في owner/widget tests؛ لم يفشل test، لكنه قد يخفي race ويجب تنظيف lifecycle.
- Firestore wrapper خلّف emulator على port 8080؛ rerun فوري فشل بسبب port occupied. شُغّل inner suite على نفس emulator (39/39)، ثم أُوقفت فقط العمليات التي بدأها التدقيق وثبت تحرير المنفذ. هذا operational harness issue وليس rules failure.
- Android emulator command عاد 0 لكن adb لم ير الجهاز؛ صُنّف Blocked لا flaky pass.

## 32. Missing test coverage

- A(permissive/safe)→B(conservative/unsafe) مع delayed Riverpod loads، in-flight AI tool، receipt capture، deletion Auth، وsync/deletion interleavings.
- guard-enabled receipt persistence/confirmation، parent/items/splits atomicity، metadata/file cleanup failure، consent switch، FX consistency، negative split properties.
- account/category reference deletion، opening ledger، repository protected-field update، transfer rate/amount، reused group/concurrency.
- backup initial snapshot، opt-out cancel، atomic outbox، tombstone field purge، raw UID/payload retention، unknown cloud subcollection.
- exhaustive `IncomeSourceType` + null، dated FX mutation، timezone boundaries، minor-unit rounding، goal ledger protection، invalid pending repository writes.
- numeric grounding/false claims على Flutter لكل providers، full Arabic dialect corpus، receipt/label/note indirect prompt injection، prompt size/deep nesting end-to-end.
- Firestore list/collection-group/batch/transaction، deployed parity، real Auth revoked/audience، valid/invalid App Check.
- authentic v8-v15 database fixtures؛ current migration tests ليست schemas تاريخية كاملة.
- Android/iOS/device camera/gallery/background/restart/accessibility and production Node20 container.

## 33. Commands executed with exit codes

كل الأوامر من الجذر إلا إذا ذُكر غير ذلك. التفاصيل sanitized في `docs/qa/evidence/`.

| الأمر | exit | النتيجة |
|---|---:|---|
| `git rev-parse --show-toplevel` / branch / HEAD / status / diff / untracked | 0 | baseline captured |
| `flutter --version`, `dart --version`, `flutter doctor -v`, `flutter devices`, `flutter emulators` | 0 | env captured؛ doctor warning للـWindows toolchain |
| `java -version`, `node --version`, `npm.cmd --version` | 0 | env captured |
| `npm --version` | 1 | PowerShell execution policy؛ `npm.cmd` بديل ناجح |
| `flutter analyze --no-pub` | 0 | No issues؛ 330.4s analyzer |
| `flutter test --no-pub -r expanded` | 0 | 517 Pass |
| focused owner scope | 0 | 3 Pass |
| focused finance/transactions/reports | 0 | 44 Pass |
| focused receipts | 0 | 34 Pass |
| focused migrations | 0 | 11 Pass |
| focused deletion | 0 | 10 Pass |
| focused backup/sync | 0 | 15 Pass |
| focused auth domain | 0 | 3 Pass؛ ليس live Auth |
| all AI assistant focused | 0 | 304 Pass |
| AI intent/parser/routing/runtime subset | 0 | 42 Pass |
| AI tools/policy/flags subset | 0 | 32 Pass |
| AI execution/durable/reconciliation subset | 0 | 76 Pass |
| AI memory/provider/gateway subset | 0 | 32 Pass |
| RTL/responsive focused batch | 0 | 44 Pass |
| `flutter build web --no-pub` | 0 | Pass |
| `flutter build apk --debug --no-pub` | 0 | Pass |
| `flutter build windows --debug --no-pub` | 1 | Blocked: no suitable VS toolchain |
| `flutter test ...ai_navigation_device_regression_test.dart -d chrome` | 1 | Blocked before tests: web integration unsupported |
| `flutter emulators --launch Pixel_6` | 0 | launch initiated؛ device لم يسجل |
| `flutter devices --device-timeout 60` | 0 | no Android target |
| bounded `adb devices -l` polling | 2 | no registered emulator/device |
| bounded `flutter run -d web-server ... --release` | served | HTTP 200؛ browser interaction Blocked؛ process cleaned |
| Browser runtime bootstrap/list | tool success | 0 browser backends؛ Blocked |
| `npm.cmd test` في gateway | 0 | 32 Pass |
| gateway `lint`, `typecheck`, `build`, `secret-scan` | 0 لكل منها | Pass |
| `npm.cmd audit --omit=dev --json` في gateway | 1 | advisory findings: 5 affected high entries، 0 critical |
| `npm.cmd ls brace-expansion minimatch --omit=dev --all` | 0 | production chain confirmed |
| `npm.cmd run test:firestore-rules:emulator` | 0 | wrapper Pass؛ stdout counts unavailable |
| inner `npm.cmd run test:firestore-rules` على emulator | 0 | 39 Pass |
| `npm.cmd test` في `tools/groq_evaluation` | 0 | 16 Pass |
| `dart run docs/qa/evidence/ai_behavior_probe.dart` | 0 | synthetic observations captured |
| `dart analyze docs/qa/evidence/ai_behavior_probe.dart` | 0 | No issues found |
| `git diff --check` | 0 | no whitespace errors؛ CRLF warnings only |
| sanitized secret filename/content scans | 0 | no credential files؛ only expected Firebase client config matches |

## 34. Repository files changed by the audit

التدقيق لم يغيّر product source، config، tests، dependencies، أو بيانات خارجية. أنشأ فقط:

- `docs/qa/CASHPILOT_FULL_QA_REPORT_AR.md`
- `docs/qa/CASHPILOT_FINDINGS.csv`
- `docs/qa/evidence/` (ملخصات sanitized وprobe محلي اصطناعي)

أوامر البناء حدّثت ignored `build/`; gateway build حدّث timestamps لملفات `dist` التي كانت untracked أصلًا لكن aggregate hash بقي نفسه؛ emulator حدّث ignored debug logs. لا content tracked غير متعلق بالتدقيق عُدّل. المقارنة النهائية موثقة في `git-status-after.txt`.

## 35. Recommended repair order

| المرحلة | defects | لماذا أولًا / modules | الاختبارات المطلوبة / exit criteria |
|---|---|---|---|
| 1 Cross-user isolation | `AI-001/002`, `OF-006/008/009/014/021/031/032` | يمنع disclosure/authorization bypass؛ owner scope, AI providers, receipts, deletion, DB triggers | كل A→B interleavings zero cross-read/write؛ health fail closed |
| 2 Duplicate/unconfirmed mutations | `OF-005`, `AI-007/008`, `GW-02`, `OF-016` | يمنع success كاذب/duplicate؛ durable bridge, gateway, UI | exactly-once + complete state fingerprint + no unverified claim |
| 3 Ledger/Finance Engine | `OF-001..004`, `OF-019/020/022/033/040/041/042` | يصلح المصدر المالي الأساسي | balance conservation/property tests، no direct protected writes |
| 4 Confirmation/reconciliation | `AI-005/008`, `OF-011/015/016` | يثبت preview→proof→execution→recovery | guards-on crash matrix لكل action |
| 5 Auth/App Check/gateway | `GW-04..012`, `OF-006/008/012/036` | يقفل deployment boundary | Node20، live staging token/AppCheck/CORS/ingress tests، audit clean |
| 6 AI minimization/privacy | `GW-03`, `AI-001/002/005/013`, `OF-013/014/030` | يقلل provider/local exposure | provider spies exact schema، scope epoch، deletion keys absent |
| 7 Hallucinations/claims | `GW-01/02`, `AI-003/004/006/007` | يمنع أرقام/تنفيذ وهمي | Arabic/English numeric and claim adversarial corpus |
| 8 Build/test blockers | `OF-044/045` + platform prerequisites | يجعل green signal ممثلًا للإنتاج | guards-on suite، authentic migrations، Windows/Android/iOS CI |
| 9 Receipt safety | `OF-010..020`, `OF-034/035`, `AI-002/009` | يعيد flow ذريًا وآمنًا | synthetic corpus، failure injection، retention، duplicate confirmation |
| 10 Backup/deletion | `OF-007/012/013/026..030/035..038` | يحقق consent/completeness | snapshot/opt-out/fence/recursive delete، zero remnants |
| 11 Localization/RTL | `AI-003/004/009/010` | يدعم السوق العربي/الليبي | dialect/digits/plurals/goldens |
| 12 Responsive/accessibility | coverage gaps | runtime غير منفذ | devices + screen reader + keyboard + large text |
| 13 Docs/CI | `OF-034/043/045`, `GW-10/11/12` | يمنع drift ويثبت gates | docs match behavior؛ automated dependency/security/release matrix |

لا تنتقل مرحلة إلى التالية إذا بقي P0 من المرحلة، أو إذا كانت suite المرتبطة لا تعمل production guards. جميع P0 وP1 يجب إغلاقها أو قبول استثناء موثق من مالك المخاطر قبل staging؛ لا استثناء لـcross-user/direct balance/duplicate/unconfirmed mutation.

## 36. Regression-test plan

1. أضف deterministic concurrency harness مع scope epoch لكل A→B await boundary، deletion/sync، confirmation، وprovider stream.
2. شغّل Drift production guards افتراضيًا، وأضف repository-boundary malicious inputs وauthentic migration DBs.
3. أنشئ Finance Engine property suite: sum conservation، posted once، pending zero effect، reverse-before-change، transfer pair exactly two، currency minor units.
4. أنشئ AI adversarial golden corpus عربي/ليبي/إنجليزي: digits/separators/compound words، false claims، unsupported numbers، ambiguous actions، prompt injection labels/receipts.
5. استخدم provider spies لتأكيد exact minimized payload وzero tokens/UID/paths/unrelated records؛ اختبر source verification قبل أول streamed byte.
6. Receipt integration مع صور اصطناعية فقط، production guards، file/DB/provider failure injection، duplicate/restart/retention choices.
7. Backup/deletion emulator acceptance: mature snapshot، opt-out during upload، outbox fault، minimal tombstone، unknown child collection، recursive proof، no resurrection.
8. Live staging: Firebase Auth revoke/audience، App Check valid/missing/invalid، deployed rules، gateway CORS/HTTPS/Node20، Groq model evaluation، cleanup verification.
9. Device matrix Android/iOS/web/Windows + RTL/LTR/themes/320px/tablet/desktop/large text/keyboard/screen reader/background/restart.

## 37. Remaining unknowns and limitations

- لا live model call؛ جودة/availability/current model behavior غير معروفة.
- لا Firebase staging identity أو App Check؛ implementation static لا يساوي acceptance.
- لا real device أو browser backend؛ UI/camera/accessibility/background unknown.
- لم تُثبت deployed rules أو Cloud Run configuration أو distributed rate behavior.
- local Node 26 لا يطابق production Node20.
- المصدر كان dirty على نطاق واسع قبل التدقيق؛ النتائج تصف commit + working tree الحالي، وليست commit نظيفًا reproducible دون حفظ تغييرات المستخدم.
- السباقات عالية الثقة تحتاج tests controlled لإثبات interleaving runtime؛ صُنفت بوضوح ولم تُعرض كـlive exploit.
- `OF-043` risk مشروط بتهديد الجهاز وسياسة OS؛ لم يُثبت تسريب.
- التقرير لا يدعي اكتشاف كل عيب ممكن؛ يغطي كل ما لوحظ في النطاق المنفذ.

## 38. Final release recommendation

**Financial AI: DO NOT ENABLE. Staging: NO-GO حاليًا. Production: NO-GO.**

أعد القبول فقط بعد: إغلاق P0/P1، تشغيل guards في الاختبارات، نجاح كل regressions المقترحة، `flutter analyze` وfull/focused suites وbuilds، gateway audit بلا high/critical، ثم live isolated staging على Firebase/App Check/Gateway/Groq وأجهزة Android/iOS مع إثبات cleanup وعدم تسرب أو duplicate/incorrect balance. نجاح 604 حالة حالية قيمة، لكنه لا يتغلب على العيوب المصدرية الحتمية وغياب القبول الحي.
