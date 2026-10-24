#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
MR=action.analytics.posthog.m.clifton.quest/example-action
object() {
  get "projects/$POSTHOG_PROJECT_ID/actions/$(at id)/"
}
UPDATED='.description == "Updated description"'
assert_api "$@"
