# release-github

This is a simple, bash-only script and GitHub Action for Creating a new release on Github.

## Features

- Create a release in GitHub
- Create a tag to go with the release
- Specify the exact commit to release
- Specify the description (or body) of the release
- Append Github's Auto-generated release notes
- Set the release to latest, draft, or prerelease
- Optionally create/move a Major Tag and/or Minor Tag alongside the release

## Usage

```yaml
permissions:
  contents: write

steps:
  - name: Create Release
    uses: Chris-Greaves/release-github@v1
    with:
      tag: v1.2.3
      generate-notes: true
      draft: false
```

`permissions: contents: write` is required because repos default the Actions token to
read-only — without it, the release creation call fails with a 403.

See [`action.yml`](./action.yml) for the full list of inputs and outputs.

### Moving Tags

A **Release Tag** is a git tag whose name is a Semantic Version (`MAJOR.MINOR.PATCH`, per
semver.org), with an optional leading lowercase `v` — this is the value passed to `tag` above.
Setting `tag-major`/`tag-minor` also creates/force-moves a **Moving Tag** — a Major Tag
(`vMAJOR`) and/or Minor Tag (`vMAJOR.MINOR`) — to the Release Tag's commit. Unlike the Release
Tag, which is immutable once published, a Moving Tag always tracks the most recently released
commit that shares its MAJOR (or MAJOR.MINOR) version — this is what consumers pin against
(e.g. `uses: Chris-Greaves/release-github@v1`) to pick up non-breaking fixes and features
automatically. Both inputs require `tag` to be a Release Tag, and are independent of each other:

```yaml
permissions:
  contents: write

steps:
  - name: Create Release
    uses: Chris-Greaves/release-github@v1
    with:
      tag: v1.2.3
      tag-major: true
      tag-minor: true
```

This creates the Release Tag `v1.2.3`, then creates/moves the Major Tag `v1` and Minor Tag
`v1.2` to point at the same commit.

> [!TIP]
> This bash script relies heavily on the GitHub API, specifically the [Releases section](https://docs.github.com/en/rest/releases?apiVersion=2026-03-10)

## License

[ISC](./LICENSE)