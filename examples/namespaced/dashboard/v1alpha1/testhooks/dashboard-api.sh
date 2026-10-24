#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
MR=dashboard.dashboard.posthog.m.clifton.quest/example-dashboard
object() {
  get "projects/$POSTHOG_PROJECT_ID/dashboards/$(at id)/"
}
UPDATED='.description == "Updated description"'
assert_api "$@"
