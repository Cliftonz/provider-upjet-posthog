#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

load helpers

@test "skips the check when there is no release yet" {
  setup_stubs
  stub gh
  run "$ROOT/hack/breaking-changes.sh" crds
  [ "$status" -eq 0 ]
  [ "$output" = "no release yet; skipping the breaking-change check" ]
}
