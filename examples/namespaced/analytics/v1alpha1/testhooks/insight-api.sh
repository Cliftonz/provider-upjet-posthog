#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
MR=insight.analytics.posthog.m.clifton.quest/example-insight
object() {
  get "projects/$POSTHOG_PROJECT_ID/insights/$(at id)/"
}
UPDATED='.name == "example-insight-updated"'
assert_api "$@"
