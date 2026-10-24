#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
MR=survey.survey.posthog.m.clifton.quest/example-nps
object() {
  get "projects/$POSTHOG_PROJECT_ID/surveys/$(at id)/"
}
UPDATED='.description == "Updated description."'
assert_api "$@"
