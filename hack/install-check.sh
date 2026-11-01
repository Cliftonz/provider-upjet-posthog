#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

# usage: install-check.sh VERSION
# Checks that the released package VERSION (vX.Y.Z) pulls without credentials from
# Upbound and GHCR, then, for each registry, installs it into a throwaway kind cluster
# against the running harness E2E_CLUSTER and creates, reads and deletes a FeatureFlag.
set -euo pipefail

version=$1
cluster=${E2E_CLUSTER:-posthog-e2e}
check=$cluster-install
refs=("xpkg.upbound.io/cliftonz/provider-upjet-posthog:$version" "ghcr.io/cliftonz/provider-upjet-posthog:$version")
work=$(mktemp -d)

set -a
# shellcheck source=/dev/null
. "test/harness/.out/$cluster.env"
set +a

for ref in "${refs[@]}"; do
  DOCKER_CONFIG=$work/docker docker manifest inspect "$ref" > /dev/null
  echo "install-check anonymous pull ok: $ref"
done

flag() {
  curl -fsS -H "Authorization: Bearer $POSTHOG_API_KEY" "$POSTHOG_HOST/api/projects/$POSTHOG_PROJECT_ID/feature_flags/$1/"
}

export KUBECONFIG=$work/kubeconfig
export KUBECTL=kubectl
UPTEST_CLOUD_CREDENTIALS="$(jq -n --arg api_key "$POSTHOG_API_KEY" --arg host "http://$cluster-control-plane:30800" \
  --arg organization_id "$POSTHOG_ORGANIZATION_ID" --arg project_id "$POSTHOG_PROJECT_ID" \
  '{$api_key, $host, $organization_id, $project_id}')"
export UPTEST_CLOUD_CREDENTIALS
for ref in "${refs[@]}"; do
  kind create cluster --name "$check" --image "$(sed -n 's/^KIND_NODE_IMAGE=//p' test/harness/images.env)" --kubeconfig "$KUBECONFIG"
  trap 'kind delete cluster --name "$check"' EXIT
  make controlplane.up KIND_CLUSTER_NAME="$check" \
    CROSSPLANE_VERSION="$(sed -n 's/^ *version: ">=v\(.*\)"$/\1/p' package/crossplane.yaml)"
  kubectl -n crossplane-system wait --for=condition=Available deployment --all --timeout=5m
  kubectl apply -f - <<EOF
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-posthog
spec:
  package: $ref
EOF
  cluster/test/setup.sh
  key="install-check-$(date +%s)"
  kubectl apply -f - <<EOF
apiVersion: featureflag.posthog.m.clifton.quest/v1alpha1
kind: FeatureFlag
metadata:
  name: install-check
  namespace: default
spec:
  forProvider:
    key: $key
    name: install check
    active: true
    filters: |
      {"groups":[{"properties":[],"rollout_percentage":100}]}
  providerConfigRef:
    kind: ProviderConfig
    name: default
EOF
  for condition in Synced Ready; do
    kubectl -n default wait featureflag.featureflag.posthog.m.clifton.quest/install-check --for=condition=$condition --timeout=10m
  done
  id=$(kubectl -n default get featureflag.featureflag.posthog.m.clifton.quest/install-check -o jsonpath='{.status.atProvider.id}')
  flag "$id" | jq -e --arg key "$key" '.key == $key and .deleted == false' > /dev/null
  kubectl -n default delete featureflag.featureflag.posthog.m.clifton.quest/install-check --timeout=10m
  flag "$id" | jq -e '.deleted == true' > /dev/null
  echo "install-check feature flag round trip ok: $ref"
  kind delete cluster --name "$check"
  trap - EXIT
done
rm -rf "$work"
