#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
echo "${XDG_CACHE_HOME:-$HOME/.cache}/posthog-e2e/$(cat images.env bootstrap.py manifests/* | sha256sum | cut -d" " -f1).tar"
