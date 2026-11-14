# Sanitized cleanup evidence

Captured: 2026-08-19 (Africa/Tripoli)

- Acceptance-owned local account scopes removed: 2.
- Acceptance-owned local accounts remaining: 0.
- An older unrelated local synthetic fixture was positively verified and
  preserved.
- Synthetic Firebase Auth users remaining: 0.
- Synthetic cloud user profiles remaining: 0.
- Acceptance receipt files: none.
- Full application-data clear: not used.
- Existing App Check debug registration: preserved.
- Temporary Unicode input method: restored to the system IME and uninstalled.
- Temporary screenshots, UI dumps, database copies, and credential-bearing
  coordinates: removed.
- Android logcat buffer used during acceptance: cleared after verification.

The live account-deletion flow retained its secure quarantine during cleanup.
The application failed closed. Cleanup was completed for the two exact
acceptance scopes using the production scoped table order, followed by removal
of the single operation/quarantine keys and their owned preferences. The
account-deletion secure-storage namespace alone was reinitialized. A final
launch reached the signed-out surface successfully.
