#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
MR=role.access.posthog.m.clifton.quest/example-role
object() {
  get "organizations/$POSTHOG_ORGANIZATION_ID/roles/$(at id)/"
}
UPDATED='.name == "example-role-updated"'
assert_api "$@"
