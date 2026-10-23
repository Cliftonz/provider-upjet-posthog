#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
mr=featureflag.featureflag.posthog.m.clifton.quest/example-maintenance-lock
${KUBECTL} -n default patch "$mr" --type merge -p '{"spec":{"forProvider":{"active":false}}}'
${KUBECTL} -n default wait "$mr" --for=jsonpath="{.status.atProvider.active}"=false --timeout=5m
api "projects/$POSTHOG_PROJECT_ID/feature_flags/$(${KUBECTL} -n default get "$mr" -o jsonpath="{.status.atProvider.id}")/" | jq -e '
  .active == false
  and ([.filters.multivariate.variants[].key] == ["off", "notice", "locked"])
  and (.filters.payloads | keys == ["locked", "notice", "off"])
  and .filters.groups[0].variant == "notice"'
