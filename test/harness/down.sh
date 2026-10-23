#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
kind delete cluster --name posthog-e2e
rm -f .out/posthog.env
