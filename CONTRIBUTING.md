# Contributing

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
