#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
MR=insightvariable.analytics.posthog.m.clifton.quest/example-insightvariable-list
object() {
  get "projects/$POSTHOG_PROJECT_ID/insight_variables/$(at id)/"
}
CREATED='.type == "List" and .values == ["us", "eu"]'
UPDATED='.name == "example-region-updated"'
assert_api "$@"
