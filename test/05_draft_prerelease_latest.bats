#!/usr/bin/env bats

load test_helper

@test "--draft sets draft: true; omitted when not passed" {
  stub_curl 201 '{"html_url": "https://example.invalid/releases/tag/v1.0.0"}'
  run_release --repo octocat/hello-world --tag v1.0.0 --draft
  assert_success
  assert_payload_field_true '.draft'

  stub_curl 201 '{"html_url": "https://example.invalid/releases/tag/v1.0.0"}'
  run_release --repo octocat/hello-world --tag v1.0.0
  assert_success
  assert_payload_missing_key "draft"
}

@test "--prerelease sets prerelease: true; omitted when not passed" {
  stub_curl 201 '{"html_url": "https://example.invalid/releases/tag/v1.0.0"}'
  run_release --repo octocat/hello-world --tag v1.0.0 --prerelease
  assert_success
  assert_payload_field_true '.prerelease'

  stub_curl 201 '{"html_url": "https://example.invalid/releases/tag/v1.0.0"}'
  run_release --repo octocat/hello-world --tag v1.0.0
  assert_success
  assert_payload_missing_key "prerelease"
}

@test "--latest sets make_latest; omitted when not passed" {
  stub_curl 201 '{"html_url": "https://example.invalid/releases/tag/v1.0.0"}'
  run_release --repo octocat/hello-world --tag v1.0.0 --latest
  assert_success
  assert_payload_field '.make_latest' "true"

  stub_curl 201 '{"html_url": "https://example.invalid/releases/tag/v1.0.0"}'
  run_release --repo octocat/hello-world --tag v1.0.0
  assert_success
  assert_payload_missing_key "make_latest"
}

@test "--draft, --prerelease, and --latest are combinable" {
  stub_curl 201 '{"html_url": "https://example.invalid/releases/tag/v1.0.0"}'

  run_release --repo octocat/hello-world --tag v1.0.0 --draft --prerelease --latest
  assert_success
  assert_payload_field_true '.draft'
  assert_payload_field_true '.prerelease'
  assert_payload_field '.make_latest' "true"
}
