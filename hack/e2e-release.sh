#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

# usage: e2e-release.sh VERSION
# Runs the install check, then e2e against the released Upbound package VERSION (vX.Y.Z),
# on the running harness E2E_CLUSTER.
set -euo pipefail

hack/install-check.sh "$1"
E2E_PACKAGE="xpkg.upbound.io/cliftonz/provider-upjet-posthog:$1" hack/e2e.sh
