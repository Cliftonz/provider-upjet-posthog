#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
MR=settings.project.posthog.m.clifton.quest/example-settings
object() {
  get "environments/$(at projectId)/"
}
CREATED='.anonymize_ips == false'
UPDATED='.anonymize_ips == true'
assert_api "$@"
