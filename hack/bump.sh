#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

# usage: bump.sh VERSION
set -euo pipefail

version=$1
module=github.com/posthog/terraform-provider@v${version}

go mod edit -require="$module"

ours=$(go mod edit -json | jq -r .Go)
upstream=$(go mod edit -json "$(go mod download -json "$module" | jq -r .GoMod)" | jq -r .Go)
if [ "$(printf '%s\n%s\n' "$ours" "$upstream" | sort -V | tail -n1)" != "$ours" ]; then
  go mod edit -go="$upstream"
fi

sed -i \
  -e "s/^export TERRAFORM_PROVIDER_VERSION ?= .*/export TERRAFORM_PROVIDER_VERSION ?= ${version}/" \
  -e "s/^export TERRAFORM_PROVIDER_REF ?= .*/export TERRAFORM_PROVIDER_REF ?= v${version}/" \
  Makefile

go mod tidy
