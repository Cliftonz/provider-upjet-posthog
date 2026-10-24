#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
MR=subscription.analytics.posthog.m.clifton.quest/example-subscription
object() {
  get "projects/$POSTHOG_PROJECT_ID/subscriptions/$(at id)/"
}
UPDATED='.title == "example-subscription-updated"'
assert_api "$@"
