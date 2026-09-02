load '../node_modules/bats-support/load'
load '../node_modules/bats-assert/load'

RELEASE_SCRIPT="$BATS_TEST_DIRNAME/../release.sh"

setup() {
  export PATH="$BATS_TEST_DIRNAME/stubs:$PATH"
  export CURL_STUB_LOG="$BATS_TEST_TMPDIR/curl.args"
  export CURL_STUB_DIR="$BATS_TEST_TMPDIR/curl_stub"

  unset GITHUB_TOKEN GH_TOKEN GITHUB_REPOSITORY GITHUB_API_URL \
    CURL_STUB_STATUS CURL_STUB_BODY

  export GITHUB_TOKEN="test-token"
}

# stub_curl <http_status> <response_body>
# Scripts the same response for every curl invocation in the test.
stub_curl() {
  export CURL_STUB_STATUS="$1"
  export CURL_STUB_BODY="$2"
}

# stub_curl_sequence <status1> <body1> [<status2> <body2> ...]
# Scripts one response per curl invocation, in call order (0-indexed) —
# for flows that make several sequential API calls (e.g. release create ->
# SHA resolve -> ref create/move). Any call beyond the scripted sequence
# falls back to stub_curl's single-response behavior.
stub_curl_sequence() {
  mkdir -p "$CURL_STUB_DIR"

  local i=0
  while [[ $# -gt 0 ]]; do
    printf '%s' "$1" > "$CURL_STUB_DIR/$i.status"
    printf '%s' "$2" > "$CURL_STUB_DIR/$i.body"
    i=$((i + 1))
    shift 2
  done
}

run_release() {
  run bash "$RELEASE_SCRIPT" "$@"
}

# Number of times the curl stub was invoked (0 if never).
curl_call_count() {
  [[ -f "$CURL_STUB_LOG.count" ]] || { printf '0'; return 0; }
  cat "$CURL_STUB_LOG.count"
}

# Fails loudly if curl was invoked at all — for asserting validation
# rejects input before any API call is made.
assert_curl_not_invoked() {
  if [[ -f "$CURL_STUB_LOG" ]]; then
    echo "expected curl not to have been invoked, but it was" >&2
    return 1
  fi
}

# Populates the global array CURL_ARGS with the argv of the curl stub's Nth
# invocation (0-indexed; defaults to its only/last invocation). Both
# curl_payload() and curl_request_url() scan this.
_curl_args() {
  local index="${1:-}"
  local log_file="$CURL_STUB_LOG"
  if [[ -n "$index" ]]; then
    log_file="$CURL_STUB_LOG.$index"
  fi
  [[ -f "$log_file" ]] || return 1
  CURL_ARGS=()
  mapfile -d '' -t CURL_ARGS <"$log_file"
}

# Prints the JSON payload passed to curl via `-d`, if the stub was invoked.
# curl_payload [call_index]
curl_payload() {
  _curl_args "${1:-}" || return 1

  local i
  for i in "${!CURL_ARGS[@]}"; do
    if [[ "${CURL_ARGS[$i]}" == "-d" ]]; then
      printf '%s' "${CURL_ARGS[$((i + 1))]}"
      return 0
    fi
  done
  return 1
}

# Prints the request URL curl was invoked with, if the stub was invoked.
# curl_request_url [call_index]
curl_request_url() {
  _curl_args "${1:-}" || return 1

  local arg
  for arg in "${CURL_ARGS[@]}"; do
    if [[ "$arg" == http*://* ]]; then
      printf '%s' "$arg"
      return 0
    fi
  done
  return 1
}

# Prints the HTTP method curl was invoked with (via -X), defaulting to GET
# when no -X flag was passed, matching curl's own default.
# curl_request_method [call_index]
curl_request_method() {
  _curl_args "${1:-}" || return 1

  local i
  for i in "${!CURL_ARGS[@]}"; do
    if [[ "${CURL_ARGS[$i]}" == "-X" ]]; then
      printf '%s' "${CURL_ARGS[$((i + 1))]}"
      return 0
    fi
  done
  printf 'GET'
}

# Fails loudly if curl was never invoked, instead of letting callers
# downstream (jq on empty input) turn that into a confusing empty-value
# mismatch that hides the real cause (e.g. release.sh exited before the
# API call).
_require_curl_invoked() {
  if [[ ! -f "$CURL_STUB_LOG" ]]; then
    echo "expected curl to have been invoked, but it wasn't (no stub log at $CURL_STUB_LOG)" >&2
    return 1
  fi
}

# assert_payload_field <jq_filter> <expected_value>
assert_payload_field() {
  local filter="$1" expected="$2"
  _require_curl_invoked || return 1

  local actual
  actual=$(curl_payload | jq -r "$filter")
  # Strip any \r: some jq builds (notably native Windows ones) rewrite LF to
  # CRLF on their own stdout, which would otherwise corrupt this assertion's
  # view of multi-line values without reflecting anything actually sent to
  # curl (the raw payload captured by the stub is unaffected).
  actual="${actual//$'\r'/}"
  if [[ "$actual" != "$expected" ]]; then
    echo "expected payload $filter to be '$expected', got '$actual'" >&2
    echo "full payload: $(curl_payload)" >&2
    return 1
  fi
}

# assert_payload_field_true <jq_filter>
# Like assert_payload_field, but asserts a real JSON boolean `true` rather
# than any value that merely reads "true" — jq -r renders the boolean true
# and the string "true" identically, so assert_payload_field can't tell
# them apart.
assert_payload_field_true() {
  local filter="$1"
  _require_curl_invoked || return 1

  local actual
  actual=$(curl_payload | jq "$filter")
  actual="${actual//$'\r'/}"
  if [[ "$actual" != "true" ]]; then
    echo "expected payload $filter to be boolean true, got '$actual'" >&2
    echo "full payload: $(curl_payload)" >&2
    return 1
  fi
}

# assert_payload_missing_key <key>
assert_payload_missing_key() {
  local key="$1"
  _require_curl_invoked || return 1

  local has_key
  has_key=$(curl_payload | jq "has(\"$key\")")
  if [[ "$has_key" != "false" ]]; then
    echo "expected payload to omit key '$key', but it was present" >&2
    echo "full payload: $(curl_payload)" >&2
    return 1
  fi
}
