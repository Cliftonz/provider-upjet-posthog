#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

set -euo pipefail

state="${TMPDIR:-/tmp}/posthog-e2e-$(basename "$0" .sh).json"
CREATED='. != null'
DELETED='. == null'

api() {
  curl -fsS -H "Authorization: Bearer $POSTHOG_API_KEY" "$POSTHOG_HOST/api/$1"
}

at() {
  jq -r ".$1" "$state"
}

get() {
  local response status
  response="$(curl -sS -w '\n%{http_code}' -H "Authorization: Bearer $POSTHOG_API_KEY" "$POSTHOG_HOST/api/$1")"
  status="${response##*$'\n'}"
  if [ "$status" = 404 ]; then
    echo null
  else
    test "$status" = 200
    jq --argjson at "$(cat "$state")" "first(${2:-.} | select(.deleted != true)) // null" <<< "${response%$'\n'*}"
  fi
}

assert_api() {
  case "${1:-created}" in
    created)
      ${KUBECTL} -n default get "$MR" -o json | jq .status.atProvider > "$state"
      jq -e '.id | length > 0' "$state"
      object | jq -e "$CREATED"
      ;;
    updated)
      object | jq -e "$UPDATED"
      ;;
    deleted)
      ${KUBECTL} -n default wait --for=delete "$MR" --timeout=5m
      until object | jq -e "$DELETED"; do
        sleep 5
      done
      ;;
  esac
}
