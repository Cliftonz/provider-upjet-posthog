#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

load helpers

setup() {
  setup_stubs
  export TMPDIR=$BATS_TEST_TMPDIR
  stub git 'case $1 in ls-remote) printf "x\trefs/tags/v%s\n" 1.0.0 1.0.1 1.0.2-rc.1 ;; esac'
}

@test "refuses the oldest stable version without SIM_LATEST" {
  SIM_VERSION=1.0.0 run "$ROOT/hack/simulate-tracking.sh"
  [ "$status" -eq 1 ]
  [[ $output == *"v1.0.0 is not a stable upstream release with a predecessor; set SIM_LATEST"* ]]
}

@test "refuses a version that is not a stable tag without SIM_LATEST" {
  SIM_VERSION=1.0.2-rc.1 run "$ROOT/hack/simulate-tracking.sh"
  [ "$status" -eq 1 ]
  [[ $output == *"v1.0.2-rc.1 is not a stable upstream release with a predecessor; set SIM_LATEST"* ]]
}
