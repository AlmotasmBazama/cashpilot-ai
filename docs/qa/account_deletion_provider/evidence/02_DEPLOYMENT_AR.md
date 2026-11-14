# دليل النشر التجريبي

- المشروع: `cashpilot-ai-a6b49`.
- المنطقة: `europe-west1`.
- الخدمة: `cashpilot-account-deletion-staging`.
- المراجعة: `cashpilot-account-deletion-staging-00003-q4b`.
- الحالة: Ready + Active + ContainerHealthy.
- الحركة: 100% للمراجعة الجديدة.
- الرابط الثابت: `https://cashpilot-account-deletion-staging-yfgt2ypuvq-ew.a.run.app`.
- الصورة: `sha256:10ea2fd807a1c17ce5906256ae380d222e6880add739e240883ee10af083b938`.
- الهوية: `cashpilot-deletion-staging@cashpilot-ai-a6b49.iam.gserviceaccount.com`.
- IAM: custom Auth operator + datastore.user + App Check verifier؛ لا Owner/Editor.
- Cloud Run: 1 CPU، 512Mi، timeout 120s، concurrency 4، maxScale 2.
- مصدر النشر: `services/cashpilot_account_deletion` ببصمة
  `92c66b55a1afde5fbd95693a34cfca1a8ae98cac7391063aad8c026d445bf2ac`.

نُشر Staging فقط. لم تتغير خدمة Groq أو حركتها، ولم يُنشر Production.

