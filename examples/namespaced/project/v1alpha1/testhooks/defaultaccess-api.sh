#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
MR=defaultaccess.project.posthog.m.clifton.quest/example-defaultaccess
object() {
  get "projects/$(at projectId)/access_controls/" '.access_controls[] | select(.role == null and .organization_member == null)'
}
CREATED='.access_level == "member"'
UPDATED='.access_level == "none"'
assert_api "$@"
