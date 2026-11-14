# Groq Live Acceptance

## Status

Local implementation and automated verification are prerequisites, not proof
of deployment. Record staging deployment, emulator, and physical-device
results here only after they are directly observed. Never paste tokens, UID,
private prompts, financial values, upstream bodies, or provider credentials.

## Safe staging prerequisites

- Dedicated staging Firebase/Google Cloud project confirmed.
- Official Auth and App Check verification succeeds and fails closed.
- Exact staging origins configured; wildcard CORS absent.
- Both fixed model availability states are successful through the protected
  synthetic diagnostic, which is disabled again afterward.
- All Groq flags initially off and Firebase receipt vision on.
- Test account and synthetic financial data only.

## Acceptance matrix

| Scenario | Expected result | Status |
|---|---|---|
| Arabic greeting and casual question | Natural same-language general stream; no finance tool | Pending live staging |
| English general question | Incremental text appears once; no provider branding | Pending live staging |
| Inflation/supply-and-demand explanation | General route, no repetitive disclaimer | Pending live staging |
| Capital of Tunisia | General route, no claim of live verification | Pending live staging |
| Spending explanation/comparison | Only deterministic bounded local facts reach guarded explanation | Pending live staging |
| Gift income command | Local income draft; no action before confirmation | Pending live staging |
| Restaurant budget command | Local budget draft; no action before confirmation | Pending live staging |
| Current Libya economy question | Localized honest unavailable response | Pending live staging |
| Delete-all request | Blocked by local safety policy | Pending live staging |
| Receipt image | Existing Firebase review pipeline | Pending live staging |
| Cancellation/provider failure | Loading state released; typed localized failure | Pending live staging |

## Evidence to record

Record build/revision identifiers, feature-flag stage, device/emulator identity,
safe pass/fail states, latency percentiles, duplicate-chunk count, and reviewer
language notes. Do not record raw conversation or financial content.

Physical-device testing must include Android/iOS App Check production
attestation, token refresh, poor-network cancellation, RTL narrow layout,
background/resume, receipt capture/review, and rollback without reinstalling.
