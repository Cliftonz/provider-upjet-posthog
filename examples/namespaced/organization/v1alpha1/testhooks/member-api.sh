#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
MR=member.organization.posthog.m.clifton.quest/example-orgmember
object() {
  get "organizations/$POSTHOG_ORGANIZATION_ID/members/" '.results[] | select(.user.uuid == $at.userUuid)'
}
UPDATED='.level == 8'
DELETED='. != null'
assert_api "$@"
