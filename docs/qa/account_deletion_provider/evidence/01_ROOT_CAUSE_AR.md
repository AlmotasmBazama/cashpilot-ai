# دليل السبب الجذري

المصدر: أوصاف Cloud Run وIAM وCloud Logging المقيدة، 2026-08-21.

- المراجعة القديمة: `cashpilot-ai-gateway-staging-00005-civ`.
- حساب الخدمة: `cashpilot-ai-gateway-staging@cashpilot-ai-a6b49.iam.gserviceaccount.com`.
- أدواره الوحيدة: `roles/firebaseappcheck.tokenVerifier` و`roles/firebaseauth.viewer`.
- 503 المقيدة بتلك المراجعة: 1 على `/v1/account-deletion/recursive` و2 على `/v1/account-deletion/auth`.
- لا يملك الحساب دور Firestore data ولا صلاحية حذف Auth.
- أول عملية Admin بعد تحقق Auth/App Check/proof في المسار العودي هي معاملة قفل Firestore.
- mapping القديم يحول فشل Admin غير المتوقع إلى `providerUnavailable`/503.

النتيجة: كان الحذف يعمل تحت هوية Groq غير المخولة لبيانات Firestore وحذف Auth.
لم يكن السبب غياب route أو DNS أو مشروع Firebase خاطئاً في Flutter.

لم تُحفظ log entry خام أو URL يحوي query أو header أو token أو UID.

