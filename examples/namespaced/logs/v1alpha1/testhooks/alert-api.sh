#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
MR=alert.logs.posthog.m.clifton.quest/checkout-errors
object() {
  get "projects/$POSTHOG_PROJECT_ID/logs/alerts/$(at id)/"
}
UPDATED='.name == "Checkout API errors updated"'
assert_api "$@"
