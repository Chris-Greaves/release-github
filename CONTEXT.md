# release-github

A bash-only, no-runtime GitHub Action that creates a GitHub Release (and its underlying tag) via the REST API.

## Language

**Release Tag**:
A git tag whose name is a Semantic Version (`MAJOR.MINOR.PATCH`, per semver.org), with an optional leading lowercase `v` — no pre-release or build-metadata suffix either way. Same definition `next-semver` uses. When `tag-major`/`tag-minor` are enabled, the action's `tag` input must be a Release Tag or the run errors before creating anything; without them, `tag` stays free-form.
_Avoid_: version tag, semver tag

**Moving Tag**:
A lightweight git tag that gets force-updated to point at a new commit on every matching release, rather than staying pinned to the commit it was first created at — unlike a Release Tag, which is immutable once published. Comes in two forms: a Major Tag and a Minor Tag.
_Avoid_: rolling tag, floating tag, alias tag

**Major Tag**:
A Moving Tag named `vMAJOR` (e.g. `v1`) that always points at the most recently created Release Tag's commit sharing that MAJOR version. Created/moved when the action's `tag-major` input is `true`.
_Avoid_: major version tag

**Minor Tag**:
A Moving Tag named `vMAJOR.MINOR` (e.g. `v1.2`) that always points at the most recently created Release Tag's commit sharing that MAJOR.MINOR — frozen once a newer MINOR ships. Created/moved when the action's `tag-minor` input is `true`.
_Avoid_: minor version tag
