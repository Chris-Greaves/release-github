# Contributing

## Running tests

Tests use [bats](https://github.com/bats-core/bats-core) and live under `test/` as `*.bats`
files. `curl` is stubbed (see `test/stubs/curl`), so no test run hits the real GitHub API.
The test helpers use `mapfile -d ''`, which needs bash >= 4.4 — on macOS, the system `/bin/bash`
is 3.2, so install a newer bash (e.g. via Homebrew) before running tests.

```
npm install
node_modules/.bin/bats test/
```

`npm test` runs the same command and works in most shells, but on some Windows setups the
npm/npx wrapper mis-resolves paths for bats — if `npm test` fails with a "Passed library load
path is not an absolute path" error, run `node_modules/.bin/bats test/` directly instead.

## Versioning

Releases of this action are tagged with Release Tags, e.g. `v1.2.3`. Tagging is automated: a
`release` job in `.github/workflows/test.yml` runs after the `bats` and `integration` jobs pass
on a push to `main`. It computes the next version with `Chris-Greaves/next-semver`, and if that
version differs from the last Release Tag, it invokes this action with `tag-major: true` and
`tag-minor: true` to create the new Release Tag and move the Major Tag (e.g. `v1`) and Minor Tag
(e.g. `v1.2`) to point at it. If the computed version is unchanged — no `feat`/`fix`/breaking
commits since the last release — the job is a no-op, since a Release Tag is immutable once
published and re-running would otherwise fail trying to recreate it.

The Major Tag is what consumers pin against in their `uses: Chris-Greaves/release-github@v1`
steps, so they pick up non-breaking fixes and features automatically.

## Commit messages

This repo uses [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

- **type** — one of:
  - `feat` — a new feature
  - `fix` — a bug fix
  - `docs` — documentation only
  - `test` — adding or correcting tests
  - `refactor` — code change that neither fixes a bug nor adds a feature
  - `chore` — tooling, config, or other changes that don't touch script/test behavior
- **description** — imperative mood, lowercase, no trailing period (e.g. `add commit targeting flag`, not `Added commit targeting flag.`)
- **body** — explain *why*, not just what; wrap around 72 characters
- Breaking changes: add `!` after the type/scope (`feat!: ...`) and/or a `BREAKING CHANGE:` footer

### Examples

```
feat: add --commit flag for targeting a specific ref

fix: surface GitHub error body on non-2xx release creation

docs: document GITHUB_API_URL override for GHES
```
