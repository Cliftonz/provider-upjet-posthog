#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

load helpers

setup() {
  setup_stubs
  printf '#!/usr/bin/env bash\necho "$(basename "$0") $*" >> "%s"\n' "$CALLS" > "$BATS_TEST_TMPDIR/recorder"
  stub curl "cp '$BATS_TEST_TMPDIR/recorder' \"\$2\""
  cd "$BATS_TEST_TMPDIR"
  echo 'CROSSPLANE_CLI_VERSION = v2.2.1' > Makefile
  mkdir -p xpkg/linux_amd64 xpkg/linux_arm64
  touch xpkg/linux_amd64/provider-posthog-v1.0.1.xpkg xpkg/linux_arm64/provider-posthog-v1.0.1.xpkg
}

@test "skips the push when the tag exists" {
  stub docker
  run "$ROOT/hack/push-xpkg.sh" registry.example/org/repo:v1.0.1
  [ "$status" -eq 0 ]
  [ "$output" = "registry.example/org/repo:v1.0.1 exists" ]
  ! grep -q '^crossplane \|^up ' "$CALLS"
}

@test "pushes both platforms and appends the extensions when the tag is not found" {
  stub docker 'echo "ERROR: registry.example/org/repo:v1.0.1: not found"; exit 1'
  run "$ROOT/hack/push-xpkg.sh" registry.example/org/repo:v1.0.1
  [ "$status" -eq 0 ]
  grep -qxF "crossplane xpkg push --package-files xpkg/linux_amd64/provider-posthog-v1.0.1.xpkg --package-files xpkg/linux_arm64/provider-posthog-v1.0.1.xpkg registry.example/org/repo:v1.0.1" "$CALLS"
  grep -qxF "up xpkg append --extensions-root=extensions registry.example/org/repo:v1.0.1" "$CALLS"
}

@test "fails without pushing when the lookup fails for another reason" {
  stub docker 'echo "ERROR: unauthorized"; exit 1'
  run "$ROOT/hack/push-xpkg.sh" registry.example/org/repo:v1.0.1
  [ "$status" -eq 1 ]
  [ "$output" = "ERROR: unauthorized" ]
  ! grep -q '^crossplane \|^up ' "$CALLS"
}
