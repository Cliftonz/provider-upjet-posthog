#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

# usage: validate-examples.sh
set -euo pipefail

cluster=posthog-validate
export KUBECONFIG
KUBECONFIG=$(mktemp)
kind create cluster --name "$cluster" --image "$(sed -n 's/^KIND_NODE_IMAGE=//p' test/harness/images.env)" --kubeconfig "$KUBECONFIG"
trap 'kind delete cluster --name "$cluster"; rm -f "$KUBECONFIG"' EXIT

kubectl apply --server-side -f package/crds
kubectl wait --for condition=established --timeout=120s crd --all
grep -rhoP '^\s+namespace:\s*\K\S+' examples/namespaced | sort -u | while read -r ns; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done
kubectl apply --dry-run=server -R -f examples/namespaced
