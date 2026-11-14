# قرار الطرح النهائي لميزات Update/Delete/Undo على Android

التاريخ: 2026-08-19

## القرار النهائي

| النطاق | القرار |
|---|---|
| Debug/Profile Staging feature rollout | **GO** |
| `CASH_PILOT_AI_UPDATE_DRAFTS_ENABLED` في Staging | **APPROVED=true** |
| `CASH_PILOT_AI_ARCHIVE_DRAFTS_ENABLED` في Staging | **APPROVED=true** |
| Production feature rollout | **NO-GO / NOT APPROVED** |
| Android Release Candidate العام | **NO-GO** |

تجاوزت كل حالات mutation الحية الحرجة: update، delete، Undo، pending/posted،
إلغاء التحويل الذري، الغموض، idempotency، عزل المالك، والمصالحة بعد restart.
بقي Release مغلقًا افتراضيًا ويتطلب تهيئة واعتمادًا مستقلين.

Android RC العام ليس جاهزًا لأن هذا التشغيل Debug على محاكي، ولا يثبت توقيع
الإصدار أو SHA registrations أو Play Integrity/App Check للإنتاج أو جهازًا
فعليًا. كذلك سُجل تعثر fail-safe في إكمال حذف الحساب الحي أثناء التنظيف،
رغم نجاح اختبارات حذف الحساب الآلية واستعادة الجهاز وتنظيف النطاقين كاملًا.

## الدليل المختصر

- الجهاز: Pixel 6 AVD، Android 17/API 37، x86_64، 1080×2400، 420 dpi.
- البداية: Cash=870.000، Bank=2600.000 LYD.
- النهاية المقبولة: Cash=970.000، Bank=2500.000 LYD.
- duplicate Confirm: تنفيذ واحد.
- double Undo: لا تنفيذ ثانٍ.
- transfer cancellation: ساقان ذريتان بلا ساق ثالثة.
- transfer-cancellation Undo: رفض آمن بلا تغيير.
- owner isolation: PASS حيًا، وowner replay مرفوض آليًا.
- force-stop/reopen: process changed، ولا replay.
- read-only grounding: رصيد Cash الصحيح بلا mutation.
- analyzer: PASS.
- Flutter: 1687/1687 PASS.
- Android Debug APK: PASS.
- Web: PASS.
- Tooling: 160/160 PASS.
- Firestore: 42/42 PASS.
- Account deletion emulator: 2/2 PASS.

## حدود الطرح المعتمدة

مدعوم في Staging:

- تحديث دخل/مصروف.
- تغيير pending/posted وفق Finance Engine.
- حذف/عكس دخل أو مصروف.
- Undo لإنشاء/تحديث/حذف.
- إلغاء تحويل ذريًا.
- Undo لتحويل أنشأه AI حيث تدعمه الخدمة القائمة.

غير مدعوم ويبقى fail-closed:

- تعديل ساقي تحويل قائم.
- Undo لإلغاء تحويل قائم.
- bulk destructive actions.
- multi-step mutation plans.
- التنفيذ المدمر الفوري أو bypass للتأكيد.

## الملفات التي تغيرت في مرور القبول الحي

### مصدر التطبيق

- `lib/features/ai_assistant/application/services/ai_assistant_conversation_workflow_controller.dart`
- `lib/features/ai_assistant/application/services/ai_transaction_mutation_draft_service.dart`
- `lib/features/ai_assistant/domain/services/ai_intent_router.dart`
- `lib/features/ai_assistant/domain/services/ai_transaction_mutation_parser.dart`
- `lib/features/ai_assistant/domain/services/transaction_target_resolver.dart`
- `lib/features/ai_assistant/domain/usecases/understand_ai_message.dart`
- `lib/features/ai_assistant/presentation/pages/ai_assistant_screen.dart`
- `lib/features/ai_assistant/presentation/support/ai_assistant_workflow_composition.dart`
- `lib/features/ai_assistant/presentation/widgets/ai_action_confirmation_card.dart`

### التهيئة والـtooling

- `config/groq_staging.json`
- `tool/android_groq_staging_scenario.ps1`
- `tool/run_android_groq_staging.test.cjs`
- `tool/final_android_mutation_auth_session.cjs`
- `tool/final_android_hive_cleanup.dart`
- `tool/final_android_synthetic_cleanup.cjs`
- `tool/android_unicode_ime/settings.gradle.kts`
- `tool/android_unicode_ime/build.gradle.kts`
- `tool/android_unicode_ime/app/build.gradle.kts`
- `tool/android_unicode_ime/app/src/main/AndroidManifest.xml`
- `tool/android_unicode_ime/app/src/main/res/xml/input_method.xml`
- `tool/android_unicode_ime/app/src/main/java/com/cashpilot/qa/unicodeime/UnicodeImeService.java`
- `tool/android_unicode_ime/app/src/main/java/com/cashpilot/qa/unicodeime/UnicodeTextReceiver.java`
- `tool/android_unicode_ime/app/build/**` — مخرجات بناء أداة QA المولدة، حُفظت لأن الشجرة كانت untracked ولا يجوز تنظيفها.

### الاختبارات

- `test/features/ai_assistant/ai_assistant_send_test.dart`
- `test/features/ai_assistant/ai_environment_defaults_test.dart`
- `test/features/ai_assistant/ai_transaction_mutation_cards_test.dart`
- `test/features/ai_assistant/ai_transaction_mutation_draft_service_test.dart`
- `test/features/ai_assistant/ai_transaction_mutation_parser_test.dart`
- `test/features/ai_assistant/assistant_routing_regression_test.dart`

### التقارير والأدلة

- `docs/qa/ai_transaction_mutations/AI_TRANSACTION_MUTATIONS_REPORT_AR.md`
- `docs/qa/ai_transaction_mutations/AI_UPDATE_DELETE_UNDO_MATRIX.csv`
- `docs/qa/ai_transaction_mutations/LIVE_ACCEPTANCE_AR.md`
- `docs/qa/ai_transaction_mutations/REMAINING_LIMITATIONS.csv`
- `docs/qa/ai_transaction_mutations/FINAL_ANDROID_ROLLOUT_AR.md`
- `docs/qa/ai_transaction_mutations/final_live/evidence/00_baseline.md`
- `docs/qa/ai_transaction_mutations/final_live/evidence/01_live_mutations.md`
- `docs/qa/ai_transaction_mutations/final_live/evidence/02_owner_restart.md`
- `docs/qa/ai_transaction_mutations/final_live/evidence/03_automated_gates.md`
- `docs/qa/ai_transaction_mutations/final_live/evidence/04_rollout.md`
- `docs/qa/ai_transaction_mutations/final_live/evidence/05_cleanup.md`
- `docs/qa/ai_transaction_mutations/final_live/evidence/06_final_worktree.md`

القائمة أعلاه تخص مرور القبول الحالي؛ لا تنسب التغييرات الواسعة الموجودة قبل
baseline إلى هذا المرور. لم يتغير Gateway.
