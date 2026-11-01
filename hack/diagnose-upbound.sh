#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

# usage: diagnose-upbound.sh
# Describes XPKG_ACCESS_ID and XPKG_TOKEN (length, shape, whitespace) and whether
# docker login and up login accept them, without printing either value.
set -euo pipefail

shape() {
  if [[ $1 =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
    echo UUID
  elif [[ $1 =~ ^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$ ]]; then
    echo JWT
  else
    echo unrecognised
  fi
}

for name in XPKG_ACCESS_ID XPKG_TOKEN; do
  value=${!name}
  whitespace=no
  if [[ $value =~ [[:space:]] ]]; then
    whitespace=yes
  fi
  echo "$name: ${#value} characters, $(shape "$value") shape, whitespace $whitespace"
done

work=$(mktemp -d)
if DOCKER_CONFIG=$work/docker docker login xpkg.upbound.io -u "$XPKG_ACCESS_ID" --password-stdin <<< "$XPKG_TOKEN" > /dev/null 2>&1; then
  echo "docker login xpkg.upbound.io: accepted"
else
  echo "docker login xpkg.upbound.io: refused"
fi

up_version=$(sed -n 's/^up_version=//p' hack/push-xpkg.sh)
curl -fsSLo "$work/up" "https://cli.upbound.io/stable/${up_version}/bin/linux_amd64/up"
chmod +x "$work/up"
if HOME=$work "$work/up" login --token "$XPKG_TOKEN" > /dev/null 2>&1; then
  echo "up login --token XPKG_TOKEN: accepted"
  HOME=$work "$work/up" organization list
else
  echo "up login --token XPKG_TOKEN: refused"
fi
rm -rf "$work"
