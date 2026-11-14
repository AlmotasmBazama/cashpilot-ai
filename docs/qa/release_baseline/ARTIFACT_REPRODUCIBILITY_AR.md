# قابلية إعادة إنتاج artifacts النهائية

## Android Debug APK

كلا الـAPK أدناه بُنيا داخل worktree نظيف عند `fb7301660f56812b8ecfb953a6f47558a6acf070` ومن ملفات ملتزمة فقط:

| الاستخدام | الأمر/الإعداد | المسار | الحجم | SHA-256 |
|---|---|---|---:|---|
| baseline الافتراضي | `flutter build apk --debug --no-pub` | `C:\Users\pixel\cashpilot_ai_release_final_reproduction_fb7301660f56\build\app\outputs\flutter-apk\app-debug-default-baseline.apk` | 182,351,567 | `3423f8292208bcd9d29f10c4715109f59311b33de40b42d7f97130f625b18f58` |
| قبول Groq والطفرات | الأمر نفسه مع `--dart-define-from-file=config/groq_staging.json` | `C:\Users\pixel\cashpilot_ai_release_final_reproduction_fb7301660f56\build\app\outputs\flutter-apk\app-debug.apk` | 182,351,567 | `694826a899f219983f93288554c9695d05eaa86ed3f1cb2e6129d4f0d90174b7` |

فحص `aapt` للنسخة المثبتة أعطى:

- package: `com.example.cashpilot_ai`.
- version: `1.0.0+1`.
- min SDK: 24؛ target/compile SDK: 36.
- `adb pm list packages` أثبت وجود حزمة CashPilot واحدة فقط.
- بعد `adb install -r` سُحبت `base.apk` وقورنت: SHA-256 المثبّت يطابق `694826…` بايتًا.

الاختلاف بين SHA الافتراضي ونسخة staging سببه dart-defines الملتزمة. البناء الافتراضي يبقي update/archive drafts مغلقة، بينما `config/groq_staging.json` يفتحها لقبول staging. لم يتغير source أو lockfile أو Cloud Run أو applicationId أو signing.

## Web

`flutter build web --no-pub` نجح خلال 68.9 s. الناتج يحتوي **50** ملفًا بإجمالي **45,941,956** bytes.

## ثوابت المصدر وملفات القفل

Git object IDs عند commit التشغيل:

| المسار | Git object |
|---|---|
| `lib` | `227acede525c094a2ae9fdd37933fa66247fcf71` |
| `android` | `04d703a7e18232577a6b618070cd2838af7e99f1` |
| `assets` | `34a348e652d63b0f579fee1bf217085972f4c6ef` |
| `config` | `96472db021674b106e57417d0d6ad1e145dc4091` |
| `pubspec.yaml` | `8e4de873eea83fad91dae07ab582c9ed749cc4ae` |
| `pubspec.lock` | `7f2f05e7aef329e3bda191c453398177a037eed7` |
| root `package-lock.json` | `3f3fd5cb237a21ffdd7e0cc71b8d662680745f0c` |
| gateway lock | `fce550fe3626ac2a02e7fb3ade332e3acc342600` |
| deletion lock | `cb2fdfbc2ecdadf80165242eb59745a79a5879b2` |
| Groq evaluation lock | `1c177f743f842d0a5f2631e0e076b25a5738f3cd` |

Commit الإغلاق النهائي وثائقي فقط. يجب أن يكون `git diff --name-only fb730166… <final> -- . :(exclude)docs/qa/release_baseline` فارغًا؛ وبذلك يبقى مصدر APK/config والـlockfiles بايتًا كما اختُبرت.

**القرار: PASS لقابلية إعادة إنتاج المصدر والمحتوى. لا تُعامل نسخة Debug/staging كتوقيع RC أو artifact متجر.**
