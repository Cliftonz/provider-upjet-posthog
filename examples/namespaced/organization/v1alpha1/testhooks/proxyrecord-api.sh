#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
MR=proxyrecord.organization.posthog.m.clifton.quest/example-proxyrecord
object() {
  get "organizations/$POSTHOG_ORGANIZATION_ID/proxy_records/$(at id)/"
}
assert_api "$@"
