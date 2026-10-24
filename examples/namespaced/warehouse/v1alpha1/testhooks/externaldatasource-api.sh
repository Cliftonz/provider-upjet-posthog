#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

. "$(dirname "$0")/../../../testhooks/posthog.sh"
MR=externaldatasource.warehouse.posthog.m.clifton.quest/postgres-source
object() {
  get "projects/$POSTHOG_PROJECT_ID/external_data_sources/$(at id)/"
}
CREATED='.source_type == "Postgres" and .prefix == "e2e_" and .job_inputs.host == "source-db.posthog.svc.cluster.local" and ([.schemas[] | select(.should_sync) | .name] | sort) == ["orders", "users"]'
UPDATED='.job_inputs.host == "source-db.posthog.svc"'
assert_api "$@"
if [ $# = 0 ]; then
  ${KUBECTL} -n default patch "$MR" --type merge -p '{"spec":{"forProvider":{"jobInputsJsonSecretRef":{"key":"jobInputsUpdated"}}}}'
  until object | jq -e "$UPDATED"; do
    sleep 5
  done
fi
