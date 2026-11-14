# Libya-First Localization

Last registry verification: 2026-08-18.

## Locale and money

- Default locale/currency/timezone: `ar-LY`, `LYD`, `Africa/Tripoli`; explicit
  user settings remain authoritative.
- LYD is represented with `Decimal`/decimal strings, never binary floating
  point, with at most three fractional digits (1 dinar = 1,000 dirhams).
- Recognized currency labels include `دينار ليبي`, `دينار`, `دنانير`, `د.ل`,
  `ل.د`, and `LYD`; account context may select another supported currency but
  never invents a conversion rate.
- Parsers accept Western, Arabic-Indic, and extended Arabic digits; strict `.`,
  `,`, `٫`, and `٬` forms; Arabic number words; `خمسة ونص`, `دينار ونص`, and
  `ربع دينار`. More than three decimal places and ambiguous multiple amounts
  are rejected.
- `امبارح`, `مبارح`, and `البارح` map to the previous local calendar date.

## Libyan intent/accounting rules

- Expense vocabulary includes `شريت`, `خديت`, `دفعت`, `صرفت`, `خلصت`,
  `خصموا`, `شحنت`, and `عبيت رصيد`.
- Income vocabulary includes `نزلولي مرتب`, `نزل المرتب`, `استلمت`, `جاني`,
  `دخلولي`, `حولولي`, and `قبضت`.
- Transfer/safety vocabulary includes `حولت`, `دزيت`, `بعثت`, `نقلت`, `عطيت`,
  and `سحبت`. These terms do not fall through to an expense draft.
- Cash withdrawal is bank-to-cash transfer; internal bank transfer is not
  spending; bank fee is expense; telecom top-up is telecom expense; salary is
  income. A person payment that changes accounting meaning asks one concise
  clarification.

## Banks

`LibyanBankCatalog` separates canonical display names from aliases and contains
the 26 commercial banks in the Central Bank of Libya directory checked on this
date, including National Union, Imaar, Islamic Finance, Daman Islamic, Al Seraj
Islamic, Arab Islamic Investment, Jumhouria, Commercial National, Wahda,
Sahara, Trade and Development, North Africa, Al Aman, Arab Ejmaa, Libyan
Foreign, First Gulf Libya, Waha, United, Assaray/ATIB, Mediterranean, Nuran,
Alwafa, Tadhamon, Libyan Islamic, Yaqeen, and Andalus.

Common aliases such as `الجمهورية`, `التجاري`, `الوحدة`, `الصحارى`, `شمال
أفريقيا`, `الأمان`, `السراي`, and `الإسلامي` resolve only against accounts in
the authenticated owner's data.

Primary reference: Central Bank of Libya commercial-bank directory,
`https://cbl.gov.ly/banks/`.

## Payment labels

The recognition catalog includes cash, bank transfer/IBAN/NAD, cheque, local
bank card, POS, QR, LYPay, OnePay, Moamalat, Tadawul, Sadad, Mobi Cash, Mobimal,
Edfaly, LiboPay, GPAY, RUNPAY, and existing bank products (Masrafi Pay/Yusr
Pay). Generic products map to normal ledger payment-method enums.

The Central Bank directory checked on 2026-08-18 confirms LYPay and lists
licensed/approved entities including Tadawul, Moamalat, and a RUNPAY wallet.
Other names are accepted as user-facing aliases but are not represented as a
regulatory status or integration claim. Reference:
`https://cbl.gov.ly/electronic-payment/`.

Recognition means label parsing only. CashPilot has no automatic provider/bank
synchronization unless a separate API, credentials, consent, callbacks,
reconciliation, and acceptance suite exist. Never request OTPs, passwords, full
card data, or unnecessary bank credentials.

## Categories and maintenance

Existing default category definitions keep a compact stable taxonomy for food,
restaurants, housing, utilities, telecom, fuel/transport/car, health,
education, clothing, family/support, bank fees, entertainment, work, salary,
extra income, and other. User corrections/rules may personalize mapping without
renaming canonical analytics categories.

Built-in bank/payment aliases are currently a versioned code seed with tests.
A signed remote/local alias override channel is still required to correct a
global alias without an app release; until implemented, users can still name
their own accounts/payees, but the global seed itself is release-bound.
