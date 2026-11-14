# Receipt Privacy and Security

Receipt images can contain sensitive financial and identity data. CashPilot
therefore applies a narrow consent, transport, storage, and deletion boundary.

## Remote boundary

Before the first remote analysis, the user sees a receipt-specific disclosure.
The Firebase AI request contains the prepared image plus locale, supported
currencies, sanitized category descriptions, and fixed schema instructions.
It excludes UID, email, phone, tokens, account IDs/names, balances, transaction
history, notes, local image paths, sync data, and debug secrets.

Firebase AI may return only an untrusted draft. It cannot access Drift, create
transactions, or change balances. App Check remains enabled: debug providers
are non-release only, while Android release uses Play Integrity. No Gemini
Developer API key is embedded in the app.

## Local image policy

- The original gallery asset is never modified.
- The prepared copy is oriented, bounded, JPEG re-encoded to remove EXIF, and
  stored only in app-private storage under a hashed filename.
- Images, bytes, paths, and hashes are excluded from Firestore backup.
- The user chooses whether to keep the prepared image locally or delete it
  after a successful confirmed transaction.
- Failed analysis/confirmation preserves a reviewable draft where safe and
  does not prematurely delete the image.
- Full account deletion removes receipt rows, line items, splits, consent, and
  the private receipt image directory.

CashPilot logs only fixed safe event names/codes. It never logs image data or
paths, OCR/receipt text, merchant/item/receipt identifiers, Gemini prompts or
responses, monetary values, personal data, credentials, or App Check tokens.

Client concurrency, debounce, image-size, timeout, retry, and duplicate guards
reduce accidental usage and cost; they are not treated as a security boundary.
Production enforcement, provider quotas, billing alerts, and console metrics
must be reviewed before release.
