#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
MR=featureflag.featureflag.posthog.m.clifton.quest/example-boolean
object() {
  get "projects/$POSTHOG_PROJECT_ID/feature_flags/$(at id)/"
}
UPDATED='.name == "Example boolean flag updated"'
assert_api "$@"
