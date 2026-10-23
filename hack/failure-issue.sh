#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

# usage: failure-issue.sh VERSION STEP LABEL [AFFECTED_FILE]
set -euo pipefail

version=$1
step=$2
label=$3
affected=${4:-}

export TITLE="Upstream v${version}: ${step}"
body="Upstream release: https://github.com/${UPSTREAM_REPO}/releases/tag/v${version}
Workflow run: ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
if [ -s "$affected" ]; then
  body+=$'\n\nAffected resources and fields:\n'"$(sed "s/^/- /" "$affected")"
fi

number=$(gh issue list --state open --search "\"${TITLE}\" in:title" --json number,title \
  --jq '.[] | select(.title == env.TITLE) | .number' | head -n1)
if [ -n "$number" ]; then
  gh issue comment "$number" --body "$body"
else
  gh issue create --title "$TITLE" --label upstream-tracking --label "$label" --body "$body"
fi
