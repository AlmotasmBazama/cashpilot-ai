# Pre-change Git snapshot

Captured: 2026-08-19 (Africa/Tripoli)

This evidence is content-blind: it records the required command results as
counts and SHA-256 commitments so the hundreds of pre-existing paths can be
verified without copying potentially sensitive path content into QA reports.

| Command | Sanitized result |
|---|---|
| `git branch --show-current` | `codex/production-transformation` |
| `git rev-parse HEAD` | `fd24526f3f21ba0e96ca73dcc4a69f5a11aed632` |
| `git status --short` | 526 display lines; SHA-256 `68c44b1ef6ab0e261cbbe142ddabc04549ef5725d83b21bcceae10f9f227eee6` |
| `git diff --stat` | 252 lines; SHA-256 `ddf43265411e16242e02e1f8c37d4555c1b7ea7374dcd75fb2135836f69dcc6f` |
| `git diff --name-only` | 251 tracked paths; SHA-256 `6d2f902b152d82da983a67242f16fb221710dc28f3454543b02ede64bb08c621` |
| `git ls-files --others --exclude-standard` | 803 untracked paths; SHA-256 `753650a36781d3992b20b55c6b492c681f40ee57ee63d8f20aa707d5ef7ed0f6` |

Tracked diff summary before this sprint:

```text
251 files changed, 41743 insertions(+), 8759 deletions(-)
```

No reset, clean, restore, stash, rebase, merge, commit, push, or branch change
was performed.
