# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

ROOT=$(cd "$BATS_TEST_DIRNAME/../.." && pwd)

setup_stubs() {
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  PATH=$BATS_TEST_TMPDIR/bin:$PATH
  CALLS=$BATS_TEST_TMPDIR/calls
  : > "$CALLS"
}

# stub NAME [BODY]: puts NAME on PATH; it records "NAME ARGS" in $CALLS, then runs BODY.
stub() {
  printf '#!/usr/bin/env bash\necho "%s $*" >> "%s"\n%s\n' "$1" "$CALLS" "${2:-}" > "$BATS_TEST_TMPDIR/bin/$1"
  chmod +x "$BATS_TEST_TMPDIR/bin/$1"
}
