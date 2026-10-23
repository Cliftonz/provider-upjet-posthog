#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

# usage: open-pr.sh VERSION
set -euo pipefail

version=$1
branch="upstream/v${version}"
title="feat: track upstream v${version}"

git switch -C "$branch"
git add -A
git commit -m "$title"
git push --force origin "$branch"
gh pr create --base main --head "$branch" --title "$title" \
  --body "Upstream release: https://github.com/${UPSTREAM_REPO}/releases/tag/v${version}"
gh pr merge "$branch" --auto --squash
