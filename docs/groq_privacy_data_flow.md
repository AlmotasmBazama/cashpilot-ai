# Groq Privacy Data Flow

## General conversation

Flutter sends the current message, at most eight recent sanitized turns, an
optional compact memory summary, locale, request ID, timeout class, and client
version. Credential-like content, email addresses, local paths, and
phone-shaped runs of seven or more ASCII or Arabic digits are rejected before
the provider call. The check operates on each bounded text value, not the
total digit count, so ordinary small finance amounts in English or Arabic stay
valid. Rejection messages never echo the blocked value. The stateless gateway
does not persist the conversation and does not log prompts or responses.

## Personal financial explanation

CashPilot first invokes only locally governed read/calculation tools. Flutter
converts successful results into no more than twelve bounded records and strips
identifiers, account data, names, notes, descriptions, merchants, payees,
transactions, receipts, file/storage paths, and tokens. It sends the base
currency, deterministic scalar/aggregate values, partial-data markers, and
explicit assumptions. Raw transaction history and unrelated accounts are not
sent.

The gateway validates that minimized shape again. The provider receives only
the bounded request plus fixed safety instructions. The response is advisory
text, post-validated for unsupported figures and false mutation claims.

## Governed tool selection

Flutter sends a bounded user question and a list of locally relevant tool IDs.
The gateway intersects those IDs with its own read/calculation allowlist.
Provider output contains only an approved name, bounded arguments, and an
optional clarification. No local tool result, token, database handle, or
mutation capability travels upstream. CashPilot validates and executes any
allowed read/calculation locally.

## Excluded flows

Financial command extraction, drafts, confirmation, and execution are local.
Receipt images and receipt JSON stay in the existing Firebase receipt pipeline.
Current web information is disabled and no current-search gateway endpoint
exists. Private financial context is never mixed with public search.

## Identity and transport

Firebase ID and App Check tokens travel only from the client to the CashPilot
gateway over HTTPS. The gateway verifies and consumes them, keeps only the
verified UID transiently for rate limiting, and never forwards identity tokens
or UID to the provider. Responses are not cacheable.
