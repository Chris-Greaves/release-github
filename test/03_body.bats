#!/usr/bin/env bats

load test_helper

@test "--body sets the release body" {
  stub_curl 201 '{"html_url": "https://example.invalid/releases/tag/v1.0.0"}'

  run_release --repo octocat/hello-world --tag v1.0.0 --body "Release notes here"
  assert_success
  assert_payload_field '.body' "Release notes here"
}

@test "--body-file sets the release body to the file's contents" {
  stub_curl 201 '{"html_url": "https://example.invalid/releases/tag/v1.0.0"}'
  local body_file="$BATS_TEST_TMPDIR/body.md"
  printf 'Line one\nLine two\n' >"$body_file"

  run_release --repo octocat/hello-world --tag v1.0.0 --body-file "$body_file"
  assert_success
  assert_payload_field '.body' "$(printf 'Line one\nLine two')"
}

@test "passing both --body and --body-file is an error" {
  local body_file="$BATS_TEST_TMPDIR/body.md"
  printf 'from file' >"$body_file"

  run_release --repo octocat/hello-world --tag v1.0.0 --body "from flag" --body-file "$body_file"
  assert_failure
  assert_output --partial "cannot both be passed"
}

@test "passing neither --body nor --body-file leaves the body unset" {
  stub_curl 201 '{"html_url": "https://example.invalid/releases/tag/v1.0.0"}'

  run_release --repo octocat/hello-world --tag v1.0.0
  assert_success
  assert_payload_missing_key "body"
}
