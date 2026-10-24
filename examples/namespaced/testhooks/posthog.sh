#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

set -euo pipefail

api() {
  curl -fsS -H "Authorization: Bearer $POSTHOG_API_KEY" "$POSTHOG_HOST/api/$1"
}

api_state() {
  local response status
  response="$(curl -sS -w '\n%{http_code}' -H "Authorization: Bearer $POSTHOG_API_KEY" "$POSTHOG_HOST/api/$1")"
  status="${response##*$'\n'}"
  if [ "$status" = 404 ] || jq -e ".deleted == true" <<< "${response%$'\n'*}" >/dev/null; then
    echo gone
  else
    echo "$status"
  fi
}

assert_lifecycle() {
  local mr="$1" collection="$2" idfile="${TMPDIR:-/tmp}/posthog-e2e-${1##*/}"
  if [ "$(${KUBECTL} -n default get "$mr" --ignore-not-found -o jsonpath="{.metadata.name}/{.metadata.deletionTimestamp}")" = "${mr##*/}/" ]; then
    ${KUBECTL} -n default get "$mr" -o jsonpath="{.status.atProvider.id}" > "$idfile"
    test -s "$idfile"
    test "$(api_state "$collection/$(cat "$idfile")/")" = 200
  else
    ${KUBECTL} -n default wait --for=delete "$mr" --timeout=5m
    test "$(api_state "$collection/$(cat "$idfile")/")" = gone
  fi
}
