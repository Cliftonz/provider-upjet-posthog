#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
MR=layout.dashboard.posthog.m.clifton.quest/example-layout
object() {
  get "projects/$POSTHOG_PROJECT_ID/dashboards/$(at dashboardId)/"
}
CREATED='[.tiles[] | .text.body // .insight.name] | sort == ["## Key metrics", "example-layout-insight"]'
assert_api "$@"
