#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
MR=insightvariable.analytics.posthog.m.clifton.quest/example-insightvariable
object() {
  get "projects/$POSTHOG_PROJECT_ID/insight_variables/$(at id)/"
}
UPDATED='.name == "example-environment-updated"'
assert_api "$@"
