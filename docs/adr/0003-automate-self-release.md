# Automate this repo's own releases via next-semver

Closes the loop ADR-0001 deferred. A `release` job appended to `.github/workflows/test.yml`, gated
on the `bats`/`integration` jobs passing, on push to `main`, replaces the manual `git tag`/`push`
steps in `CONTRIBUTING.md`. It runs `Chris-Greaves/next-semver@v1` (full-history checkout) to
compute the next version; if that version is unchanged from the last Release Tag (no `feat`/`fix`/
breaking commits since), the job does nothing further — re-running would otherwise force-move the
exact Release Tag to a new commit, breaking the immutability the whole Moving Tag scheme (see
`CONTEXT.md`, ADR-0002) depends on. Otherwise it self-invokes `uses: ./` with `tag: v<version>`,
`tag-major: true`, `tag-minor: true`, `generate-notes: true`.

The integration test job already proves `uses: ./` works end-to-end on this exact repo, resolving
the bootstrapping concern ADR-0001 raised about trusting the action to release itself.

## Considered options

- **Tags-only, no self-created Release** — rejected: this action's entire purpose is creating
  Releases; producing tags with no accompanying Release would be a half-finished result.
- **Draft releases requiring manual publish** — rejected: defeats the purpose of automating this
  away.

## Other decisions bundled with this one

- Bootstrap: this repo's first Release Tag (`v1.0.0`) is seeded manually, once, before the
  automation goes live — matching what was already done for `next-semver` itself, and keeping the
  `v1` usage already documented in `README.md`/`CONTRIBUTING.md` true from day one. (`next-semver`
  hardcodes `0.1.0` as the very first computed version when no tag exists at all, which would
  otherwise contradict those docs.)
