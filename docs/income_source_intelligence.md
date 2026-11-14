# Income Source Intelligence

CashPilot models the origin of an inflow separately from its destination
account. AI and local parsing may prepare an editable suggestion, but only an
explicit confirmation can call the normal transaction application use case.

## Source taxonomy

Supported source types are salary, freelance, business revenue, gift,
allowance, refund, sale, rental income, government support, scholarship,
investment return, reimbursement, prize, loan proceeds, external transfer, and
other. The structured AI transport accepts only known enum values and keeps
amounts/rates as strings until strict `Decimal` parsing.

Resolution priority is:

1. explicit user source, category, payee, or account;
2. trusted local user rule;
3. resolved payee and its defaults;
4. exact Arabic, English, or Libyan income phrase;
5. a strong structured AI suggestion;
6. local language parsing;
7. user clarification.

An ambiguous account stays unresolved. CashPilot does not invent an account,
currency, amount, rate, or transaction date. A uniquely resolved account may
supply its currency only where the existing account-resolution policy
considers that safe.

## Financial semantics

- Salary, freelance work, business revenue, rent, and similar earned inflows
  are normal income.
- Gifts, refunds, reimbursements, sales, scholarships, prizes, and support
  remain separately classified.
- Loan proceeds are liability-related cash inflow and are excluded from
  earned-income reporting.
- A transfer between the user's own accounts is a transfer, never income.
- An ambiguous external transfer requires clarification.
- Cancelled entries do not contribute to reporting; pending behavior follows
  the existing report policy.

The income confirmation card exposes source type, source/payee, destination
account, category, date, and description as draft-only edits. It highlights
loan, refund, reimbursement, and ambiguous-transfer semantics. Editing does not
touch Drift or balances.

## Boundaries and verification

The resolver and report policy live in `lib/features/income_sources`. The AI
schema extension is optional and backward compatible. Firebase receives only
the minimized allowlisted AI context; it does not receive balances, IDs,
transaction history, user profile data, or credentials.

Focused Arabic/English/Libyan, priority, reporting, confirmation, and privacy
coverage is in `test/features/ai_assistant`.

Full liability-ledger accounting for loans is intentionally deferred. Until a
liability domain is introduced, CashPilot preserves `loanProceeds` as typed
metadata and excludes it from earned-income summaries.
