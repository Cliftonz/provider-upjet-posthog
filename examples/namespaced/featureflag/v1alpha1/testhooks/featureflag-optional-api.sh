#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
MR=featureflag.featureflag.posthog.m.clifton.quest/example-optional
object() {
  get "projects/$POSTHOG_PROJECT_ID/feature_flags/$(at id)/"
}
CREATED='.active == false and .archived == true and .bucketing_identifier == "device_id" and .ensure_experience_continuity == false and .evaluation_contexts == ["web"] and .evaluation_runtime == "server" and .is_remote_configuration == true'
UPDATED='.evaluation_runtime == "client"'
assert_api "$@"
