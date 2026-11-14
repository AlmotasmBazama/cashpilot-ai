# Sanitized live mutation evidence

Captured: 2026-08-19 (Africa/Tripoli)

This file contains no raw prompts, provider output, token, UID, owner scope,
email address, database ID, or real financial data.

## Fixture

- Cash opening balance: 1000.000 LYD.
- Bank opening balance: 2000.000 LYD.
- Posted expense: 30.000 LYD from Cash.
- Pending expense: 20.000 LYD from Cash; zero balance effect.
- Posted income: 500.000 LYD to Bank.
- Posted transfer: 100.000 LYD Cash to Bank.
- Verified start: Cash 870.000, Bank 2600.000 LYD.

## Verified transitions

| Operation | Result |
|---|---|
| Posted expense update 30→50 | Cash 850.000; Bank unchanged |
| Rapid duplicate confirmation | One execution; balances unchanged after first execution |
| Update Undo | Cash restored to 870.000 |
| Second Undo | Unavailable; zero mutation |
| Posted expense delete | Cash 900.000 |
| Delete Undo | Cash restored to 870.000; one restored row |
| Pending→posted | Cash 850.000 |
| Status Undo | Pending restored; Cash 870.000 |
| Transfer cancellation | Cash 970.000; Bank 2500.000; both legs consistent |
| Existing-transfer cancellation Undo | Safely unsupported; zero mutation |
| Existing-transfer update | Safely unsupported; zero mutation |

Two balance-neutral pending ambiguity fixtures were created. Three safe choices
were displayed, a single choice was retained for one turn, and cancellation
left all records and balances unchanged.
