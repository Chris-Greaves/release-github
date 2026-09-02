#!/usr/bin/env bats

load test_helper

@test "without --tag-major, --tag stays free-form and no extra API calls are made" {
  stub_curl 201 '{"html_url": "https://example.invalid/releases/tag/not-semver"}'

  run_release --repo octocat/hello-world --tag not-semver
  assert_success
  assert_equal "$(curl_call_count)" "1"
}

@test "--tag-major rejects a non-Release-Tag before any API call" {
  local bad_tag
  for bad_tag in "1.2" "v1.2.3-beta" "v1.2.3+build.5" "v01.2.3" "V1.2.3" "release-2024"; do
    run_release --repo octocat/hello-world --tag "$bad_tag" --tag-major
    assert_failure
    assert_output --partial "Release Tag"
    assert_curl_not_invoked
  done
}

@test "--tag-major accepts a bare MAJOR.MINOR.PATCH tag with no leading v" {
  stub_curl_sequence \
    201 '{"html_url": "https://example.invalid/releases/tag/1.4.2"}' \
    200 '{"object": {"sha": "commitsha123", "type": "commit"}}' \
    201 '{"ref": "refs/tags/v1", "object": {"sha": "commitsha123"}}'

  run_release --repo octocat/hello-world --tag 1.4.2 --tag-major
  assert_success
  assert_equal "$(curl_call_count)" "3"
}

@test "--tag-major creates the Major Tag when it doesn't yet exist" {
  stub_curl_sequence \
    201 '{"html_url": "https://example.invalid/releases/tag/v1.4.2"}' \
    200 '{"object": {"sha": "commitsha123", "type": "commit"}}' \
    201 '{"ref": "refs/tags/v1", "object": {"sha": "commitsha123"}}'

  run_release --repo octocat/hello-world --tag v1.4.2 --tag-major
  assert_success
  assert_output "https://example.invalid/releases/tag/v1.4.2"
  assert_equal "$(curl_call_count)" "3"

  # Call 1: resolves the just-created exact tag's commit SHA.
  assert_equal "$(curl_request_url 1)" "https://api.github.com/repos/octocat/hello-world/git/refs/tags/v1.4.2"

  # Call 2: create attempted directly; absent -> succeeds via POST git/refs.
  assert_equal "$(curl_request_method 2)" "POST"
  assert_equal "$(curl_request_url 2)" "https://api.github.com/repos/octocat/hello-world/git/refs"
  assert_equal "$(curl_payload 2 | jq -r '.ref')" "refs/tags/v1"
  assert_equal "$(curl_payload 2 | jq -r '.sha')" "commitsha123"
}

@test "--tag-major force-moves the Major Tag when it already exists" {
  stub_curl_sequence \
    201 '{"html_url": "https://example.invalid/releases/tag/v1.4.2"}' \
    200 '{"object": {"sha": "commitsha123", "type": "commit"}}' \
    422 '{"message": "Reference already exists"}' \
    200 '{"ref": "refs/tags/v1", "object": {"sha": "commitsha123"}}'

  run_release --repo octocat/hello-world --tag v1.4.2 --tag-major
  assert_success
  assert_equal "$(curl_call_count)" "4"

  # Call 2: create attempted first, fails with "already exists" ...
  assert_equal "$(curl_request_method 2)" "POST"

  # ... call 3: ... so it falls back to a force-move via PATCH.
  assert_equal "$(curl_request_method 3)" "PATCH"
  assert_equal "$(curl_request_url 3)" "https://api.github.com/repos/octocat/hello-world/git/refs/tags/v1"
  assert_equal "$(curl_payload 3 | jq -r '.sha')" "commitsha123"
  assert_equal "$(curl_payload 3 | jq '.force')" "true"
}

@test "--tag-major derives a multi-digit Major Tag correctly" {
  stub_curl_sequence \
    201 '{"html_url": "https://example.invalid/releases/tag/v10.4.2"}' \
    200 '{"object": {"sha": "commitsha123", "type": "commit"}}' \
    201 '{"ref": "refs/tags/v10", "object": {"sha": "commitsha123"}}'

  run_release --repo octocat/hello-world --tag v10.4.2 --tag-major
  assert_success
  assert_equal "$(curl_payload 2 | jq -r '.ref')" "refs/tags/v10"
}

@test "resolving an annotated Release Tag dereferences the tag object to reach its commit" {
  stub_curl_sequence \
    201 '{"html_url": "https://example.invalid/releases/tag/v1.4.2"}' \
    200 '{"object": {"sha": "tagobjectsha", "type": "tag"}}' \
    200 '{"object": {"sha": "commitsha123"}}' \
    201 '{"ref": "refs/tags/v1", "object": {"sha": "commitsha123"}}'

  run_release --repo octocat/hello-world --tag v1.4.2 --tag-major
  assert_success
  assert_equal "$(curl_call_count)" "4"

  # Call 2: dereferences the annotated tag object via git/tags/<sha> ...
  assert_equal "$(curl_request_url 2)" "https://api.github.com/repos/octocat/hello-world/git/tags/tagobjectsha"

  # ... call 3: ... and the Major Tag ends up pointed at the commit, not the tag object.
  assert_equal "$(curl_payload 3 | jq -r '.sha')" "commitsha123"
}

@test "a failure resolving the exact tag's commit SHA fails the run" {
  stub_curl_sequence \
    201 '{"html_url": "https://example.invalid/releases/tag/v1.4.2"}' \
    404 '{"message": "Not Found"}'

  run_release --repo octocat/hello-world --tag v1.4.2 --tag-major
  assert_failure
  assert_output --partial "Not Found"
  assert_equal "$(curl_call_count)" "2"
}

@test "a failure creating the Major Tag that isn't 'already exists' fails the run without attempting a move" {
  stub_curl_sequence \
    201 '{"html_url": "https://example.invalid/releases/tag/v1.4.2"}' \
    200 '{"object": {"sha": "commitsha123", "type": "commit"}}' \
    422 '{"message": "Validation Failed"}'

  run_release --repo octocat/hello-world --tag v1.4.2 --tag-major
  assert_failure
  assert_output --partial "Validation Failed"
  assert_equal "$(curl_call_count)" "3"
}

@test "a failure force-moving the Major Tag fails the run even though the Release succeeded" {
  stub_curl_sequence \
    201 '{"html_url": "https://example.invalid/releases/tag/v1.4.2"}' \
    200 '{"object": {"sha": "commitsha123", "type": "commit"}}' \
    422 '{"message": "Reference already exists"}' \
    500 '{"message": "Internal Server Error"}'

  run_release --repo octocat/hello-world --tag v1.4.2 --tag-major
  assert_failure
  assert_output --partial "Internal Server Error"
  refute_output --partial "https://example.invalid"
}
