#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

load helpers

setup() {
  setup_stubs
  stub kind 'echo other-cluster'
  cd "$BATS_TEST_TMPDIR"
  mkdir -p hack test/harness
  cp "$ROOT/hack/harness-fresh.sh" hack/
  for script in up down; do
    printf '#!/usr/bin/env bash\necho "%s $E2E_CLUSTER" >> "%s"\n' "$script" "$CALLS" > "test/harness/$script.sh"
    chmod +x "test/harness/$script.sh"
  done
  stub check
  export E2E_CLUSTER=posthog-fresh
}

@test "boots the harness, runs the command and tears down" {
  run hack/harness-fresh.sh check one two
  [ "$status" -eq 0 ]
  [ "$(grep -v '^kind ' "$CALLS")" = "$(printf 'up posthog-fresh\ncheck one two\ndown posthog-fresh')" ]
}

@test "tears down and keeps the command's failure" {
  stub check 'exit 3'
  run hack/harness-fresh.sh check
  [ "$status" -eq 3 ]
  grep -qxF "down posthog-fresh" "$CALLS"
}

@test "refuses a cluster that exists without touching it" {
  stub kind 'echo posthog-fresh'
  run hack/harness-fresh.sh check
  [ "$status" -eq 1 ]
  [ "$output" = "kind cluster posthog-fresh exists; harness-fresh.sh only boots a new one" ]
  [ "$(grep -v '^kind ' "$CALLS")" = "" ]
}
