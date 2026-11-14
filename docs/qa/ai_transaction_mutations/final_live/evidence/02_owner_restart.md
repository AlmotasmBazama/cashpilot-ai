# Sanitized owner and restart evidence

Captured: 2026-08-19 (Africa/Tripoli)

- User B started with no records, then received a distinct synthetic account
  and posted expense through the real UI.
- User B did not display User A conversation state, draft, preview, Undo, or
  transaction candidates.
- The cross-owner replay path is rejected by the automated owner-bound suite.
- Switching back to User A restored the expected 3470.000 LYD aggregate and
  the expected transaction count.
- The Flutter tool was detached before force-stop.
- Process absence was verified after force-stop; launcher reopen produced a
  different process (`changed=true`). Exact process identifiers are omitted.
- No update, delete, Undo, or transfer cancellation replayed after reopen.
- Consumed and unsupported Undo paths remained unavailable.
- A scoped read-only balance request returned 970.000 LYD without mutation.
- Groq Staging and App Check remained operational after restart.
