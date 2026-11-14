# AI conversation memory

Conversation memory is local-only. It is never sent to Firestore or the backup
sync queue.

Defaults:

- memory is enabled for the current app session;
- persistence across restarts is off;
- at most eight recent user/assistant messages are retained;
- older turns become a bounded compact summary;
- raw tool payloads are not stored;
- active topic and period are retained for follow-ups;
- sessions expire after 12 hours;
- complex hidden reasoning is never stored.

`InMemoryAiAgentMemoryStore` is the default. A user-approved local persistence
setting can select `HiveAiAgentMemoryStore`; only sanitized messages, compact
summary, active references, period, and timestamp are serialized. The setting
key and stored memory are included in full account deletion.

The assistant app bar offers New conversation and Clear conversation. Both
clear agent memory and any pending local draft state. Account deletion also
removes memory-persistence preferences.

Do not add raw tool responses, transaction history, UID, email, phone, tokens,
prompts from other users, or model reasoning to the memory schema.
