# release-github

This is a simple, bash-only script and GitHub Action for Creating a new release on Github.

## Features

- Create a release in GitHub
- Create a tag to go with the release
- Specify the exact commit to release
- Specify the description (or body) of the release
- Append Github's Auto-generated release notes
- Set the release to latest, draft, or prerelease

> [!TIP]
> This bash script relies heavily on the GitHub API, specifically the [Releases section](https://docs.github.com/en/rest/releases?apiVersion=2026-03-10)