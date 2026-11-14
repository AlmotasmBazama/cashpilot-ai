# خريطة الأسباب الجذرية لمعالجة CashPilot

## خط الأساس ومصدر الحقيقة

- الفرع: `master`.
- الالتزام: `fd24526f3f21ba0e96ca73dcc4a69f5a11aed632`.
- مصدر الحقيقة: `docs/qa/CASHPILOT_FULL_QA_REPORT_AR.md` و`docs/qa/CASHPILOT_FINDINGS.csv`.
- تم تحميل 70 سجلًا فريدًا بلا معرفات فارغة: P0=11، P1=34، P2=18، P3=1، P4=6.
- حالة Phase 0: 39 عيب P0/P1 مؤكدًا أُعيد تصنيفه `Reproduced` من دليل التدقيق، و6 سباقات/مسارات عالية الثقة بقيت `Investigating` إلى أن يثبتها harness حتمي، و25 عيبًا أقل أولوية `Not Started`.
- لا duplicate ولا invalid ولا already-fixed مثبت في baseline الحالي. لا يجوز تغيير هذا الحكم إلا بدليل اختبار أو مصدر مسجّل.
- كل أعلام Financial AI والتحكم والقراءة والتنفيذ تبقى معطلة؛ خريطة الأسباب لا تمنح إذن تفعيل.

## مجموعات السبب الجذري

| المجموعة | السبب الجذري الجامع | العيوب | P0 | P1 | أقل |
|---|---|---|---:|---:|---:|
| RCG-01 | غياب scope epoch/session ثابت عبر تبديل الحساب والعمل غير المتزامن | OF-009, OF-014, OF-021, AI-001, AI-002 | 3 | 2 | 0 |
| RCG-02 | تعدد مسارات الحذف، إعادة حل الهوية، غياب writer fence، وعدم اكتمال الجرد | OF-006, OF-007, OF-008, OF-012, OF-013, OF-035, OF-036, OF-037, OF-038 | 3 | 4 | 2 |
| RCG-03 | حالة الحساب/الرصيد قابلة للتغيير خارج دفتر محمي وحدود update ضيقة | OF-001, OF-002, OF-003, OF-033, OF-040, OF-041 | 3 | 1 | 2 |
| RCG-04 | transfer group وFX لا يملكان invariant ذريًا/idempotent واحدًا | OF-004, OF-005 | 2 | 0 | 0 |
| RCG-05 | الإيصال ليس aggregate ذريًا عبر الصفوف/الملف/التأكيد/الاحتفاظ | OF-010, OF-011, OF-015, OF-016, OF-017, OF-018, OF-019, OF-020, OF-034 | 0 | 7 | 2 |
| RCG-06 | سياسات التصنيف والزمن وFX والتقريب موزعة وغير شاملة | OF-023, OF-024, OF-025, OF-039, OF-042 | 0 | 3 | 2 |
| RCG-07 | consent/outbox/tombstone/retention للنسخ ليست boundary تنفيذية ذرية | OF-026, OF-027, OF-028, OF-029, OF-030 | 0 | 5 | 0 |
| RCG-08 | حراس UPDATE والمراجع وowner health وتغطية الاختبار غير مكتملة | OF-022, OF-031, OF-032, OF-044, OF-045 | 0 | 3 | 2 |
| RCG-09 | parser/router ليس محليًا/حتميًا وشاملًا قبل المزوّد | AI-003, AI-004, AI-005, AI-009, AI-010, AI-013 | 0 | 3 | 3 |
| RCG-10 | لا يوجد validator موحد ودقيق للأرقام/ادعاء التنفيذ/stream/reconciliation | AI-006, AI-007, AI-008, AI-011, AI-012, GW-01, GW-02 | 0 | 5 | 2 |
| RCG-11 | schemas وحدود النقل/config والـruntime في Gateway غير مقفلة بالكامل | GW-03, GW-04, GW-05, GW-06, GW-07, GW-08, GW-09, GW-10, GW-11, GW-12 | 0 | 1 | 9 |
| RCG-12 | ضمانات حماية صورة الإيصال على المنصة غير مقبولة حيًا بعد | OF-043 | 0 | 0 | 1 |
| **الإجمالي** |  | **70** | **11** | **34** | **25** |

## علاقات الاعتماد

1. RCG-01 يسبق كل قراءة AI أو receipt أو proof لأن أي اختبار مالي بعد تبديل الحساب غير موثوق قبله.
2. RCG-02 يسبق قبول deletion/backup؛ الحذف لا ينجح ما دام كاتب قديم قادرًا على الإحياء أو الهوية قابلة للتبدل.
3. RCG-03 ثم RCG-04 يثبتان ledger conservation وpair invariants قبل reconciliation أو Financial AI.
4. RCG-05 يعتمد على الحراس الفعلية في RCG-08 وعلى Finance Engine من RCG-03/04.
5. RCG-10 يعتمد على facts typed/minimized من RCG-09 وRCG-11؛ validator النصي لا يعوض scope أو schema غير موثوقة.
6. RCG-07 وRCG-02 يشتركان في deletion fence، لكن لكل منهما tests مستقلة للـconsent والديمومة.

## سياسة الإغلاق

- لا يُغلق عيب مشترك السبب تلقائيًا بإصلاح ملف واحد؛ لكل ID regression ونتيجة مستقلة في CSV.
- `Verified` يتطلب focused green، الاختبارات المرتبطة، analyzer، وعدم فتح عيب أعلى.
- ما يحتاج Firebase/App Check/Groq/device/deployed parity يبقى `Fixed Pending Live Verification` بعد النجاح المحلي.
- لا يُستخدم `Duplicate` أو `Invalid With Evidence` إلا مع رابط صريح إلى الدليل والعيب المالك.

