#!/usr/bin/env bash
set -euo pipefail

require_arg() {
  local flag="$1" remaining="$2"
  if [[ "$remaining" -lt 2 ]]; then
    echo "Error: $flag requires a value" >&2
    exit 1
  fi
}

usage() {
  cat >&2 <<'EOF'
Usage: release.sh --tag <name> [--repo owner/name] [--commit <ref>]
                   [--body <text> | --body-file <path>] [--generate-notes]
                   [--draft] [--prerelease] [--latest] [--tag-major] [--tag-minor]

  --repo owner/name   Repository to release into. Defaults to $GITHUB_REPOSITORY.
  --tag <name>        Tag to create the release for. Required.
  --commit <ref>      Commit/branch/tag to target. Defaults to the repo's default branch HEAD.
  --body <text>       Release body text. Mutually exclusive with --body-file.
  --body-file <path>  Read the release body from this file. Mutually exclusive with --body.
  --generate-notes    Have GitHub append its auto-generated notes after the body.
  --draft             Create the release as a draft.
  --prerelease        Mark the release as a prerelease.
  --latest            Mark the release as the repo's "latest" release.
  --tag-major         Also create/force-move the Major Tag (vMAJOR) to the Release Tag's commit.
                      Requires --tag to be a Release Tag (MAJOR.MINOR.PATCH, optional leading v).
  --tag-minor         Also create/force-move the Minor Tag (vMAJOR.MINOR) to the Release Tag's
                      commit. Requires --tag to be a Release Tag, same as --tag-major.
                      Independent of --tag-major: either, both, or neither may be passed.

Auth is read from $GITHUB_TOKEN, falling back to $GH_TOKEN.
API base URL defaults to https://api.github.com, overridable via $GITHUB_API_URL.
EOF
}

# A Release Tag: a Semantic Version (MAJOR.MINOR.PATCH, per semver.org), with
# an optional leading lowercase v, and no pre-release/build-metadata suffix.
release_tag_regex='^v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'

# github_api <method> <path> [payload]
# Performs one GitHub API call and prints the response in the shape the
# rest of this script expects: the response body, a newline, then the HTTP
# status code (matching curl's own -w '\n%{http_code}').
github_api() {
  local method="$1" path="$2" payload="${3:-}"
  local args=(-sS -w '\n%{http_code}' -X "$method" \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$api_url/$path")
  if [[ -n "$payload" ]]; then
    args+=(-d "$payload")
  fi
  curl "${args[@]}"
}

response_status() {
  printf '%s\n' "$1" | tail -n1
}

response_body_of() {
  printf '%s\n' "$1" | sed '$d'
}

# resolve_tag_commit_sha <tag>
# Resolves the commit SHA a just-created Release Tag points at, via
# GET git/refs/tags/<tag>. If the tag is annotated (object.type == "tag"),
# dereferences it via GET git/tags/<sha> to reach the underlying commit,
# since a Moving Tag must point at a commit like the Release Tag does.
# Exits non-zero on failure.
resolve_tag_commit_sha() {
  local tag_name="$1"
  local response http_code body sha type

  response=$(github_api GET "repos/$repo/git/refs/tags/$tag_name")
  http_code=$(response_status "$response")
  body=$(response_body_of "$response")

  if ! [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
    echo "$body" >&2
    exit 1
  fi

  sha=$(echo "$body" | jq -r '.object.sha')
  type=$(echo "$body" | jq -r '.object.type')

  if [[ "$type" == "tag" ]]; then
    response=$(github_api GET "repos/$repo/git/tags/$sha")
    http_code=$(response_status "$response")
    body=$(response_body_of "$response")

    if ! [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
      echo "$body" >&2
      exit 1
    fi

    sha=$(echo "$body" | jq -r '.object.sha')
  fi

  echo "$sha"
}

# create_or_move_tag <moving_tag> <sha>
# Points a Moving Tag (e.g. a Major Tag) at the given commit SHA: attempts
# to create it via POST git/refs first, falling back to a force-move via
# PATCH git/refs/<ref> if it already exists. Trying the create unconditionally
# (rather than checking existence first) keeps this a single atomic write
# attempt, avoiding a check-then-act race against a concurrent run touching
# the same Moving Tag. Exits non-zero if any call in this sequence fails.
create_or_move_tag() {
  local moving_tag="$1" sha="$2"
  local ref="tags/$moving_tag"
  local response http_code body

  local create_payload
  create_payload=$(jq -n --arg ref "refs/$ref" --arg sha "$sha" '{ref: $ref, sha: $sha}')
  response=$(github_api POST "repos/$repo/git/refs" "$create_payload")
  http_code=$(response_status "$response")
  body=$(response_body_of "$response")

  if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
    return 0
  fi

  if [[ "$http_code" != "422" ]] || ! echo "$body" | jq -e '.message == "Reference already exists"' >/dev/null; then
    echo "$body" >&2
    exit 1
  fi

  local move_payload
  move_payload=$(jq -n --arg sha "$sha" '{sha: $sha, force: true}')
  response=$(github_api PATCH "repos/$repo/git/refs/$ref" "$move_payload")
  http_code=$(response_status "$response")
  body=$(response_body_of "$response")

  if ! [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
    echo "$body" >&2
    exit 1
  fi
}

repo="${GITHUB_REPOSITORY:-}"
tag=""
commit=""
body=""
body_file=""
body_provided=false
body_file_provided=false
generate_notes=false
draft=false
prerelease=false
latest=false
tag_major=false
tag_minor=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      require_arg "$1" "$#"
      repo="$2"
      shift 2
      ;;
    --tag)
      require_arg "$1" "$#"
      tag="$2"
      shift 2
      ;;
    --commit)
      require_arg "$1" "$#"
      commit="$2"
      shift 2
      ;;
    --body)
      require_arg "$1" "$#"
      body="$2"
      body_provided=true
      shift 2
      ;;
    --body-file)
      require_arg "$1" "$#"
      body_file="$2"
      body_file_provided=true
      shift 2
      ;;
    --generate-notes)
      generate_notes=true
      shift
      ;;
    --draft)
      draft=true
      shift
      ;;
    --prerelease)
      prerelease=true
      shift
      ;;
    --latest)
      latest=true
      shift
      ;;
    --tag-major)
      tag_major=true
      shift
      ;;
    --tag-minor)
      tag_minor=true
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$repo" ]]; then
  echo "Error: --repo is required (or set \$GITHUB_REPOSITORY)" >&2
  exit 1
