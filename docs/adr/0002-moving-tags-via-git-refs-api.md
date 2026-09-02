# Add Major/Minor Tag support via GitHub's git-refs API, not git CLI

We're extending the action so it can also create/move a Major Tag and Minor Tag (see `CONTEXT.md`)
alongside the Release Tag it already creates — as new `release.sh` flags (`--tag-major`,
`--tag-minor`) mirrored 1:1 into `action.yml` inputs, keeping `release.sh` the single source of
truth per ADR-0001. Started as a need for this repo's own self-release automation, but built as
a general opt-in input since it'll be reused by other actions.

We chose GitHub's REST `git/refs` endpoints (create via `POST`, move via `PATCH ... force: true`,
resolving the new Release Tag's commit SHA via `GET git/refs/tags/<tag>`) over local git CLI
commands (`git tag -f` + `push --force`). `release.sh` already works purely via `curl`+`jq` with
no git checkout required at all. A git-CLI-based retag would force every consumer of
`tag-major`/`tag-minor` into a full, deep checkout with push credentials configured just to get
two extra tags moved — a much heavier requirement than the rest of the action has ever imposed,
and inconsistent with its checkout-free design.

## Considered options

- **git CLI** (`git tag -f` + `push --force`) — rejected: requires a full checkout and push
  credentials from every consumer; contradicts `release.sh`'s existing checkout-free design.
- **Logic living only in `action.yml`/composite steps, bypassing `release.sh`** — rejected:
  breaks ADR-0001's "release.sh is the single source of truth, every input mirrors a flag 1:1."

## Other decisions bundled with this one

- `tag-major` and `tag-minor` are independent — a consumer can opt into one without the other.
  Both default to `false` (opt-in, no behavior change for existing users).
- When either flag is `true`, `tag` must be a Release Tag (see `CONTEXT.md`) or the script errors
  before creating anything.
- If the Release + exact tag succeeds but a moving-tag API call then fails, the whole action fails
  non-zero — matches `release.sh`'s existing error-surfacing convention; a "green" run that left a
  Moving Tag stale would be worse than a loud failure.
