# CashPilot AI

[![Source validation](https://github.com/AlmotasmBazama/cashpilot-ai/actions/workflows/ci.yml/badge.svg)](https://github.com/AlmotasmBazama/cashpilot-ai/actions/workflows/ci.yml)

<p align="center">
  <img src="assets/images/app_icon.png" alt="CashPilot AI" width="112" />
</p>

**إدارة مالية شخصية تبدأ بالعربية، وتحفظ بياناتك محليًا.**

CashPilot AI يساعد المستخدم الليبي على متابعة الحسابات والمصروفات والدخل
والميزانيات والأهداف، مع مساعد ذكي يقترح إجراءات قابلة للمراجعة. بُني باستخدام
Flutter، ويدعم العربية والإنجليزية واتجاه RTL والدينار الليبي بدقة ثلاثة منازل
عشرية.

**Arabic-first, local-first personal finance for Libya.** Track everyday money
with Flutter, precise decimal accounting, and an AI assistant whose proposals
pass through deterministic validation and confirmation rules.

[التشغيل والتطوير](#getting-started) · [حالة الإصدار](#release-status) ·
[Architecture](#architecture) · [Contributing](CONTRIBUTING.md) ·
[Security](SECURITY.md)

## ماذا يقدم التطبيق؟ / Features

| المجال | الوظائف الموجودة |
| --- | --- |
| الحسابات والحركات | حسابات متعددة، دخل ومصروفات، تصنيفات وجهات دفع، بحث وترشيح وسجل بحجم محدود |
| التحويلات | طرفان مترابطان داخل معاملة ذرية؛ التحويل بين الحسابات لا يُحسب دخلًا أو مصروفًا |
| التخطيط | ميزانيات وأهداف وتقارير ومؤشرات مالية |
| المساعد الذكي | فهم محلي للأوامر المالية، محادثة عبر مزود مهيأ، معاينة وتأكيد وفق الصلاحيات، وتتبع نتيجة الحفظ |
| الإيصالات | التقاط الصورة، مراجعة الحقول المستخرجة وتعديلها، ثم تأكيد تسجيل الحركة |
| الخصوصية | بيانات مالية محلية، عزل حسب صاحب الحساب، نسخ احتياطي اختياري إلى Firestore |
| تجربة الاستخدام | العربية والإنجليزية، RTL، الوضعان الفاتح والداكن، وتفضيلات العملة واللغة |

التعرف على أسماء المصارف ووسائل الدفع يساعد في تنظيم السجلات؛ لا يوفر اتصالًا
بالمصرف أو تنفيذ تحويل أموال خارجي. النسخ السحابي الحالي **نسخ احتياطي فقط**؛
الاستعادة والمزامنة ثنائية الاتجاه لم تُنفذا بعد.

## Release status

المشروع في مرحلة التطوير والتحقق من جاهزية الإصدار. نجاح الاختبارات وبناء APK
لا يعني اكتمال متطلبات النشر في المتجر.

| Target | Current scope | Before production |
| --- | --- | --- |
| Android | Primary exercised client; debug build and automated tests | Final application ID, release signing, SHA registrations, Play Integrity/App Check, physical-device acceptance |
| Web | Build target with bundled Drift/SQLite runtime assets | Production Firebase configuration, authorized domains, reCAPTCHA Enterprise App Check, browser acceptance |
| iOS | Flutter platform scaffold | Firebase registration and generated configuration, signing, device acceptance |
| Windows, macOS, Linux | Flutter platform scaffolds; not release-qualified | Platform integration and acceptance; Windows release currently fails closed without supported production attestation |
| Node services | AI gateway and account-deletion service with deterministic tests | Deployment configuration, credentials, attestation and rollout acceptance |

No production service is deployed by CI. Historical QA reports in
[`docs/qa/`](docs/qa/) identify their tested commit and environment; they do not
certify later changes. Cloud restore, account linking, and remaining backup work
are tracked in [the backup roadmap](docs/cloud_sync_todo.md).

## Getting started

### Requirements

- Flutter **3.41.9** with Dart **3.11.5** or a compatible Dart 3.11 SDK.
- Android SDK and JDK 17 for Android builds.
- Node.js **24** for both service development and production containers, matching
  CI. The evaluation tooling alone requires at least Node 22.18.
- JDK 21 and Firebase CLI **15.22.4** for local Firebase emulator tests.

Clone this repository, open its root directory, then run:

```sh
flutter pub get --enforce-lockfile
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter analyze --no-pub
flutter test --no-pub -r expanded
```

The repository contains Firebase client configuration for the development
project. To run against your own environment, follow
[Firebase setup](docs/firebase_setup.md), register your platform apps, and
regenerate the configuration with FlutterFire. Use a dedicated development
project and synthetic data for acceptance testing.

```sh
flutter devices
flutter run -d <your-device-id>
```

AI and cloud features require their corresponding Firebase/App Check and server
configuration. Local test suites do not need provider credentials. Keep provider
keys on the server; never put them in Flutter assets, Dart defines, or source.

### Local quality checks

```sh
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze --no-pub
flutter test --no-pub -r expanded
flutter build apk --debug --no-pub
flutter build web --no-pub
npm ci
npm run test:tools
```

On Windows PowerShell, use `npm.cmd` if execution policy blocks `npm.ps1`.
Run the following in **each** service directory:

```sh
npm ci
npm test
npm run lint
npm run typecheck
npm run build
npm run secret-scan
```

Service directories are `services/cashpilot_ai_gateway` and
`services/cashpilot_account_deletion`. The rules emulator suite also runs the
account-deletion emulator tests, so install that service's dependencies first.
With JDK 21 selected, run from the repository root:

```sh
npm install --global firebase-tools@15.22.4
npm run test:firestore-rules:emulator
```

This command targets the local `demo-cashpilot-ai` project. Live integration
scripts need a separately authorized target, synthetic accounts, and a cleanup
plan. See [CONTRIBUTING.md](CONTRIBUTING.md) for the complete workflow.

## Architecture

```text
lib/
  app/         Bootstrap, routing, and dependency composition
  core/        Database, authentication infrastructure, sync, configuration
  features/    Feature-owned domain, application, data, and presentation
  shared/      Shared value objects and design-system widgets
services/
  cashpilot_ai_gateway/       Protected AI orchestration and provider adapter
  cashpilot_account_deletion/ Authenticated account-deletion service
test/                       Unit, widget, architecture, and emulator tests
integration_test/           Explicitly configured device acceptance tests
```

| Concern | Implementation |
| --- | --- |
| UI and state | Flutter, Material 3, Riverpod, go_router |
| Local persistence | Drift/SQLite; Hive and secure storage for settings and protected state |
| Monetary values | `Decimal` and decimal strings; no floating-point financial arithmetic |
| Cloud | Firebase Authentication, opt-in Firestore backup, App Check |
| AI | Deterministic local parsing, Firebase AI, protected Node.js/TypeScript gateway |
| Service boundary | Express, Zod, Firebase Admin; credentials remain server-side |

Domain rules stay in pure Dart. Presentation renders state; application services
coordinate use cases; data adapters own persistence and external calls. Financial
mutations enforce owner scope, validation, idempotency, and transactional balance
updates. The model proposes a plan and never receives a database handle or
authority to choose an owner.

## Documentation

- [مراجعة المصدر والتحقق في 14 نوفمبر 2026](docs/qa/publication/VALIDATION_2026_11_14_AR.md)
- [Engineering guide](AGENTS.md) and [architecture rules](docs/architecture/clean_architecture_rules.md)
- [Firebase setup](docs/firebase_setup.md) and [AI activation](docs/ai_activation.md)
- [Financial agent architecture](docs/ai_financial_agent_architecture.md), [tool registry](docs/ai_tool_registry.md), and [permissions](docs/ai_tool_permission_policy.md)
- [AI privacy](docs/ai_agent_privacy.md), [conversation memory](docs/ai_conversation_memory.md), and [financial guidance](docs/ai_financial_guidance_policy.md)
- [Model routing](docs/ai_model_routing.md) and [manual AI acceptance](docs/ai_agent_manual_qa_checklist.md)
- [Receipt intelligence](docs/receipt_intelligence.md) and [receipt privacy](docs/receipt_privacy.md)
- [Income classification](docs/income_source_intelligence.md) and [owner isolation](docs/local_owner_scope_architecture.md)
- [Gateway deployment](docs/groq_gateway_deployment.md) and [rollout/rollback](docs/groq_rollout_and_rollback.md)

## Contributing and security

Contributions should include a focused explanation, relevant verification, and
synthetic reproduction data. Start with [CONTRIBUTING.md](CONTRIBUTING.md).
For suspected vulnerabilities, follow [SECURITY.md](SECURITY.md) and avoid public
reports containing credentials or financial records.

No open-source license has been selected for this repository. Publishing the
source does not itself grant a license to reuse or distribute it.
