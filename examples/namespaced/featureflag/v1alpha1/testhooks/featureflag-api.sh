#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
assert_lifecycle featureflag.featureflag.posthog.m.clifton.quest/example-boolean "projects/$POSTHOG_PROJECT_ID/feature_flags"
