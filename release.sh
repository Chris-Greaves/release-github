#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: release.sh --tag <name> [--repo owner/name]

  --repo owner/name   Repository to release into. Defaults to $GITHUB_REPOSITORY.
  --tag <name>        Tag to create the release for. Required.

Auth is read from $GITHUB_TOKEN, falling back to $GH_TOKEN.
API base URL defaults to https://api.github.com, overridable via $GITHUB_API_URL.
EOF
}

repo="${GITHUB_REPOSITORY:-}"
tag=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      if [[ $# -lt 2 ]]; then
        echo "Error: --repo requires a value" >&2
        exit 1
      fi
      repo="$2"
      shift 2
      ;;
    --tag)
      if [[ $# -lt 2 ]]; then
        echo "Error: --tag requires a value" >&2
        exit 1
      fi
      tag="$2"
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

token="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
if [[ -z "$token" ]]; then
  echo "Error: no token found; set \$GITHUB_TOKEN or \$GH_TOKEN" >&2
  exit 1
fi

api_url="${GITHUB_API_URL:-https://api.github.com}"
api_url="${api_url%/}"

payload=$(jq -n --arg tag_name "$tag" '{tag_name: $tag_name}')

response=$(curl -sS -w '\n%{http_code}' \
  -X POST \
  -H "Authorization: Bearer $token" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "$api_url/repos/$repo/releases" \
  -d "$payload")

http_code=$(printf '%s\n' "$response" | tail -n1)
body=$(printf '%s\n' "$response" | sed '$d')

if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
  echo "$body" | jq -r '.html_url'
  exit 0
else
  echo "$body" >&2
  exit 1
fi
