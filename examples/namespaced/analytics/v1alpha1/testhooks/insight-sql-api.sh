#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
MR=insight.analytics.posthog.m.clifton.quest/example-insight-sql
object() {
  get "projects/$POSTHOG_PROJECT_ID/insights/$(at id)/"
}
CREATED='.query.kind == "DataVisualizationNode" and .query.source.query == "SELECT count() FROM events"'
UPDATED='.name == "example-insight-sql-updated"'
assert_api "$@"
