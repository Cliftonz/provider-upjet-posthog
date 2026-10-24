#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
MR=project.project.posthog.m.clifton.quest/example-project
object() {
  get "organizations/$POSTHOG_ORGANIZATION_ID/projects/$(at id)/"
}
UPDATED='.name == "crossplane-e2e-project-updated"'
assert_api "$@"
