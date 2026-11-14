# Receipt Manual QA Checklist

Use only synthetic data and the fake fixture in
`assets/test/receipts/fake_receipt.png`. Record build, device, OS, locale,
Firebase project, and tester. Never capture real payment, tax, address, or
identity data for staging QA.

- [ ] Camera permission is requested only after **Take photo**.
- [ ] Denied permission has a recoverable, localized state.
- [ ] Gallery import requests no broad photo-library permission.
- [ ] Unsupported scanner and desktop/web states fail closed.
- [ ] The privacy disclosure appears before the first remote upload.
- [ ] Declining consent sends no image and permits safe manual review.
- [ ] Purchase, unpaid/unclear invoice, refund/credit-note, payment
      confirmation, and unknown-document semantics match
      `docs/receipt_intelligence.md`.
- [ ] Merchant, dates, currency, totals, line items, categories, and retention
      choice can be reviewed and edited in English and Arabic.
- [ ] Add/edit/delete line item, arithmetic warning, duplicate warning,
      cross-currency input, retry, cancel, and explicit confirmation work.
- [ ] Milk/bread/eggs, detergent, shampoo, coffee, recharge, electricity,
      fuel, and medicine resolve conservatively or require a category choice.
- [ ] Split totals exactly equal the reviewed transaction total.
- [ ] Nothing changes a balance before confirmation.
- [ ] Double tap/retry creates at most one transaction and one balance effect.
- [ ] Image deletion happens only after successful confirmation/finalization.
- [ ] Kept images remain app-private and survive relaunch.
- [ ] Full account deletion removes receipt data, consent, and private files.
- [ ] Arabic RTL, English LTR, 320 px, large phone, tablet, focus order,
      semantics, contrast, and tap targets are manually verified.
- [ ] Logcat/Flutter output contains no receipt/image/prompt/output/personal
      data, money, path, token, or token prefix.
- [ ] Live chat and receipt smoke tests pass with App Check on the intended
      staging device without confirming or mutating financial data.

The broader product checklist remains in [manual_qa_checklist.md](manual_qa_checklist.md).
