#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
MR=accesscontrol.access.posthog.m.clifton.quest/example-accesscontrol-default
object() {
  get "projects/$POSTHOG_PROJECT_ID/resource_access_controls/" '.access_controls[] | select(.resource == "survey" and .role == null and .organization_member == null)'
}
UPDATED='.access_level == "editor"'
assert_api "$@"
