#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
MR=hogfunction.cdp.posthog.m.clifton.quest/teams-destination
object() {
  get "environments/$POSTHOG_PROJECT_ID/hog_functions/$(at id)/"
}
UPDATED='.description == "Updated description"'
assert_api "$@"
