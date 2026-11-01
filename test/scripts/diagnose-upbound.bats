#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

load helpers

setup() {
  setup_stubs
  cd "$BATS_TEST_TMPDIR"
  mkdir hack
  cp "$ROOT/hack/diagnose-upbound.sh" hack/
  echo up_version=v0.55.2 > hack/push-xpkg.sh
  stub docker 'exit 1'
  printf '#!/usr/bin/env bash\necho "up $*" >> "%s"\n[ -z "$UP_REFUSES" ] || exit 1\n[ "$1" != organization ] || echo "cliftonz owner"\n' "$CALLS" > up
  stub curl "cp '$BATS_TEST_TMPDIR/up' \"\$2\""
  export XPKG_ACCESS_ID=0c1d2e3f-aaaa-4bbb-8ccc-0123456789ab
  export XPKG_TOKEN=eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJyb2JvdCJ9.c2lnbmF0dXJlc2VjcmV0
}

@test "describes both values without printing them" {
  run hack/diagnose-upbound.sh
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "XPKG_ACCESS_ID: 36 characters, UUID shape, whitespace no" ]
  [ "${lines[1]}" = "XPKG_TOKEN: 62 characters, JWT shape, whitespace no" ]
  [[ $output != *"$XPKG_ACCESS_ID"* ]]
  [[ $output != *"$XPKG_TOKEN"* ]]
}

@test "reports whitespace and unrecognised shapes" {
  XPKG_ACCESS_ID="robot-id " XPKG_TOKEN=token run hack/diagnose-upbound.sh
  [ "${lines[0]}" = "XPKG_ACCESS_ID: 9 characters, unrecognised shape, whitespace yes" ]
  [ "${lines[1]}" = "XPKG_TOKEN: 5 characters, unrecognised shape, whitespace no" ]
}

@test "reports a refused docker login and an accepted up login with its organizations" {
  run hack/diagnose-upbound.sh
  [ "${lines[2]}" = "docker login xpkg.upbound.io: refused" ]
  [ "${lines[3]}" = "up login --token XPKG_TOKEN: accepted" ]
  [ "${lines[4]}" = "cliftonz owner" ]
  grep -qF "docker login xpkg.upbound.io -u $XPKG_ACCESS_ID --password-stdin" "$CALLS"
  grep -qF "curl -fsSLo" "$CALLS"
  grep -qF "https://cli.upbound.io/stable/v0.55.2/bin/linux_amd64/up" "$CALLS"
}

@test "reports an accepted docker login and a refused up login" {
  stub docker
  UP_REFUSES=1 run hack/diagnose-upbound.sh
  [ "${lines[2]}" = "docker login xpkg.upbound.io: accepted" ]
  [ "${lines[3]}" = "up login --token XPKG_TOKEN: refused" ]
}
