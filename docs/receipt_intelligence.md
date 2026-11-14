# Receipt Intelligence

The canonical implementation and operations guide is
[receipt_scanning.md](receipt_scanning.md). It documents the feature-first
domain/data/application/presentation layers, camera/gallery abstraction,
Firebase AI Logic multimodal contract, strict Decimal transport, arithmetic
validation, per-item categories, deterministic transaction splits, duplicate
detection, Drift schema v14, cost controls, and failure behavior.

## Safe workflow

1. Capture from the camera or select an image through the platform picker.
2. Decode, orient, bound, and JPEG re-encode the copy to strip metadata.
3. Obtain receipt-specific consent before any remote request.
4. Ask Firebase AI Logic for strict structured JSON.
5. Parse money from strings into `Decimal` and validate locally.
6. Resolve merchant and each item category conservatively.
7. Persist an editable local draft and display warnings.
8. Require account, payment status, retention choice, duplicate
   acknowledgement, and explicit confirmation.
9. Create one transaction through the existing transaction use case and
   Finance Engine, then persist receipt/split metadata idempotently.

Purchase receipts become posted expenses only after confirmation. Unpaid
invoices become pending expenses; unclear or partially paid invoices remain
blocked. Credit notes/refund receipts create typed refund inflows. Payment
confirmations and unknown documents never create a duplicate transaction
automatically. Cross-currency drafts require an explicit account amount and
exchange rate.

The document-scanner adapter, multi-page scanning, on-device OCR, receipt cloud
sync/restore, and automatic correction-memory persistence remain intentionally
deferred. The UI reports scanner unavailability instead of pretending support.
