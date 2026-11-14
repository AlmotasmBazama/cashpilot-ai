# Final Android live acceptance baseline

Captured: 2026-08-19 (Africa/Tripoli)

This evidence is sanitized. It contains no token, Firebase UID, owner scope,
provider response, raw prompt, real financial data, or internal database ID.

## Repository

- Branch: `codex/production-transformation`
- HEAD: `fd24526f3f21ba0e96ca73dcc4a69f5a11aed632`
- `git status --short`: 542 display lines; SHA-256
  `07f60eeff2113d30c28746a95a1fc9f7e79209cc9a963b282b0abd2fe412822b`
- `git diff --stat`: 256 lines; SHA-256
  `75cc89d76a22b65e0db56e5e1eb589028e3404126b2b9fb275ee5671ab191189`
- The worktree was already substantially dirty and was preserved.

## Android discovery

- Initially connected Android targets: none.
- Available AVDs: Pixel_6, Pixel_7_Pro, Resizable_Experimental, Small_Phone.
- Selected AVD: Pixel_6, matching prior API 37 acceptance evidence.
- The saved snapshot remained `offline`; only the two processes launched for
  this run were stopped, then the same AVD was cold-booted with
  `-no-snapshot-load`. Userdata was not cleared.
- Actual device: `emulator-5554`.
- Boot proof: ADB state `device`; `sys.boot_completed=1`.

## Device profile

- Model: `sdk_gphone16k_x86_64`
- Android: 17 / API 37
- ABI: x86_64
- Physical display: 1080×2400, 420 dpi
- `/data` storage: 5.8 GiB total, 4.3 GiB available at capture
- Airplane mode: off
- Network: one bounded connectivity probe succeeded
- Intended build mode: Flutter debug

No application data, App Check registration, existing user, or QA evidence was
deleted.
