#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
assert_lifecycle dashboard.dashboard.posthog.m.clifton.quest/example-dashboard "projects/$POSTHOG_PROJECT_ID/dashboards"
