#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

# usage: fork-checks.sh FORK_DIR
set -euo pipefail

cd "$1"
go test ./...
go -C test/externalimport mod tidy
go -C test/externalimport test ./...
