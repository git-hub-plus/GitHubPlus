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
| `src/main/git/diff.ts`, `diff-parser.ts`, `patch-formatter.ts` | `app/src/lib/git/diff.ts`, `app/src/lib/diff-parser.ts`, `app/src/lib/patch-formatter.ts` | Plain-data diff output |
| `src/main/git/commit.ts`, `apply.ts`, `update-index.ts` | `app/src/lib/git/{commit,apply,update-index}.ts` | Partial commits, discard lines |
| `src/main/git/status.ts`, `status-parser.ts` | `app/src/lib/git/status.ts`, `app/src/lib/status-parser.ts` | |
| `src/main/git/rev-list.ts`, `rev-parse.ts`, `in-progress.ts` | `app/src/lib/git/{rev-list,rev-parse,merge,rebase,cherry-pick,stash}.ts` | Ahead/behind, in-progress detection, stash count |
| `src/main/git/log.ts`, `git-delimiter-parser.ts` | `app/src/lib/git/{log,git-delimiter-parser}.ts` | |
| `src/main/git/discard.ts` | `app/src/lib/git/{checkout,reset}.ts` | File discard |
| `tests/main/git/*` | `app/test/unit/**` | Converted to Vitest |
| `src/main/git/branch.ts`, `for-each-ref.ts`, `checkout.ts`, `remote.ts`, `config.ts` | `app/src/lib/git/{branch,for-each-ref,checkout,remote,config}.ts` | |
| `src/main/git/fetch.ts`, `pull.ts`, `push.ts`, `clone.ts` | `app/src/lib/git/{fetch,pull,push,clone}.ts` | No trampoline; credential helper handles auth |
| `src/main/git/progress/*` | `app/src/lib/progress/*` | |
| `src/main/git/identity.ts` | (written for GitHub+) | Identity setup replaces upstream's welcome-flow git config |
| `src/main/git/merge.ts`, `conflicts.ts` | `app/src/lib/git/{merge,checkout}.ts`, `app/src/models/manual-conflict-resolution.ts` | |
| `src/main/git/stash.ts`, `revert.ts`, `reset.ts`, `tag.ts` | `app/src/lib/git/{stash,revert,reset,tag}.ts` | |
| `src/main/git/cherry-pick.ts`, `rebase.ts`, `squash.ts`, `reorder.ts` | `app/src/lib/git/{cherry-pick,rebase,squash,reorder}.ts` | Non-interactive rebase via generated todo |
