#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

# usage: bump.sh VERSION FORK_TAG FORK_DIR
set -euo pipefail

version=$1
fork_tag=$2
fork=$3

go mod edit \
  -require="github.com/posthog/terraform-provider@v${version}" \
  -replace="github.com/posthog/terraform-provider=github.com/${FORK_REPO}@${fork_tag}"

ours=$(go mod edit -json | jq -r .Go)
upstream=$(go mod edit -json "$fork/go.mod" | jq -r .Go)
if [ "$(printf '%s\n%s\n' "$ours" "$upstream" | sort -V | tail -n1)" != "$ours" ]; then
  go mod edit -go="$upstream"
fi

sed -i \
  -e "s/^export TERRAFORM_PROVIDER_VERSION ?= .*/export TERRAFORM_PROVIDER_VERSION ?= ${version}/" \
  -e "s/^export TERRAFORM_PROVIDER_REF ?= .*/export TERRAFORM_PROVIDER_REF ?= ${fork_tag}/" \
  Makefile

go mod tidy
