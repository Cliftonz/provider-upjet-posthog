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
delete_observed() {
  api "organizations/$POSTHOG_ORGANIZATION_ID/roles/$observed_role_id/" -X DELETE
  api "projects/$POSTHOG_PROJECT_ID/insights/$observed_insight_id/" -X PATCH -d '{"deleted": true}' > /dev/null
}
trap delete_observed EXIT

mkdir -p _output
cat > _output/e2e-datasource.yaml <<EOF
POSTHOG_TEST_USER_UUID: "$POSTHOG_TEST_USER_UUID"
OBSERVED_ROLE_ID: "$observed_role_id"
OBSERVED_INSIGHT_ID: "$observed_insight_id"
EOF

CLUSTER="${E2E_CLUSTER:-posthog-e2e}"
LANES=("$CLUSTER" "$CLUSTER-lane1" "$CLUSTER-lane2")
UPTEST_CLOUD_CREDENTIALS="$(jq -n --arg api_key "$POSTHOG_API_KEY" --arg host "http://$CLUSTER-control-plane:30800" \
  --arg organization_id "$POSTHOG_ORGANIZATION_ID" --arg project_id "$POSTHOG_PROJECT_ID" \
  '{$api_key, $host, $organization_id, $project_id}')"
export UPTEST_CLOUD_CREDENTIALS
export UPTEST_DATASOURCE_PATH="$PWD/_output/e2e-datasource.yaml"

start=$SECONDS
phase() {
  echo "e2e-timing $1 $((SECONDS - start))s"
  start=$SECONDS
}

mkdir -p _output/lanes
pids=()
for lane in "${LANES[@]}"; do
  if ! kind get clusters | grep -x "$lane" > /dev/null; then
    kind create cluster --name "$lane" --image "$(sed -n 's/^KIND_NODE_IMAGE=//p' test/harness/images.env)" --kubeconfig "_output/lanes/$lane.kubeconfig" &
    pids+=($!)
  fi
done

hash="$(find apis config internal cmd/provider package cluster/images go.mod go.sum -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)"
rebuilt=false
if [ ! -f _output/e2e-provider.sha256 ] || [ "$(cat _output/e2e-provider.sha256)" != "$hash" ]; then
  rebuilt=true
  rm -rf _output/xpkg
  make build PLATFORMS=linux_amd64
  echo "$hash" > _output/e2e-provider.sha256
fi
phase provider-build

for pid in "${pids[@]}"; do
  wait "$pid"
done
phase lane-clusters

deploy() (
  kind export kubeconfig --name "$1" --kubeconfig "_output/lanes/$1.kubeconfig"
  export KUBECONFIG="$PWD/_output/lanes/$1.kubeconfig"
  make controlplane.up KIND_CLUSTER_NAME="$1" \
    CROSSPLANE_VERSION="$(sed -n 's/^ *version: ">=v\(.*\)"$/\1/p' package/crossplane.yaml)"
  kubectl -n crossplane-system wait --for=condition=Available deployment --all --timeout=5m
  make e2e.provider KIND_CLUSTER_NAME="$1" LOCAL_XPKG_DIGEST="sha256:$hash" DRC_FILE=cluster/test/runtimeconfig.yaml
  kubectl wait provider.pkg provider-posthog --for=jsonpath='{.status.currentIdentifier}'="xpkg.crossplane.internal/dev/provider-posthog@sha256:$hash" --timeout=5m
  if $rebuilt; then
    kubectl -n crossplane-system delete pod -l pkg.crossplane.io/provider=provider-posthog
  fi
  kubectl -n crossplane-system wait --for=condition=Available deployment --all --timeout=5m
)
for lane in "${LANES[@]}"; do
  deploy "$lane"
done
phase provider-install

diagnose() {
  kubectl get managed -o wide
  kubectl -n crossplane-system logs -l pkg.crossplane.io/provider=provider-posthog --tail=200
  KUBECONFIG="$PWD/_output/lanes/$CLUSTER.kubeconfig" kubectl -n posthog get pods -o custom-columns=NAME:.metadata.name,READY:.status.containerStatuses[*].ready,RESTARTS:.status.containerStatuses[*].restartCount,LAST:.status.containerStatuses[*].lastState.terminated.reason,EXIT:.status.containerStatuses[*].lastState.terminated.exitCode
  KUBECONFIG="$PWD/_output/lanes/$CLUSTER.kubeconfig" kubectl -n posthog get events --sort-by=.lastTimestamp | tail -50
  free -m
}

run_lane() (
  export KUBECONFIG="$PWD/_output/lanes/$1.kubeconfig"
  while read -r _ examples; do
    for example in $examples; do
      if ! make uptest UPTEST_EXAMPLE_LIST="$example" UPTEST_ARGS="--test-directory=$PWD/_output/uptest/$1" 2>&1 | sed "s/^/[$1] /"; then
        echo "$example" >> "_output/lanes/$1.failed"
        diagnose 2>&1 | sed "s/^/[$1] /"
        break 2
      fi
    done
  done < "_output/lanes/$1.jobs"
  echo "e2e-timing lane-$1 $((SECONDS - start))s"
  [ ! -s "_output/lanes/$1.failed" ]
)

for lane in "${LANES[@]}"; do
  : > "_output/lanes/$lane.jobs"
  : > "_output/lanes/$lane.failed"
done
mapfile -t examples < <(find examples/namespaced -path '*/v1alpha1/*.yaml' | sort | xargs grep -L upjet.upbound.io/manual-intervention)
{
  echo "test-user $(grep -l POSTHOG_TEST_USER_UUID "${examples[@]}" | xargs)"
  grep -L POSTHOG_TEST_USER_UUID "${examples[@]}" | sed 's#^examples/namespaced/\([^/]*\)/v1alpha1/\(.*\)\.yaml$#\1-\2 &#'
} | awk -v lanes="${LANES[*]}" '{n = split(lanes, l, " "); print > ("_output/lanes/" l[NR % n + 1] ".jobs")}'

pids=()
for lane in "${LANES[@]}"; do
  run_lane "$lane" &
  pids+=($!)
done
failed=0
for pid in "${pids[@]}"; do
  wait "$pid" || failed=1
done
phase tests
for lane in "${LANES[@]}"; do
  sed "s/^/e2e-failed [$lane] /" "_output/lanes/$lane.failed"
done
exit "$failed"
