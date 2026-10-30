#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

# usage: push-xpkg.sh REGISTRY/ORG/REPO:TAG
set -euo pipefail

ref=$1
up_version=v0.55.2
crossplane_version=$(sed -n 's/^CROSSPLANE_CLI_VERSION = //p' Makefile)
bin=$(mktemp -d)
curl -fsSLo "$bin/crossplane" "https://releases.crossplane.io/stable/${crossplane_version}/bin/linux_amd64/crank"
curl -fsSLo "$bin/up" "https://cli.upbound.io/stable/${up_version}/bin/linux_amd64/up"
chmod +x "$bin/crossplane" "$bin/up"

if out=$(docker buildx imagetools inspect "$ref" 2>&1); then
  echo "$ref exists"
  exit 0
fi
if ! grep -q 'not found' <<< "$out"; then
  echo "$out" >&2
  exit 1
fi
files=()
for f in xpkg/*/provider-posthog-"${ref##*:}".xpkg; do
  files+=(--package-files "$f")
done
"$bin/crossplane" xpkg push "${files[@]}" "$ref"
"$bin/up" xpkg append --extensions-root=extensions "$ref"
