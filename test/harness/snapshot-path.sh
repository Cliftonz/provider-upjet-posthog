#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

set -euo pipefail

cd "$(dirname "$0")"
echo "${XDG_CACHE_HOME:-$HOME/.cache}/posthog-e2e/$(cat images.env bootstrap.py manifests/* | sha256sum | cut -d" " -f1).tar"
