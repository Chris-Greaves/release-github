#!/usr/bin/env bats

load test_helper

@test "requires --repo when GITHUB_REPOSITORY is unset" {
  run_release --tag v1.0.0
  assert_failure
  assert_output --partial "repo"
}

@test "falls back to GITHUB_REPOSITORY when --repo is omitted" {
  stub_curl 201 '{"html_url": "https://github.com/octocat/hello-world/releases/tag/v1.0.0"}'
  export GITHUB_REPOSITORY="octocat/hello-world"

  run_release --tag v1.0.0
  assert_success
  assert_equal "$(curl_request_url)" "https://api.github.com/repos/octocat/hello-world/releases"
}

@test "requires --tag" {
  run_release --repo octocat/hello-world
  assert_failure
  assert_output --partial "tag"
}

@test "requires a token when neither GITHUB_TOKEN nor GH_TOKEN is set" {
  unset GITHUB_TOKEN
  run_release --repo octocat/hello-world --tag v1.0.0
  assert_failure
  assert_output --partial "token"
}

@test "falls back to GH_TOKEN when GITHUB_TOKEN is unset" {
  unset GITHUB_TOKEN
  export GH_TOKEN="gh-token"
  stub_curl 201 '{"html_url": "https://github.com/octocat/hello-world/releases/tag/v1.0.0"}'

  run_release --repo octocat/hello-world --tag v1.0.0
  assert_success
}

@test "on a 2xx response, prints html_url and exits 0" {
  stub_curl 201 '{"html_url": "https://github.com/octocat/hello-world/releases/tag/v1.0.0"}'

  run_release --repo octocat/hello-world --tag v1.0.0
  assert_success
  assert_output "https://github.com/octocat/hello-world/releases/tag/v1.0.0"
}

@test "sends only tag_name in the payload with no optional flags" {
  stub_curl 201 '{"html_url": "https://example.invalid/releases/tag/v1.0.0"}'

  run_release --repo octocat/hello-world --tag v1.0.0
  assert_success
  assert_payload_field '.tag_name' "v1.0.0"
  assert_payload_missing_key "target_commitish"
  assert_payload_missing_key "body"
  assert_payload_missing_key "generate_release_notes"
  assert_payload_missing_key "draft"
  assert_payload_missing_key "prerelease"
  assert_payload_missing_key "make_latest"
}

@test "on a non-2xx response, prints GitHub's error to stderr and exits 1" {
  stub_curl 500 '{"message": "Internal Server Error"}'

  run_release --repo octocat/hello-world --tag v1.0.0
  assert_failure
  assert_output --partial "Internal Server Error"
}

@test "a second run against the same tag surfaces already_exists instead of silently succeeding" {
  stub_curl 201 '{"html_url": "https://github.com/octocat/hello-world/releases/tag/v1.0.0"}'
  run_release --repo octocat/hello-world --tag v1.0.0
  assert_success

  stub_curl 422 '{"message": "Validation Failed", "errors": [{"code": "already_exists", "field": "tag_name"}]}'
  run_release --repo octocat/hello-world --tag v1.0.0
  assert_failure
  assert_output --partial "already_exists"
}
