#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
CLUSTER="${E2E_CLUSTER:-posthog-e2e}"
for lane in "$CLUSTER" "$CLUSTER-lane1" "$CLUSTER-lane2"; do
  kind delete cluster --name "$lane"
done
rm -f .out/posthog.env
