# Firebase Setup

CashPilot AI now initializes Firebase before the app starts and uses Firebase Authentication plus Cloud Firestore for the `users/{uid}` profile document.

## Required Firebase Services

Enable these services in the Firebase console:

- Authentication: Email/Password, Anonymous, Google, and Apple.
- Cloud Firestore: native mode.

## Runtime Configuration

The current initializer reads generated FlutterFire platform options from
`lib/firebase_options.dart` and the normal native Firebase files. It does not
read `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, or project-setting dart defines.
Run `flutterfire configure` whenever registered platforms or identifiers
change. The current generated options cover Android and Web. iOS still requires
its own registered app and generated native configuration before it is runnable.

Current local verification:

- `android/app/google-services.json` exists and matches Firebase project
  `cashpilot-ai-a6b49`, Android package `com.example.cashpilot_ai`, and the
  Android entry in `lib/firebase_options.dart`.
- The Google Services Gradle plugin is declared and applied to the Android app.
- Web has a registered Firebase app, generated options, and the required Drift
  runtime assets. Live browser AI still requires an allowed Web origin,
  authorized Auth domain, and a registered reCAPTCHA Enterprise App Check key.
- iOS has no generated FlutterFire option or `GoogleService-Info.plist`.
- The current Android release uses development identifiers/signing and is not a
  Play Integrity production release.
- Windows release is intentionally unsupported: the current Flutter App Check
  SDK exposes only a debug provider for Windows, and the initializer fails
  closed in release mode rather than activating debug attestation.

After registering any additional intended platform apps in the same Firebase
project, regenerate rather than manually inventing values:

```powershell
dart pub global run flutterfire_cli:flutterfire configure `
  --project=cashpilot-ai-a6b49 `
  --platforms=android,ios,web `
  --out=lib/firebase_options.dart
```

Review the generated project IDs, application IDs, package/bundle identifiers,
`android/app/google-services.json`, and `ios/Runner/GoogleService-Info.plist`
before committing or provisioning them in CI. The generated Firebase client API
key is a non-secret Firebase app identifier, not a Gemini Developer API key.
Restrict it to required Firebase APIs in Google Cloud Console and explicitly
exclude the Generative Language API.

Google Sign-In can also receive:

```bash
--dart-define=GOOGLE_CLIENT_ID=...
--dart-define=GOOGLE_SERVER_CLIENT_ID=...
```

Keep the normal FlutterFire platform configuration files and generated native
configuration aligned with the selected Firebase project.

For Android debug App Check, use
`node tool/register_android_app_check_debug.cjs`. The tool reads the SDK-managed
secret without printing it, validates an existing registration before creating
one, preserves a valid registration, and verifies the official token exchange
without printing the issued token. Never paste the secret into source or QA
reports, and never remove the registration as test teardown.

Firebase AI Logic provider, model, and App Check dart defines are documented in
[`ai_activation.md`](ai_activation.md).

## Firestore User Document

The auth datasource creates or updates:

```text
users/{uid}
```

Stored fields:

- `uid`
- `name`
- `email`
- `photoURL`
- `currency`
- `language`
- `country`
- `timezone`
- `createdAt`
- `updatedAt`
- `lastLogin`

## Suggested Firestore Rules

Use per-user ownership as the baseline:

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, create, update, delete: if request.auth != null
        && request.auth.uid == userId;
    }
  }
}
```

## Provider Notes

Google:

- Configure Android SHA-1/SHA-256 fingerprints.
- Configure iOS URL schemes from GoogleService-Info.plist.
- Configure web OAuth client IDs and authorized domains.

Apple:

- Enable Sign in with Apple in the Apple Developer portal.
- Add the capability to iOS/macOS targets.
- Configure the Firebase Apple provider with the service ID, team ID, key ID, and private key.

Email verification:

- Customize Firebase email templates before production launch.
- Add authorized domains for all production and staging hosts.
