# التقرير النهائي لإغلاق خط أساس المصدر

التاريخ: `2026-08-22`، الفرع: `codex/production-transformation`.

## الخلاصة التنفيذية

بدأ الإغلاق من `27d7ad636bb9bc5baad9c822ef6fd51e217471cb`. أضيف commit وثائقي لتقارير baseline، ثم commit مستقل لإصلاح harness فقط، ثم commit الإغلاق الوثائقي الذي يحتوي هذا التقرير. لم يحدث push أو tag أو deploy أو تعديل applicationId/signing/Play Integrity/Cloud Run أو تغيير للسلوك المالي.

**Release Source Baseline: GO.** Gate D وGate F مغلقتان. **Android Release Candidate: NO-GO** لأن هوية التطبيق النهائية والتوقيع وSHA/Play Integrity/App Check الإنتاجي والاختبار على جهاز فعلي وتهيئة build الافتراضي للطفرات لم تُغلق، ولأن تحديث supply-chain الصغير لم يُطبق في هذه المهمة.

## commits الجديدة

| # | commit | العنوان | النطاق |
|---:|---|---|---|
| 1 | `6db0e0203b837d52e08bbe694b1600206564483f` | `docs(release): finalize reproducible source baseline evidence` | عشرة مسارات تقارير فقط |
| 2 | `fb7301660f56812b8ecfb953a6f47558a6acf070` | `test(release): make committed-build smoke self-contained` | harness واختبارات regression فقط |
| 3 | commit الوثائقي النهائي الذي يحتوي هذا الملف | `docs(release): close source baseline acceptance gates` | تقارير `docs/qa/release_baseline` فقط |

العشرة المسارات المتبقية راجعت ثم التُزمت في commit الأول. لم يكن بينها product/test/service/build/localization/tool source. اجتازت scans عدم وجود أسرار أو tokens أو UIDs أو بيانات مالية خاصة، وأصبحت active tree نظيفة.

## قرار البوابات

| البوابة | الحالة | الدليل |
|---|---|---|
| A — Backup Safety | PASS | النسخة الخارجية الموثقة لم تُمس |
| B — Source Inventory | PASS | الجرد السابق كامل وunknown=0 |
| C — Commit Quality | PASS | commits منفصلة وثائق/harness، ولا refactor |
| D — Clean Worktree | **PASS** | تقارير المرحلة السابقة ملتزمة؛ active status/diff/cached/untracked صفر بعد commit النهائي؛ fresh final worktree نظيف |
| E — Fresh Reproduction | PASS | clean worktree؛ analyzer/tests/services/emulators/APK/Web |
| F — Live Committed Build | **PASS** | APK من `fb730166…`؛ auth اصطناعي مستقل؛ manual/Groq/create/update/delete/Undo/restart/cleanup مكتملة أو محسوبة بدقة |

## النتائج الآلية

- Analyzer: PASS؛ صفر issues؛ 21.2 s.
- Flutter: **1701/1701 PASS**؛ 1 min 12 s.
- Tooling: **162/162 PASS**؛ Groq evaluation: **16/16 PASS**.
- Gateway: **133/133 PASS**؛ lint/typecheck/build/secret-scan كلها PASS.
- Account deletion: **31/31 PASS**؛ lint/typecheck/build/secret-scan كلها PASS.
- Firestore rules emulator: **42/42 PASS**.
- Account-deletion emulator: **2/2 PASS**.
- Android Debug APK: PASS؛ 182,351,567 bytes؛ SHA-256 الافتراضي `3423f8292208bcd9d29f10c4715109f59311b33de40b42d7f97130f625b18f58`.
- Web: PASS؛ 50 ملفًا، 45,941,956 bytes.

## القبول الحي

- Digital Wellbeing حُدد فعليًا: `com.google.android.apps.wellbeing`، `1.43.912539612 (839927)`. أُغلقت نافذة ANR وعُمِل force-stop لهذه الحزمة وحدها. لم تُعطّل قط، وهي enabled في التنظيف، وعدد ANR matches النهائي صفر.
- أزيل اعتماد `prior_auth_state_unavailable`. يدعم harness onboarding/welcome/login/authenticated/quarantine، وينشئ مستخدمين فريدين مؤقتين، ولا يسجل credentials، واختبارات no-prior/existing/onboarding/dialog/create-failure/cleanup/restart تمر ضمن 162/162.
- الحسابان `CashRelease` و`BankRelease` أُنشئا. المصروف اليدوي المنشور 30 LYD خفّض 10000 إلى 9970 مرة واحدة.
- `how are u` سلك `directConversation` محليًا بلا gateway وبلا duplicate response.
- الطلب العربي الحقيقي أعاد HTTP 200 من revision `cashpilot-ai-gateway-staging-00005-civ`، alias `general-primary`، model `openai/gpt-oss-20b`، retries=0، وFirebase text fallback بقي معطّلًا.
- draft دخل 100 LYD أُلغي: صفر mutation. إنشاء الدخل بعد التأكيد رفع الإجمالي إلى 10070 وعدد المعاملات إلى 3 مرة واحدة.
- تحديث الدخل 100→120 بعد preview/confirm رفع الإجمالي إلى 10090؛ Undo أعاده إلى 10070. الحذف بعد preview/confirm خفّضه إلى 9970 ومعاملتين؛ Undo أعاده إلى 10070 وثلاث معاملات.
- background/resume حافظ على PID والحالة. force-stop/reopen أعطى PID جديدًا وحافظ على auth/state دون replay.
- Settings أثبت Groq، gateway available، auth ready، App Check verified، Firebase fallback disabled؛ الاختبار الحي انتقل `testing→available`.
- حذف profile وFirebase Auth للمستخدمين الاصطناعيين A وB نجح. logout داخل التطبيق أعاد `false` قبل الحذف؛ لذلك لم تُمسح package data بلا تفويض أوسع. أُبطل الحساب البعيد، أُوقفت عملية CashPilot، وبقيت البيانات المحلية owner-scoped ومحجوزة لمالك محذوف. هذا الاستثناء محسوب ومعلن.

## npm

الجذر وأداة Groq: 0 vulnerabilities. كل خدمة: 13 high في الشجرة الكاملة و5 high مع `--omit=dev`. التحقيق أثبت advisory جذريًا واحدًا في `brace-expansion 5.0.8`؛ الإصلاح `5.0.9` patch متوافق، ولم يُطبق حفاظًا على lockfiles ونطاق الإغلاق. الحزم الخمس موجودة في image الإنتاج لكن لا يوجد مسار request-controlled glob إلى الوظيفة المتأثرة؛ التصنيف: **Upgrade available with normal regression** وليس blocker لقابلية إعادة المصدر، مع منع deploy الإنتاجي حتى ترقية مستقلة واختبار شامل.

## ما بقي

التفاصيل في `REMAINING_BLOCKERS.csv` و`NPM_VULNERABILITY_TRIAGE_AR.md`. أهمها: applicationId النهائي، signing، SHA registrations، Play Integrity/App Check production، physical-device release acceptance، config إصدار واضح لميزات update/delete، وترقية `brace-expansion` المضبوطة. هذه تمنع Android RC/Production ولا تعيد فتح Gate D أو Gate F.
