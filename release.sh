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
                   [--body <text> | --body-file <path>]

  --repo owner/name   Repository to release into. Defaults to $GITHUB_REPOSITORY.
  --tag <name>        Tag to create the release for. Required.
  --commit <ref>      Commit/branch/tag to target. Defaults to the repo's default branch HEAD.
  --body <text>       Release body text. Mutually exclusive with --body-file.
  --body-file <path>  Read the release body from this file. Mutually exclusive with --body.

Auth is read from $GITHUB_TOKEN, falling back to $GH_TOKEN.
API base URL defaults to https://api.github.com, overridable via $GITHUB_API_URL.
EOF
}

repo="${GITHUB_REPOSITORY:-}"
tag=""
commit=""
body=""
body_file=""
body_provided=false
body_file_provided=false

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

payload=$(jq -n "${jq_args[@]}" "$jq_filter")

response=$(curl -sS -w '\n%{http_code}' \
  -X POST \
  -H "Authorization: Bearer $token" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "$api_url/repos/$repo/releases" \
  -d "$payload")

http_code=$(printf '%s\n' "$response" | tail -n1)
response_body=$(printf '%s\n' "$response" | sed '$d')

if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
  echo "$response_body" | jq -r '.html_url'
  exit 0
else
  echo "$response_body" >&2
  exit 1
fi
