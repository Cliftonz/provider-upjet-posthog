#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

# usage: tag.sh VERSION SHA
set -euo pipefail

tag="v$1"
sha=$2

existing=$(git ls-remote origin "refs/tags/${tag}" "refs/tags/${tag}^{}" | tail -n1 | cut -f1)
if [ -z "$existing" ]; then
  gh api "repos/${GITHUB_REPOSITORY}/git/refs" -f ref="refs/tags/${tag}" -f sha="$sha" >/dev/null
elif [ "$existing" != "$sha" ]; then
  echo "${tag} exists at ${existing}, not ${sha}" >&2
  exit 1
fi
