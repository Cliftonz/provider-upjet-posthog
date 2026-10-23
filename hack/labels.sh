#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

# usage: labels.sh
set -euo pipefail

for label in upstream-tracking fork-rebase fork-fix generation build test breaking-change new-resource publish release skip; do
  gh label create "$label" --color ededed --force
done
