# NOTICE

GitHub+ is an independent project. It is **not affiliated with GitHub, Inc.**
"GitHub" is a trademark of GitHub, Inc.; GitHub+ does not use GitHub logos.

## Code derived from GitHub Desktop

Parts of GitHub+ are ported or adapted from
[GitHub Desktop](https://github.com/desktop/desktop), Copyright (c) GitHub, Inc.,
licensed under the MIT License (see `LICENSE`). Every ported file keeps a header
comment naming its upstream source. The list below is updated whenever code is
ported.

| GitHub+ file | Upstream source | Notes |
| --- | --- | --- |
| `src/shared/models/status.ts` | `app/src/models/status.ts` | Status types as plain data |
| `src/shared/models/diff.ts` | `app/src/models/diff/*` | Classes replaced by plain data |
| `src/shared/i18n/index.ts` | (written for the GitHub+ fork, not upstream) | |
| `src/shared/models/diff-selection.ts` | `app/src/models/diff/diff-selection.ts` | Class replaced by pure functions |
| `src/main/git/core.ts` | `app/src/lib/git/core.ts` | Simplified (no hooks/trampoline) |
