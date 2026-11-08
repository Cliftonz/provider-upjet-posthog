#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

load helpers

setup() {
  setup_stubs
  export UPSTREAM_REPO=PostHog/terraform-provider-posthog GITHUB_SERVER_URL=https://github.com \
    GITHUB_REPOSITORY=owner/repo GITHUB_RUN_ID=42
}

@test "opens a labeled issue when none with the title is open" {
  stub gh
  run "$ROOT/hack/failure-issue.sh" 1.0.2 build build
  [ "$status" -eq 0 ]
  grep -qF "gh issue create --title Upstream v1.0.2: build --label upstream-tracking --label build --body Upstream release: https://github.com/PostHog/terraform-provider-posthog/releases/tag/v1.0.2" "$CALLS"
  grep -qxF "Workflow run: https://github.com/owner/repo/actions/runs/42" "$CALLS"
}

@test "comments on the open issue with the same title" {
  stub gh '[ "$1 $2" != "issue list" ] || echo 7'
  run "$ROOT/hack/failure-issue.sh" 1.0.2 build build
  [ "$status" -eq 0 ]
  grep -qF "gh issue comment 7 --body Upstream release:" "$CALLS"
  ! grep -q "issue create" "$CALLS"
}

@test "lists the affected resources and fields" {
  stub gh
  printf 'posthog_dashboard.description\nposthog_insight\n' > "$BATS_TEST_TMPDIR/affected"
  run "$ROOT/hack/failure-issue.sh" 1.0.2 "breaking-change gate" breaking-change "$BATS_TEST_TMPDIR/affected"
  [ "$status" -eq 0 ]
  grep -qxF "Affected resources and fields:" "$CALLS"
  grep -qxF -- "- posthog_dashboard.description" "$CALLS"
  grep -qxF -- "- posthog_insight" "$CALLS"
}
