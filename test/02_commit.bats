#!/usr/bin/env bats

load test_helper

@test "--commit is included in the payload as target_commitish" {
  stub_curl 201 '{"html_url": "https://example.invalid/releases/tag/v1.0.0"}'

  run_release --repo octocat/hello-world --tag v1.0.0 --commit deadbeef
  assert_success
  assert_payload_field '.target_commitish' "deadbeef"
}

@test "omitting --commit leaves target_commitish out of the payload entirely" {
  stub_curl 201 '{"html_url": "https://example.invalid/releases/tag/v1.0.0"}'

  run_release --repo octocat/hello-world --tag v1.0.0
  assert_success
  assert_payload_missing_key "target_commitish"
}
