#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

set -euo pipefail

set -a
. test/harness/.out/posthog.env
set +a

api() {
  curl -fsS -H "Authorization: Bearer $POSTHOG_API_KEY" -H 'Content-Type: application/json' "$POSTHOG_HOST/api/$1" "${@:2}"
}

suffix="$(date +%s)"
observed_role_id="$(api "organizations/$POSTHOG_ORGANIZATION_ID/roles/" \
  -d "$(jq -n --arg name "e2e-observed-$suffix" '{$name}')" | jq -r .id)"
observed_insight_id="$(api "projects/$POSTHOG_PROJECT_ID/insights/" \
  -d "$(jq -n --arg name "e2e-observed-$suffix" '{$name, query: {kind: "InsightVizNode", source: {kind: "TrendsQuery", series: []}}}')" | jq -r .id)"

mkdir -p _output
cat > _output/e2e-datasource.yaml <<EOF
POSTHOG_TEST_USER_UUID: "$POSTHOG_TEST_USER_UUID"
OBSERVED_ROLE_ID: "$observed_role_id"
OBSERVED_INSIGHT_ID: "$observed_insight_id"
EOF

UPTEST_CLOUD_CREDENTIALS="$(jq -n --arg api_key "$POSTHOG_API_KEY" --arg host "$POSTHOG_CLUSTER_HOST" \
  --arg organization_id "$POSTHOG_ORGANIZATION_ID" --arg project_id "$POSTHOG_PROJECT_ID" \
  '{$api_key, $host, $organization_id, $project_id}')"
export UPTEST_CLOUD_CREDENTIALS
export UPTEST_DATASOURCE_PATH="$PWD/_output/e2e-datasource.yaml"

make local-deploy PLATFORMS=linux_amd64 KIND_CLUSTER_NAME=posthog-e2e \
  CROSSPLANE_VERSION="$(sed -n 's/^ *version: ">=v\(.*\)"$/\1/p' package/crossplane.yaml)"
kubectl -n crossplane-system delete pod -l pkg.crossplane.io/provider=provider-posthog
kubectl -n crossplane-system wait --for=condition=Available deployment --all --timeout=5m
for example in $(find examples/namespaced -path '*/v1alpha1/*.yaml' | sort | xargs grep -L upjet.upbound.io/manual-intervention); do
  make uptest UPTEST_EXAMPLE_LIST="$example"
done
