#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

load helpers

setup() {
  cd "$ROOT"
  unset VERSION MAKEFLAGS MAKELEVEL
}

@test "e2e-release requires VERSION" {
  run make -n e2e-release
  [ "$status" -ne 0 ]
  [[ $output == *"VERSION is required, e.g. VERSION=v1.0.27"* ]]
}

@test "install-check requires VERSION" {
  run make -n install-check
  [ "$status" -ne 0 ]
  [[ $output == *"VERSION is required, e.g. VERSION=v1.0.27"* ]]
}
