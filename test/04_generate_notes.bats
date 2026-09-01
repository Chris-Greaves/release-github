#!/usr/bin/env bats

load test_helper

@test "--generate-notes sets generate_release_notes: true" {
  stub_curl 201 '{"html_url": "https://example.invalid/releases/tag/v1.0.0"}'

  run_release --repo octocat/hello-world --tag v1.0.0 --generate-notes
  assert_success
  assert_payload_field_true '.generate_release_notes'
}

@test "omitting --generate-notes leaves generate_release_notes out of the payload" {
  stub_curl 201 '{"html_url": "https://example.invalid/releases/tag/v1.0.0"}'

  run_release --repo octocat/hello-world --tag v1.0.0
  assert_success
  assert_payload_missing_key "generate_release_notes"
}
