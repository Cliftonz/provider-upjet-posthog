#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

load helpers

setup() {
  setup_stubs
  stub gh
  export GITHUB_REPOSITORY=owner/repo
  git init -q --bare "$BATS_TEST_TMPDIR/origin.git"
  git init -q "$BATS_TEST_TMPDIR/clone"
  cd "$BATS_TEST_TMPDIR/clone"
  git -c user.name=t -c user.email=t@t commit -q --allow-empty -m one
  first=$(git rev-parse HEAD)
  git -c user.name=t -c user.email=t@t commit -q --allow-empty -m two
  second=$(git rev-parse HEAD)
  git tag v1.0.1 "$first"
  git remote add origin "$BATS_TEST_TMPDIR/origin.git"
  git push -q origin HEAD:refs/heads/main v1.0.1
}

@test "creates the tag through the API when it does not exist" {
  run "$ROOT/hack/tag.sh" 1.0.2 "$second"
  [ "$status" -eq 0 ]
  grep -qxF "gh api repos/owner/repo/git/refs -f ref=refs/tags/v1.0.2 -f sha=$second" "$CALLS"
}

@test "does nothing when the tag exists at the commit" {
  run "$ROOT/hack/tag.sh" 1.0.1 "$first"
  [ "$status" -eq 0 ]
  [ ! -s "$CALLS" ]
}

@test "fails when the tag exists at another commit" {
  run "$ROOT/hack/tag.sh" 1.0.1 "$second"
  [ "$status" -eq 1 ]
  [ "$output" = "v1.0.1 exists at $first, not $second" ]
  [ ! -s "$CALLS" ]
}
