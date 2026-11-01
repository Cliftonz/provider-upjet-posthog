#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

# usage: snapshot-check.sh
# Bakes the harness snapshot on a fresh cluster E2E_CLUSTER when none exists, then boots
# another fresh one from it and fails if PostHog's startup migrate applied any Django
# migration after the cluster was created.
set -euo pipefail

if [ ! -f "$(test/harness/snapshot-path.sh)" ]; then
  hack/harness-fresh.sh true
fi

migrations_applied_after_boot() {
  local created
  created=$(kubectl --context "kind-$E2E_CLUSTER" get nodes -o jsonpath='{.items[0].metadata.creationTimestamp}')
  kubectl --context "kind-$E2E_CLUSTER" -n posthog exec deploy/db -- \
    psql -U posthog -d posthog -Atc "SELECT count(*) FROM django_migrations WHERE applied >= '$created'"
}
export -f migrations_applied_after_boot
hack/harness-fresh.sh bash -c 'applied=$(migrations_applied_after_boot); echo "snapshot-check migrations applied after boot: $applied"; [ "$applied" = 0 ]'
