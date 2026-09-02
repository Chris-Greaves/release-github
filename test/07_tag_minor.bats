#!/usr/bin/env bats

load test_helper

@test "--tag-minor rejects a non-Release-Tag before any API call" {
  local bad_tag
  for bad_tag in "1.2" "v1.2.3-beta" "v1.2.3+build.5" "v01.2.3" "V1.2.3" "release-2024"; do
    run_release --repo octocat/hello-world --tag "$bad_tag" --tag-minor
    assert_failure
    assert_output --partial "Release Tag"
    assert_curl_not_invoked
  done
}

@test "--tag-minor creates the Minor Tag when it doesn't yet exist" {
  stub_curl_sequence \
    201 '{"html_url": "https://example.invalid/releases/tag/v1.4.2"}' \
    200 '{"object": {"sha": "commitsha123", "type": "commit"}}' \
    201 '{"ref": "refs/tags/v1.4", "object": {"sha": "commitsha123"}}'

  run_release --repo octocat/hello-world --tag v1.4.2 --tag-minor
  assert_success
  assert_output "https://example.invalid/releases/tag/v1.4.2"
  assert_equal "$(curl_call_count)" "3"

  # Call 1: resolves the just-created exact tag's commit SHA.
  assert_equal "$(curl_request_url 1)" "https://api.github.com/repos/octocat/hello-world/git/refs/tags/v1.4.2"

  # Call 2: create attempted directly; absent -> succeeds via POST git/refs.
  assert_equal "$(curl_request_method 2)" "POST"
  assert_equal "$(curl_request_url 2)" "https://api.github.com/repos/octocat/hello-world/git/refs"
  assert_equal "$(curl_payload 2 | jq -r '.ref')" "refs/tags/v1.4"
  assert_equal "$(curl_payload 2 | jq -r '.sha')" "commitsha123"
}

@test "--tag-minor force-moves the Minor Tag when it already exists" {
  stub_curl_sequence \
    201 '{"html_url": "https://example.invalid/releases/tag/v1.4.2"}' \
    200 '{"object": {"sha": "commitsha123", "type": "commit"}}' \
    422 '{"message": "Reference already exists"}' \
    200 '{"ref": "refs/tags/v1.4", "object": {"sha": "commitsha123"}}'

  run_release --repo octocat/hello-world --tag v1.4.2 --tag-minor
  assert_success
  assert_equal "$(curl_call_count)" "4"

  # Call 2: create attempted first, fails with "already exists" ...
  assert_equal "$(curl_request_method 2)" "POST"

  # ... call 3: ... so it falls back to a force-move via PATCH.
  assert_equal "$(curl_request_method 3)" "PATCH"
  assert_equal "$(curl_request_url 3)" "https://api.github.com/repos/octocat/hello-world/git/refs/tags/v1.4"
  assert_equal "$(curl_payload 3 | jq -r '.sha')" "commitsha123"
  assert_equal "$(curl_payload 3 | jq '.force')" "true"
}

@test "--tag-minor derives the Minor Tag correctly for multi-digit MAJOR and MINOR" {
  stub_curl_sequence \
    201 '{"html_url": "https://example.invalid/releases/tag/v10.42.2"}' \
    200 '{"object": {"sha": "commitsha123", "type": "commit"}}' \
    201 '{"ref": "refs/tags/v10.42", "object": {"sha": "commitsha123"}}'

  run_release --repo octocat/hello-world --tag v10.42.2 --tag-minor
  assert_success
  assert_equal "$(curl_payload 2 | jq -r '.ref')" "refs/tags/v10.42"
}

@test "a failure force-moving the Minor Tag fails the run even though the Release succeeded" {
  stub_curl_sequence \
    201 '{"html_url": "https://example.invalid/releases/tag/v1.4.2"}' \
    200 '{"object": {"sha": "commitsha123", "type": "commit"}}' \
    422 '{"message": "Reference already exists"}' \
    500 '{"message": "Internal Server Error"}'

  run_release --repo octocat/hello-world --tag v1.4.2 --tag-minor
  assert_failure
  assert_output --partial "Internal Server Error"
  refute_output --partial "https://example.invalid"
}

@test "--tag-major and --tag-minor combined move both tags in one invocation, sharing one SHA resolve" {
  stub_curl_sequence \
    201 '{"html_url": "https://example.invalid/releases/tag/v1.4.2"}' \
    200 '{"object": {"sha": "commitsha123", "type": "commit"}}' \
    201 '{"ref": "refs/tags/v1", "object": {"sha": "commitsha123"}}' \
    201 '{"ref": "refs/tags/v1.4", "object": {"sha": "commitsha123"}}'

  run_release --repo octocat/hello-world --tag v1.4.2 --tag-major --tag-minor
  assert_success
  assert_equal "$(curl_call_count)" "4"

  # Call 1: the single SHA resolve, shared by both moving tags.
  assert_equal "$(curl_request_url 1)" "https://api.github.com/repos/octocat/hello-world/git/refs/tags/v1.4.2"

  # Call 2: Major Tag created first ...
  assert_equal "$(curl_payload 2 | jq -r '.ref')" "refs/tags/v1"

  # ... call 3: ... then the Minor Tag.
  assert_equal "$(curl_payload 3 | jq -r '.ref')" "refs/tags/v1.4"
}

@test "--tag-minor alone does not touch the Major Tag" {
  stub_curl_sequence \
    201 '{"html_url": "https://example.invalid/releases/tag/v1.4.2"}' \
    200 '{"object": {"sha": "commitsha123", "type": "commit"}}' \
    201 '{"ref": "refs/tags/v1.4", "object": {"sha": "commitsha123"}}'

  run_release --repo octocat/hello-world --tag v1.4.2 --tag-minor
  assert_success
  assert_equal "$(curl_call_count)" "3"
}
