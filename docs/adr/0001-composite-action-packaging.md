# Wrap release.sh as a composite GitHub Action

We're exposing `release.sh` to consumers as a GitHub Action. We chose a **composite action**
(`action.yml` with `runs: using: composite`, a `run:` step invoking `release.sh` directly) over
a Docker container action or a JavaScript action, because the project's whole design
philosophy is "bash-only, no other language runtime" (see `.scratch/release-script/spec.md`).
A Docker action adds build/pull overhead for no benefit; a JS action would need bundling and
contradicts the bash-only stance. Composite keeps `release.sh` as the single source of truth,
invoked directly, and still testable by the existing bats suite.

## Considered options

- **Docker container action** — rejected: build/pull overhead, no functional benefit over
  running the script directly on the (already Linux) runner.
- **JavaScript action** — rejected: contradicts the "bash-only" project constraint and needs
  a bundling step.

## Other decisions bundled with this one

- The action's `token` input defaults to `${{ github.token }}`, so it works with zero config
  in the common same-repo case, while still being overridable for cross-repo/PAT use.
- Every `release.sh` flag is exposed 1:1 as an action input (no curated subset) — the script's
  flag surface was already deliberately scoped in its own grilling session, so the wrapper
  shouldn't be narrower than what it wraps.
- Versioning is manual for now (semver tags + a moved `v1` major tag) — automating the
  action's own release process is deferred to a future session to avoid scope creep and a
  bootstrapping problem (the action must be proven working before it's trustworthy to use on
  itself).
