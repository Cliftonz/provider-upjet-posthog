#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
MR=alert.analytics.posthog.m.clifton.quest/example-alert
object() {
  get "environments/$POSTHOG_PROJECT_ID/alerts/$(at id)/"
}
CREATED='.enabled == true and .skip_weekend == true and .config.check_ongoing_interval == true and .threshold.configuration.bounds.lower == 1 and .schedule_restriction.blocked_windows == [{"start": "22:00", "end": "06:00"}]'
UPDATED='.name == "example-alert-updated"'
assert_api "$@"
