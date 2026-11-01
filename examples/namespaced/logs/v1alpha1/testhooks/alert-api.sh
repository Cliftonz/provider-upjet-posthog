#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
MR=alert.logs.posthog.m.clifton.quest/checkout-errors
object() {
  get "projects/$POSTHOG_PROJECT_ID/logs/alerts/$(at id)/"
}
CREATED='.enabled == true and (.snooze_until | startswith("2027-01-31T09:00:00")) and .filters.filterGroup.values[0].values[0].key == "status_code" and .schedule_restriction.blocked_windows == [{"start": "22:00", "end": "06:00"}]'
UPDATED='.name == "Checkout API errors updated"'
assert_api "$@"
