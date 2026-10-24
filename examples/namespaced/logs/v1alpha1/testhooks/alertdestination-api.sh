#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
MR=alertdestination.logs.posthog.m.clifton.quest/checkout-errors-oncall
object() {
  get "projects/$POSTHOG_PROJECT_ID/logs/alerts/$(at alertId)/" '.destinations[] | select(.hog_function_ids | contains($at.hogFunctionIds))'
}
assert_api "$@"
