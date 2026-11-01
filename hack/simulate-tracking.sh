#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
#
# SPDX-License-Identifier: MPL-2.0

# usage: simulate-tracking.sh
# Runs the upstream tracking pipeline (SPEC.md section 9) and the publish build on scratch
# clones of this repository's HEAD and of the fork that cannot push, with a gh stub in
# place of GitHub, then checks the gates' failure paths. Exits non-zero on any unexpected
# result and keeps the scratch directory for inspection; removes it on success.
#   SIM_VERSION  upstream version to track; default the newest upstream release
#   SIM_LATEST   our pretended latest release; default the upstream release before SIM_VERSION
#   SIM_E2E=1    also runs e2e on a fresh harness in cluster SIM_CLUSTER (default posthog-sim)
set -euo pipefail

export UPSTREAM_REPO=PostHog/terraform-provider-posthog
export FORK_REPO=Cliftonz/terraform-provider-posthog
repo=$(git rev-parse --show-toplevel)
work=$(mktemp -d)
echo "simulate-tracking: scratch directory $work"

export GIT_CONFIG_COUNT=3
export GIT_CONFIG_KEY_0=url.file:///dev/null/push-disabled/.pushInsteadOf GIT_CONFIG_VALUE_0=https://github.com/
export GIT_CONFIG_KEY_1=user.name GIT_CONFIG_VALUE_1=simulate-tracking
export GIT_CONFIG_KEY_2=user.email GIT_CONFIG_VALUE_2=simulate-tracking@localhost

step() {
  echo "simulate-tracking: $*"
}

expect_failure() {
  local name=$1 expected=$2 out
  shift 2
  if out=$("$@" 2>&1); then
    echo "$out"
    step "UNEXPECTED PASS: $name"
    exit 1
  fi
  if ! grep -qF -- "$expected" <<< "$out"; then
    echo "$out"
    step "UNEXPECTED FAILURE: $name did not report $expected"
    exit 1
  fi
  step "failed as expected: $name"
}

git ls-remote --tags --refs "https://github.com/$UPSTREAM_REPO.git" | sed 's#.*refs/tags/##' > "$work/upstream-tags"
jq -R '{tag_name: ., draft: false, prerelease: false}' "$work/upstream-tags" | jq -s . > "$work/upstream.json"
mapfile -t stable < <(grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' "$work/upstream-tags" | sort -V | sed 's/^v//')
version=${SIM_VERSION:-${stable[-1]}}
for i in "${!stable[@]}"; do
  if [ "${stable[$i]}" = "$version" ]; then
    latest=${SIM_LATEST:-${stable[$((i - 1))]}}
  fi
done
jq -n --arg tag "v$latest" '[{tag_name: $tag, draft: false, prerelease: false}]' > "$work/ours.json"
step "tracking v$version with v$latest as our latest release"

mkdir "$work/bin"
cat > "$work/bin/gh" <<EOF
#!/usr/bin/env bash
case "\$1 \$2" in
  "api repos/$UPSTREAM_REPO/releases") cat "$work/upstream.json" ;;
  "api repos/Cliftonz/provider-upjet-posthog/releases") cat "$work/ours.json" ;;
  "release list") echo "v$latest" ;;
  *) echo "gh stub: unexpected call: \$*" >&2; exit 1 ;;
esac
EOF
chmod +x "$work/bin/gh"
export PATH=$work/bin:$PATH

git clone -q "$repo" "$work/provider"
git -C "$work/provider" remote set-url --push origin file:///dev/null/push-disabled
git -C "$work/provider" submodule update --init -q
cd "$work/provider"
go build -o "$work/tracking" ./cmd/tracking

step "detect"
"$work/tracking" skips hack/upstream-acks.yaml
gh api "repos/$UPSTREAM_REPO/releases" --paginate > "$work/upstream-releases.json"
gh api repos/Cliftonz/provider-upjet-posthog/releases --paginate > "$work/our-releases.json"
pending=$("$work/tracking" pending hack/upstream-acks.yaml "$work/upstream-releases.json" "$work/our-releases.json")
if [ "$pending" != "$version" ]; then
  step "UNEXPECTED: pending version is '$pending', not $version"
  exit 1
fi

