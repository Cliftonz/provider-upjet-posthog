#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

load helpers

setup() {
  real_go=$(command -v go)
  setup_stubs
  stub go "if [ \"\$1 \$2\" != 'mod tidy' ]; then exec '$real_go' \"\$@\"; fi"
  export FORK_REPO=Owner/fork GOTOOLCHAIN=local
  mkdir "$BATS_TEST_TMPDIR/fork"
  cd "$BATS_TEST_TMPDIR"
  printf 'module example.com/provider\n\ngo 1.27.0\n' > go.mod
  printf 'export TERRAFORM_PROVIDER_VERSION ?= 1.0.1\nexport TERRAFORM_PROVIDER_REF ?= v1.0.1-public\n' > Makefile
}

@test "sets the pins and keeps our go directive when upstream's is not higher" {
  printf 'module github.com/posthog/terraform-provider\n\ngo 1.26.5\n' > fork/go.mod
  run "$ROOT/hack/bump.sh" 1.0.2 v1.0.2-public fork
  [ "$status" -eq 0 ]
  [ "$(go mod edit -json | jq -r .Go)" = 1.27.0 ]
  [ "$(go mod edit -json | jq -r '.Require[0] | "\(.Path)@\(.Version)"')" = github.com/posthog/terraform-provider@v1.0.2 ]
  [ "$(go mod edit -json | jq -r '.Replace[0].New | "\(.Path)@\(.Version)"')" = github.com/Owner/fork@v1.0.2-public ]
  [ "$(cat Makefile)" = "$(printf 'export TERRAFORM_PROVIDER_VERSION ?= 1.0.2\nexport TERRAFORM_PROVIDER_REF ?= v1.0.2-public')" ]
  grep -qxF "go mod tidy" "$CALLS"
}

@test "raises our go directive to upstream's when it is higher" {
  printf 'module github.com/posthog/terraform-provider\n\ngo 1.27.3\n' > fork/go.mod
  run "$ROOT/hack/bump.sh" 1.0.2 v1.0.2-public fork
  [ "$status" -eq 0 ]
  [ "$(go mod edit -json | jq -r .Go)" = 1.27.3 ]
}