fi

if [[ -z "$tag" ]]; then
  echo "Error: --tag is required" >&2
  exit 1
fi

# release_major/release_minor: the Release Tag's MAJOR/MINOR components, captured
# from release_tag_regex here so major/minor moving-tag names can be built by
# simple substitution below instead of each re-parsing $tag by hand.
if [[ "$tag_major" == true || "$tag_minor" == true ]]; then
  if ! [[ "$tag" =~ $release_tag_regex ]]; then
    echo "Error: --tag-major/--tag-minor requires --tag to be a Release Tag (MAJOR.MINOR.PATCH, optional leading v); got '$tag'" >&2
    exit 1
  fi
  release_major="${BASH_REMATCH[1]}"
  release_minor="${BASH_REMATCH[2]}"
fi

if [[ "$body_provided" == true && "$body_file_provided" == true ]]; then
  echo "Error: --body and --body-file cannot both be passed" >&2
  exit 1
fi

if [[ "$body_file_provided" == true ]]; then
  if [[ ! -f "$body_file" || ! -r "$body_file" ]]; then
    echo "Error: --body-file $body_file is not a readable file" >&2
    exit 1
  fi
  body=$(cat "$body_file")
fi

token="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
if [[ -z "$token" ]]; then
  echo "Error: no token found; set \$GITHUB_TOKEN or \$GH_TOKEN" >&2
  exit 1
fi

api_url="${GITHUB_API_URL:-https://api.github.com}"
api_url="${api_url%/}"

jq_args=(--arg tag_name "$tag")
jq_filter='{tag_name: $tag_name}'

if [[ -n "$commit" ]]; then
  jq_args+=(--arg target_commitish "$commit")
  jq_filter+=' + {target_commitish: $target_commitish}'
fi

if [[ "$body_provided" == true || "$body_file_provided" == true ]]; then
  jq_args+=(--arg body "$body")
  jq_filter+=' + {body: $body}'
fi

if [[ "$generate_notes" == true ]]; then
  jq_filter+=' + {generate_release_notes: true}'
fi

if [[ "$draft" == true ]]; then
  jq_filter+=' + {draft: true}'
fi

if [[ "$prerelease" == true ]]; then
  jq_filter+=' + {prerelease: true}'
fi

if [[ "$latest" == true ]]; then
  jq_filter+=' + {make_latest: "true"}'
fi

payload=$(jq -n "${jq_args[@]}" "$jq_filter")

response=$(github_api POST "repos/$repo/releases" "$payload")
http_code=$(response_status "$response")
response_body=$(response_body_of "$response")

if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
  if [[ "$tag_major" == true || "$tag_minor" == true ]]; then
    commit_sha=$(resolve_tag_commit_sha "$tag")
    if [[ "$tag_major" == true ]]; then
      create_or_move_tag "v$release_major" "$commit_sha"
    fi
    if [[ "$tag_minor" == true ]]; then
      create_or_move_tag "v$release_major.$release_minor" "$commit_sha"
    fi
  fi
  echo "$response_body" | jq -r '.html_url'
  exit 0
else
  echo "$response_body" >&2
  exit 1
fi
