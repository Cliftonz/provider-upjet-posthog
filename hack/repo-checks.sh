#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

# usage: repo-checks.sh
set -euo pipefail

if git ls-files -s -- '*.sh' | grep -v '^100755'; then
  echo "scripts above are not mode 100755" >&2
  exit 1
fi

if go list -deps ./cmd/tracking | grep '^github.com/posthog/terraform-provider'; then
  echo "cmd/tracking links the upstream provider" >&2
  exit 1
fi

pin=$(go mod edit -json | jq -r '.Replace[] | select(.Old.Path == "github.com/posthog/terraform-provider") | .New.Version')
ref=$(sed -n 's/^export TERRAFORM_PROVIDER_REF ?= //p' Makefile)
if [[ $ref != "$pin" && $ref != "${pin##*-}"* ]]; then
  echo "Makefile TERRAFORM_PROVIDER_REF $ref does not match the go.mod fork pin $pin" >&2
  exit 1
fi
