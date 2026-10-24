#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
MR=earlyaccessfeature.featureflag.posthog.m.clifton.quest/example-new-editor
object() {
  get "projects/$POSTHOG_PROJECT_ID/early_access_feature/$(at id)/"
}
UPDATED='.description == "Updated description"'
assert_api "$@"
