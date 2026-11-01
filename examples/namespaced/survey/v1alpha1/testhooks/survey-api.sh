#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
MR=survey.survey.posthog.m.clifton.quest/example-nps
object() {
  get "projects/$POSTHOG_PROJECT_ID/surveys/$(at id)/"
}
CREATED='.schedule == "recurring" and .iteration_count == 2 and .iteration_frequency_days == 90 and (.start_date | startswith("2026-12-01")) and (.end_date | startswith("2027-12-01")) and .responses_limit == 100 and .response_sampling_interval_type == "week" and .response_sampling_interval == 1 and .response_sampling_limit == 50 and .enable_partial_responses == true and .enable_iframe_embedding == true and .appearance.backgroundColor == "#eeeeee" and .targeting_flag.filters.groups[0].rollout_percentage == 50'
UPDATED='.description == "Updated description." and .targeting_flag.filters.groups[0].rollout_percentage == 75'
flag="${state%.json}-flag-id"
if [ "${1:-created}" = updated ]; then
  UPDATED="$UPDATED and .targeting_flag.id == $(cat "$flag")"
fi
assert_api "$@"
if [ "${1:-created}" = created ]; then
  object | jq .targeting_flag.id > "$flag"
fi
