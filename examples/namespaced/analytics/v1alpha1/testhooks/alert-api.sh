#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
MR=alert.analytics.posthog.m.clifton.quest/example-alert
object() {
  get "environments/$POSTHOG_PROJECT_ID/alerts/$(at id)/"
}
UPDATED='.name == "example-alert-updated"'
assert_api "$@"
