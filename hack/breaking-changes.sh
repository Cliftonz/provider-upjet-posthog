#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

# usage: breaking-changes.sh crds|all
# Prints unacknowledged breaking changes against the latest release and fails
# if there are any; "all" adds config/schema.json to package/crds.
set -euo pipefail

scope=$1
release=$(gh release list --json tagName,isLatest --jq '.[] | select(.isLatest) | .tagName')
if [ -z "$release" ]; then
  echo "no release yet; skipping the breaking-change check" >&2
  exit 0
fi

work=$(mktemp -d)
git archive "$release" config/schema.json package/crds | tar -x -C "$work"
go build -o "$work/tracking" ./cmd/tracking
version=$(sed -n 's/^export TERRAFORM_PROVIDER_VERSION ?= //p' Makefile)

{
  if [ "$scope" = all ]; then
    "$work/tracking" schema-diff "$work/config/schema.json" config/schema.json
  fi
  "$work/tracking" crd-diff "$work/package/crds" package/crds
} | "$work/tracking" gate hack/upstream-acks.yaml "$version" breaking-change
