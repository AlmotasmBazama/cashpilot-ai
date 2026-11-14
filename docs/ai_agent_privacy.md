# Financial agent privacy

## Data minimization

The baseline model request includes the current user message, guidance policy,
locale/base-currency context, and a bounded sanitized conversation summary.
Financial facts are fetched only when an allowlisted tool is requested.

Tool results contain aggregate or bounded display values. They exclude UID,
email, phone, authentication state, tokens, internal database paths, sync
payloads, notes, attachments, and raw full history. Money uses strings.
Flutter and the gateway also reject phone-shaped runs of seven or more ASCII
or Arabic digits before any provider call without echoing the blocked value.
Separate ordinary small money amounts are not rejected by a total-digit-count
rule.

No AI conversation is synced to Firestore. No prompt or AI message is added to
the backup queue. CashPilot does not log raw prompts, model responses, tool
arguments, tool results, balances, or debug tokens.

## Retention and deletion

Session-only memory is the default. Optional local persistence is stored in the
existing device-local Hive settings box, subject to platform storage
protection. Clear/New removes active memory. Full account deletion removes AI
memory and its preference keys.

Tool caches are not persisted. Cross-request financial-answer caching is
intentionally avoided until data-version metadata exists, preventing stale
balances or summaries from being presented as current.

## Security boundary

App Check remains active. The agent cannot change providers or enforcement.
Client allowlists are defense in depth, not server authorization. Firebase
rules and production attestation remain required.
