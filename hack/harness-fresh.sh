#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

# usage: harness-fresh.sh COMMAND [ARG...]
# Boots the harness in the new kind cluster E2E_CLUSTER, runs COMMAND, then deletes
# the cluster and its lanes whatever COMMAND returned. Refuses a cluster that exists.
set -euo pipefail

cluster=${E2E_CLUSTER:-posthog-e2e}
if kind get clusters | grep -x "$cluster" > /dev/null; then
  echo "kind cluster $cluster exists; harness-fresh.sh only boots a new one" >&2
  exit 1
fi
trap test/harness/down.sh EXIT
test/harness/up.sh
"$@"
