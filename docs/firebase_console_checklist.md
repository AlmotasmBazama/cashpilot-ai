# Firebase Console Checklist

## Current Firebase Project

- Firebase project: `cashpilot-ai-a6b49`
- Android Firebase app id: `1:102802326815:android:6c62d29c46586279841c2a`
- Current Android package name: `com.example.cashpilot_ai`
- Local Android config file: `android/app/google-services.json`
- Local FlutterFire options file: `lib/firebase_options.dart`

## Android App Registration

1. Open the Firebase Console.
2. Select project `cashpilot-ai-a6b49`.
3. Go to Project settings > General > Your apps.
4. Confirm the Android app is registered with package name:
   `com.example.cashpilot_ai`
5. Confirm the Android app id is:
   `1:102802326815:android:6c62d29c46586279841c2a`

## Debug Signing Certificates

Add or confirm these debug certificate hashes for the Android app:

- SHA-1: `43:BA:CB:C5:26:E5:C2:30:E7:EB:44:18:45:82:84:3D:FC:54:DD:23`
- SHA-256: `1B:E9:4E:AF:7A:0E:1C:4A:E3:AA:BB:03:38:3E:25:93:0B:81:81:E4:2A:44:44:75:E4:06:7B:11:3D:E6:FA:92`

To regenerate locally:

```powershell
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
cd android
.\gradlew.bat signingReport
```

## Authentication

Verified enabled:

- Firebase Authentication
- Email/Password sign-in
- Verification email send
- Password reset email send

Optional providers:

- Enable Anonymous sign-in if guest mode should create real Firebase users.
- Enable Google as a sign-in provider before using Google Sign-In.

## Firestore

Verified:

- Firestore database exists.
- Database location: `africa-south1`.
- Firestore rules are deployed from `firestore.rules`.
- Authenticated users can read/write only their own `users/{uid}` document.
- All other document access is denied by default.

## Google Sign-In

1. Confirm the Android app has the SHA-1 and SHA-256 hashes above.
2. Enable the Google provider in Authentication.
3. Download a fresh `google-services.json`.
4. Confirm the downloaded JSON contains OAuth client entries, especially a web client entry used for `default_web_client_id`.
5. Replace `android/app/google-services.json` with the fresh file.
6. Rerun:

```powershell
dart pub global run flutterfire_cli:flutterfire configure -p cashpilot-ai-a6b49 --platforms=android --android-package-name=com.example.cashpilot_ai --android-out=android/app/google-services.json --out=lib/firebase_options.dart --overwrite-firebase-options -y
```

## FlutterFire Configuration

The local command used for Android configuration was:

```powershell
dart pub global run flutterfire_cli:flutterfire configure -p cashpilot-ai-a6b49 --platforms=android --android-package-name=com.example.cashpilot_ai --android-out=android/app/google-services.json --out=lib/firebase_options.dart --overwrite-firebase-options -y
```

Run it again whenever Firebase apps, SHA certificates, or supported platforms change.

The checked-in working copy is internally aligned for Android only. iOS and Web
are not configured yet. After registering their final identifiers, run:

```powershell
dart pub global run flutterfire_cli:flutterfire configure `
  --project=cashpilot-ai-a6b49 `
  --platforms=android,ios,web `
  --out=lib/firebase_options.dart
```

Do not hand-edit or guess iOS/Web values. Review the regenerated native files
and `lib/firebase_options.dart` before claiming those platforms can initialize
Firebase at runtime.

## Firebase AI Logic and App Check — Manual Console Blockers

Repository configuration cannot prove these Console settings. Record dated
screenshots or release evidence without exposing tokens or keys:

- [ ] Firebase Console > AI Logic uses the intended Gemini Developer API
  backend and the Firebase AI Logic API is enabled for project
  `cashpilot-ai-a6b49`.
- [ ] The configured stable model is available to this project and region.
- [ ] Firebase Console > Security > App Check > Apps lists the matching Android
  application and its intended provider.
- [ ] The development device token is registered under **Manage debug tokens**,
  stored only in an ignored local/CI secret file, and revoked when no longer
  needed.
- [ ] Google Play Console > Release > App integrity > Play Integrity API is
  linked to the same Cloud project.
- [ ] The final release/Play App Signing SHA-256—not only the debug SHA—is
  registered for the Android Firebase app and Play Integrity provider.
- [ ] Firebase AI Logic baseline App Check protection shows **Enforced** and
  verified/unverified metrics are reviewed. Enforcement is never disabled to
  make a development request pass.
- [ ] Replay protection remains unenforced until limited-use tokens are enabled
  in the shipped client and metrics show enforcement will not break older
  clients.
- [ ] iOS, if shipped, has its final Firebase app, generated
  `GoogleService-Info.plist`, App Attest capability, and DeviceCheck fallback.
- [ ] Web, if shipped, has a registered Firebase Web app, reCAPTCHA Enterprise
  site key, and the exact staging/production allowed domains.
- [ ] Windows is not listed as a production Firebase target while the Flutter
  App Check SDK offers only a Windows debug provider.
- [ ] Google Cloud API key restrictions for the generated Firebase Android
  client key include only required Firebase APIs and exclude the Generative
  Language API and unrelated Google APIs.
- [ ] Firebase AI Logic quotas are deliberately set/reviewed for staging and
  production, with monitored 429/error metrics.
- [ ] Cloud Billing budgets and multi-threshold alerts notify the responsible
  recipients. Alerts are understood to notify rather than hard-cap spend.
- [ ] The live App Check and harmless structured AI diagnostics pass on a
  configured device using the commands in `docs/ai_activation.md`.
- [ ] Every exact prompt and guardrail row in `docs/manual_qa_checklist.md` has
  recorded staging evidence.

The current Android `google-services.json` has no OAuth client entries. Before
claiming Google Sign-In readiness, complete the SHA/provider steps above,
download a fresh file, verify its expected OAuth clients, and regenerate
FlutterFire configuration.

## Production Package Recommendation

Do not keep `com.example.cashpilot_ai` for production. Recommended production package name:

```text
ai.cashpilot.app
```

Only change it after confirming ownership of the `cashpilot.ai` domain and before publishing to Google Play, because Android package names are effectively permanent for an app listing.
