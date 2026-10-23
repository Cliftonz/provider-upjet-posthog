#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

# usage: open-pr.sh VERSION PATCH
# Commits PATCH through the index only, so the checked-out scripts stay those of main.
set -euo pipefail

version=$1
patch=$2
branch="upstream/v${version}"
title="feat: track upstream v${version}"

git switch -C "$branch"
git apply --cached "$patch"
git commit -m "$title"
git push --force "https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" "$branch"
gh pr create --base main --head "$branch" --title "$title" \
  --body "Upstream release: https://github.com/${UPSTREAM_REPO}/releases/tag/v${version}"
gh pr merge "$branch" --auto --squash
