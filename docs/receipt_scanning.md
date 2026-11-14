# Receipt and Invoice Scanning

CashPilot can capture a camera image or import a user-selected receipt image,
extract a structured draft with Firebase AI Logic, and prepare one reviewed
transaction with category splits. The AI boundary is read-only: it cannot call
Drift repositories, change balances, or create a transaction. A transaction is
created only after local validation and an explicit user confirmation.

## Runtime configuration

Receipt analysis uses its independent Firebase capability. The normal debug
configuration keeps deterministic command parsing local while conversation is
`auto`; receipt vision can still use Firebase when its receipt flag, Firebase
Core, Auth, and App Check preflight are available. An explicit Firebase
conversation preference is optional, not required:

```powershell
flutter run -d <device-id> `
  --dart-define=CASH_PILOT_AI_PROVIDER=firebaseGemini
```

`localParserOnly` describes deterministic command parsing and is not a remote
receipt provider. When receipt vision is unavailable, capture/manual entry
remains usable and no image is sent remotely.

Supported receipt-specific defines:

| Define | Default | Purpose |
| --- | --- | --- |
| `CASH_PILOT_RECEIPT_SCANNING_ENABLED` | `true` | Reversible feature flag for capture and entry points. |
| `CASH_PILOT_RECEIPT_AI_MODEL` | Current configured AI model | Staging override for the bounded receipt extraction model. |

There is no Gemini API key in the app. Firebase AI Logic uses the configured
Firebase app and existing App Check setup. Android debug builds use the App
Check debug provider; Android release builds keep Play Integrity. Receipt
scanning does not change enforcement or production providers.

## Privacy and data flow

Before the first remote extraction, CashPilot explains that the selected image
is sent to Firebase AI and records the user's consent locally. The remote
request contains only:

- the prepared receipt image;
- a locale;
- a bounded set of supported three-letter currency codes;
- bounded, sanitized category descriptions;
- the fixed extraction/schema instructions.

It does not add user IDs, email addresses, phone numbers, account IDs, account
names, balances, transaction history, notes, payee history, sync payloads,
tokens, or debug secrets. Context strings resembling email addresses, tokens,
or long account-like numbers are removed before the provider call.

The original gallery asset is never modified. CashPilot decodes the selected
image in an isolate, applies orientation, limits its dimensions, re-encodes it
as JPEG to strip EXIF/ICC/text metadata, checks its size, and computes a local
SHA-256 duplicate signal. Capture shows the current preparation, draft-save,
context-load, or analysis stage. The user can cancel while any stage is busy;
the operation detaches immediately, revokes further repository/provider work,
and purges late prepared bytes. The prepared image is stored only in the app-private
`receipt_images` directory. Its path is local metadata and is not added to the
cloud sync queue.

Users must choose one of these retention options before confirmation:

- keep the prepared image locally; or
- delete the local prepared image after successful extraction and transaction
  confirmation.

Full account deletion removes receipt rows, line items, transaction splits,
receipt consent, and the private receipt image directory.

## Permissions and supported platforms

- Android declares only `android.permission.CAMERA` for receipt capture.
- iOS includes camera and user-selected photo-library usage descriptions.
- Gallery import relies on the Android system picker/iOS picker and does not
  request broad photo-library access.
- Camera permission is requested only after the user taps **Take photo**.
- The document-scanner option is shown as unavailable until a reviewed native
  scanner adapter is added.
- Receipt capture fails closed on unsupported desktop/web platforms.

## Extraction contract

Firebase AI Logic receives an inline image and a strict JSON response schema.
Money, quantities, prices, taxes, discounts, fees, and totals must be decimal
strings. The local parser rejects JSON numbers for money, exponent notation,
NaN/infinity, comma-formatted values, excessive scale, invalid currencies,
invalid calendar dates, unknown document types, and malformed line items.

Supported document semantics:

- purchase receipt: posted expense after confirmation;
- unpaid invoice or utility bill: pending expense;
- unclear or partially paid invoice: blocked until reviewed;
- credit note or refund receipt: refund income with an absolute transaction
  amount;
- payment confirmation: never creates a second transaction automatically;
- unknown document: manual review required.

The model never silently repairs arithmetic. Local validation compares item
math, item totals, subtotal, tax, discounts, fees, amount paid/due, and total
with a one-cent tolerance. Mismatches remain visible warnings. Mixed receipts
classify each item independently and produce deterministic category splits.
Fees are allocated proportionally and the final split receives the exact
decimal remainder, so split totals equal the reviewed receipt total.

Cross-currency receipts require both an explicit amount in the selected
account currency and an explicit exchange rate. CashPilot never guesses a
rate.

## Duplicate and confirmation safety

Duplicate detection uses local-only signals:

- strong: matching prepared-image hash, or matching receipt/invoice number
  with merchant and currency;
- possible: matching normalized merchant, calendar date, currency, and total.

A possible/strong match requires a separate acknowledgement. The confirmation
use case reserves one transaction ID in Drift before transaction creation.
Retries check that ID first, so a crash or metadata failure cannot create a
second transaction. Receipt metadata and category splits can be retried after
the financial transaction succeeds.

## Database

Schema v14 adds:

- `receipts`;
- `receipt_line_items`;
- `transaction_splits`;
- indexes for dates, merchant/payee, receipt/invoice numbers, image hashes,
  linked transactions, receipt items, and transaction splits.

All monetary columns are decimal text. The v14 migration checks for existing
tables before creating them and is covered from historical snapshots through
v13.

## Failure behavior and cost controls

- Only one analysis for a draft/image hash runs at a time.
- A successfully analyzed identical draft/image hash is not submitted again
  by the same use-case instance.
- Provider calls have a 30-second timeout, low temperature, structured JSON,
  bounded output, and at most two short retries for transient 5xx failures.
- Timeouts, App Check rejection, rate limiting, network loss, content
  rejection, invalid JSON, and unavailable providers return safe user-facing
  codes/messages without raw response bodies.
- Offline/provider failure leaves a local reviewable draft and never creates a
  financial transaction.
- User cancellation returns the capture UI to an idle state immediately;
  non-cooperative late preparation/provider results are discarded and cannot
  persist or cross an owner-session boundary.

## Verification

Automated coverage is under `test/features/receipts` and includes strict
parsing, invalid money/date rejection, arithmetic mismatches, mixed-category
routing, exact split remainder, duplicate signals, invoice/refund semantics,
cross-currency requirements, App Check failure mapping, bounded retries,
sanitized context, schema v14 persistence, private-file deletion boundaries,
idempotent confirmation, image preparation, and a 320 px UI smoke test.
The focused preparation/cancellation gate also covers staged UI progress,
explicit cancellation, owner switching during preparation, and late-byte
purging.

For live staging QA, use only a synthetic receipt containing fake merchant and
line-item data. Register the physical debug device's App Check token through
the secure process in `docs/ai_activation.md`, run with
`CASH_PILOT_AI_PROVIDER=firebaseGemini`, and verify:

1. the privacy disclosure appears before the first upload;
2. extracted values and line categories are editable;
3. arithmetic and duplicate warnings are not hidden;
4. no balance changes before confirmation;
5. cancel creates no transaction;
6. double confirmation creates at most one transaction;
7. local logs contain no receipt content, image bytes/path, prompt/response,
   personal data, or token.
