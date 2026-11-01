#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

load helpers

setup() {
  setup_stubs
  export UPSTREAM_REPO=Upstream/provider
  export GIT_CONFIG_COUNT=3 \
    GIT_CONFIG_KEY_0=user.name GIT_CONFIG_VALUE_0=test \
    GIT_CONFIG_KEY_1=user.email GIT_CONFIG_VALUE_1=test@example.com \
    GIT_CONFIG_KEY_2="url.$BATS_TEST_TMPDIR/upstream.insteadOf" GIT_CONFIG_VALUE_2=https://github.com/Upstream/provider.git
  mkdir -p "$BATS_TEST_TMPDIR/hack"
  cp "$ROOT/hack/fork-rebase.sh" "$BATS_TEST_TMPDIR/hack/"
  printf '#!/usr/bin/env bash\necho "fork-checks $*" >> "%s"\n' "$CALLS" > "$BATS_TEST_TMPDIR/hack/fork-checks.sh"
  chmod +x "$BATS_TEST_TMPDIR/hack/fork-checks.sh"

  upstream=$BATS_TEST_TMPDIR/upstream
  git init -q -b main "$upstream"
  mkdir -p "$upstream/internal/provider"
  echo a > "$upstream/internal/provider/a.go"
  git -C "$upstream" add -A
  git -C "$upstream" commit -q -m one
  git -C "$upstream" tag v1.0.1

  fork=$BATS_TEST_TMPDIR/fork
  git clone -q "$upstream" "$fork"
  git -C "$fork" switch -q -c public-provider
  git -C "$fork" mv internal/provider provider
  git -C "$fork" commit -q -m "move provider out of internal"

  echo new > "$upstream/internal/provider/new.go"
  echo b > "$upstream/internal/provider/a.go"
  git -C "$upstream" add -A
  git -C "$upstream" commit -q -m two
  git -C "$upstream" tag v1.0.2
}

@test "rebases onto the upstream tag, moves new provider files out of internal, checks and tags" {
  run "$BATS_TEST_TMPDIR/hack/fork-rebase.sh" 1.0.2 "$fork"
  [ "$status" -eq 0 ]
  [ "$(cat "$fork/provider/a.go")" = b ]
  [ "$(cat "$fork/provider/new.go")" = new ]
  [ -z "$(git -C "$fork" ls-files internal/provider)" ]
  [ -z "$(git -C "$fork" status --porcelain)" ]
  [ "$(git -C "$fork" rev-parse v1.0.2-public)" = "$(git -C "$fork" rev-parse public-provider)" ]
  grep -qxF "fork-checks $fork" "$CALLS"
}
