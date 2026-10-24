#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
MR=member.project.posthog.m.clifton.quest/example-projectmember
object() {
  get "projects/$(at projectId)/access_controls/" '.access_controls[] | select(.organization_member == $at.organizationMember)'
}
UPDATED='.access_level == "admin"'
assert_api "$@"
