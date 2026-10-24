#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
MR=rolemembership.access.posthog.m.clifton.quest/example-rolemembership
object() {
  get "organizations/$POSTHOG_ORGANIZATION_ID/roles/$(at roleId)/role_memberships/$(at id)/"
}
assert_api "$@"
