# دليل Android الحي المنقح

الجهاز `emulator-5554`، Pixel 6 AVD، Android 17/API 37. لم تُمسح بيانات التطبيق.

علامات المشغل النهائية:

- setup: 4 synthetic users، credentialsPersisted=false.
- C populated: accounts=1، transactions=2، receiptFixtureFiles=1.
- interrupted: forceStopped=true، authStillPresent=true، protectedPreAuthStage=true.
- C zero: cloud=true، Drift=0، receipts=0/0، AI=0، sync=0، Hive live data=0، tombstone=1، Auth absent.
- D zero: القيم نفسها.
- controls: users=2، unchanged=true قبل تنظيف fixtures.
- no resurrection: targets=2، waitSeconds=30، dataReappeared=false، workersRestarted=true.
- cleanup: controlsDeleted=2، targetAccountsDeletedByApp=2، exactSyntheticAccountsRemaining=0.
- final: interrupted=true، clean=true، controlsPreservedBeforeCleanup=true، noResurrection=true، complete=true.

لم تحفظ الأدلة البريد أو UID أو كلمة المرور أو token أو محتوى مالي/إيصال.

## بوابات الإغلاق

- Analyzer: 0 issues.
- Flutter: 1701/1701 PASS.
- Tooling: 160/160 PASS.
- Provider: 31/31 PASS؛ lint/typecheck/build/secret scan PASS.
- Firestore rules: 42/42 PASS.
- Account-deletion emulator: 2/2 PASS.
- Android debug APK: PASS.
- Web: PASS.
