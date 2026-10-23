#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

# usage: fork-rebase.sh VERSION FORK_DIR
set -euo pipefail

version=$1
fork=$2
hack=$(dirname "$(realpath "$0")")

git -C "$fork" fetch "https://github.com/${UPSTREAM_REPO}.git" "refs/tags/v${version}:refs/upstream/v${version}"
git -C "$fork" switch public-provider
git -C "$fork" rebase "refs/upstream/v${version}"

if [ -d "$fork/internal/provider" ]; then
  (cd "$fork" && git mv internal/provider/* provider/)
  git -C "$fork" commit -m "refactor(provider): move new upstream provider files out of internal"
fi

"$hack/fork-checks.sh" "$fork"
git -C "$fork" tag "v${version}-public"
