#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

load helpers

setup() {
  setup_stubs
  cd "$BATS_TEST_TMPDIR"
  git init -q .
  mkdir hack
  cp "$ROOT/hack/repo-checks.sh" hack/
  git add hack
  echo 'export TERRAFORM_PROVIDER_REF ?= v1.0.27-public' > Makefile
  pin=v1.0.27-public
  deps=github.com/crossplane/upjet
}

stub_go() {
  stub go "if [ \"\$1\" = list ]; then echo $deps; else echo '{\"Replace\":[{\"Old\":{\"Path\":\"github.com/posthog/terraform-provider\"},\"New\":{\"Version\":\"$pin\"}}]}'; fi"
}

@test "passes a consistent repository" {
  stub_go
  run hack/repo-checks.sh
  [ "$status" -eq 0 ]
}

@test "accepts a commit ref matching a pseudo-version pin" {
  pin=v1.0.25-0.20261024120000-e6958dd16efc
  echo 'export TERRAFORM_PROVIDER_REF ?= e6958dd16efc20fd6f210cd14c926095b9cffa1a' > Makefile
  stub_go
  run hack/repo-checks.sh
  [ "$status" -eq 0 ]
}

@test "fails on a script that is not executable" {
  stub_go
  echo true > hack/plain.sh
  git add hack/plain.sh
  run hack/repo-checks.sh
  [ "$status" -eq 1 ]
  [[ $output == *"hack/plain.sh"* ]]
}

@test "fails when the tracking tool links the upstream provider" {
  deps=github.com/posthog/terraform-provider/provider
  stub_go
  run hack/repo-checks.sh
  [ "$status" -eq 1 ]
  [[ $output == *"cmd/tracking links the upstream provider"* ]]
}

@test "fails when the Makefile ref differs from the fork pin" {
  pin=v1.0.26-public
  stub_go
  run hack/repo-checks.sh
  [ "$status" -eq 1 ]
  [[ $output == *"does not match the go.mod fork pin v1.0.26-public"* ]]
}