step "fork"
git clone -q "https://github.com/$FORK_REPO.git" "$work/fork"
git -C "$work/fork" remote set-url --push origin file:///dev/null/push-disabled
fork_tag=$(git ls-remote --tags "https://github.com/$FORK_REPO.git" | "$work/tracking" fork-tag "$version")
cp -a "$work/fork" "$work/fork-rebase"
if [ -n "$fork_tag" ]; then
  git -C "$work/fork-rebase" tag -d "v$version-public"
fi
step "fork rebase onto upstream v$version"
hack/fork-rebase.sh "$version" "$work/fork-rebase"
if [ -n "$fork_tag" ]; then
  step "fork checks on the existing tag $fork_tag"
  git -C "$work/fork" -c advice.detachedHead=false checkout -q "$fork_tag"
  hack/fork-checks.sh "$work/fork"
else
  fork_tag=v$version-public
  step "no fork tag published; resolving $fork_tag from the rebased scratch fork"
  rm -rf "$work/fork"
  mv "$work/fork-rebase" "$work/fork"
  export GIT_CONFIG_COUNT=4
  export GIT_CONFIG_KEY_3=url.$work/fork.insteadOf GIT_CONFIG_VALUE_3=https://github.com/$FORK_REPO
  export GOPRIVATE=github.com/$FORK_REPO GOMODCACHE=$work/gomod GOFLAGS=-modcacherw
fi

step "bump, generate, build, unit tests"
hack/bump.sh "$version" "$fork_tag" "$work/fork"
make generate
make -j2 build
make test

step "breaking-change gate"
hack/breaking-changes.sh all
step "new-resource gate"
go run ./cmd/tracking-resources config/schema.json | "$work/tracking" gate hack/upstream-acks.yaml "$version" new-resource

step "patch paths"
git add -A
git diff --cached --binary > "$work/changes.patch"
"$work/tracking" patch-paths "$work/changes.patch"

if [ "${SIM_E2E:-}" = 1 ]; then
  step "e2e"
  E2E_CLUSTER=${SIM_CLUSTER:-posthog-sim} POSTHOG_PORT=${SIM_PORT:-30804} hack/harness-fresh.sh hack/e2e.sh
fi

step "publish build"
BUILD_ARGS=--load make -j2 build.all VERSION="v$version"
for platform in linux_amd64 linux_arm64; do
  test -s "_output/xpkg/$platform/provider-posthog-v$version.xpkg"
done

step "failure path: a patch touching hack/"
echo "# simulate-tracking" >> hack/bump.sh
git diff > "$work/hack.patch"
git checkout -q hack/bump.sh
expect_failure "patch touching hack/" hack/bump.sh "$work/tracking" patch-paths "$work/hack.patch"

step "failure path: an unacknowledged removed field"
jq -c '.provider_schemas[].resource_schemas.posthog_dashboard.block.attributes |= del(.description)' config/schema.json > "$work/schema.json"
cp "$work/schema.json" config/schema.json
expect_failure "breaking-change gate" posthog_dashboard.description hack/breaking-changes.sh all
printf '"%s":\n  breaking:\n    - posthog_dashboard.description\n' "$version" > hack/upstream-acks.yaml
hack/breaking-changes.sh all
git checkout -q config/schema.json hack/upstream-acks.yaml

step "failure path: an unacknowledged new resource"
jq '.provider_schemas[].resource_schemas.posthog_simulated = {version: 0, block: {}}' config/schema.json > "$work/schema-new.json"
new_resource_gate() {
  go run ./cmd/tracking-resources "$work/schema-new.json" | "$work/tracking" gate hack/upstream-acks.yaml "$version" new-resource
}
expect_failure "new-resource gate" posthog_simulated new_resource_gate
printf '"%s":\n  new_resources:\n    - posthog_simulated\n' "$version" > hack/upstream-acks.yaml
new_resource_gate
git checkout -q hack/upstream-acks.yaml

step "failure path: a skip entry"
printf '"%s":\n  skip: true\n' "$version" > hack/upstream-acks.yaml
if [ "$("$work/tracking" skips hack/upstream-acks.yaml)" != "$version" ] ||
  [ "$("$work/tracking" pending hack/upstream-acks.yaml "$work/upstream-releases.json" "$work/our-releases.json")" = "$version" ]; then
  step "UNEXPECTED: the skip entry for $version did not skip it"
  exit 1
fi
git checkout -q hack/upstream-acks.yaml

cd "$repo"
rm -rf "$work"
step "all checks passed"
