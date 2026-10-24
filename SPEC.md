# provider-posthog Specification

## 1. Purpose and scope

`provider-posthog` is a Crossplane v2 provider, generated with upjet, that manages PostHog configuration as Kubernetes managed resources. It embeds the official PostHog Terraform provider (`github.com/PostHog/terraform-provider-posthog`, terraform-plugin-framework, MPL-2.0) and is published to the Upbound Marketplace.

| Item | Value |
|---|---|
| Source repository | `github.com/Cliftonz/provider-upjet-posthog` |
| Package | `xpkg.upbound.io/cliftonz/provider-posthog` |
| Upbound organization | `cliftonz` |
| Upstream provider | registry `posthog/posthog`, Go module `github.com/posthog/terraform-provider` |
| Embedded via | fork `github.com/Cliftonz/terraform-provider-posthog` (section 2) |
| Crossplane | v2 only |
| Resource scope | Managed resources are namespaced only |
| License | MPL-2.0 |

First release: v1.0.25, covering all 26 upstream Terraform resources; older upstream versions are not backfilled. Data sources follow section 4.3.

Out of scope: cluster-scoped managed resources, Crossplane v1, Compositions or configuration packages, anything not in the upstream provider.

## 2. Architecture

The provider runs in upjet v2 no-fork mode: the PostHog framework provider runs in-process and serves every resource. No resource goes through upjet's Terraform CLI path, because a resource registered on both paths panics at startup. The image contains only the provider binary; there is no Terraform CLI, provider download, or filesystem mirror at runtime.

Fork: upstream keeps its provider constructor in `internal/provider`, which Go forbids importing from another module. The fork's `public-provider` branch moves it to `provider/` and updates imports; behavior and schema are unchanged. The tracking pipeline rebases and force-pushes this branch without human review, gated by the fork's unit tests and its external-import check (nested module `test/externalimport`, which imports the constructor from outside the module); both also run in the fork's CI.

Fork tags: each rebased commit is tagged `v<version>-public` (for example `v1.0.25-public`); a later fork fix for the same version gets `v<version>-public.N` with an incrementing suffix (for example `v1.0.25-public.2`). Tags never move, so every pin stays reachable after force-pushes. "Highest tag" means semver order, so `-public.10` ranks above `-public.2`, which ranks above `-public`.

Pins: `go.mod` requires `github.com/posthog/terraform-provider v<version>` and `replace`s it with the fork's highest tag for that version; the Makefile names the same upstream version for docs generation. The tracking pipeline bumps both in the same PR.

Schema: `config/schema.json` is generated from the fork build, the code that ships, so CRDs cannot drift from the binary and generation never waits on the Terraform registry.

Exit path: the fork stays until PostHog ships an importable constructor or upjet changes so one is no longer needed (section 14); then drop the `replace` and the fork. CRDs, groups, kinds, and external names must not change.

## 3. Repository layout

Based on `crossplane/upjet-provider-template` with all cluster-scoped trees and `backport.yml` removed; there are no release branches.

```
.github/workflows/   ci.yml, e2e.yaml, tag.yaml, publish-provider-package.yml, upstream-tracking.yml
apis/namespaced/     generated API types; v1beta1 ProviderConfig, ClusterProviderConfig, ProviderConfigUsage
config/              provider config, external names, per-group config, schema.json, provider metadata
examples/namespaced/ hand-maintained manifests, one per resource, used by e2e
examples-generated/  generated examples, checked in
internal/clients/    credential mapping
docs/upstream/       drafts for upstream projects
hack/upstream-acks.yaml  per upstream version: acknowledged changes and skip entries
```

## 4. API groups and kinds

### 4.1 Group scheme

One API group per PostHog product domain, named `<group>.posthog.m.clifton.quest` following the template's convention of `.m.` after the provider segment for namespaced groups. Config kinds live in `posthog.m.clifton.quest/v1beta1`. Managed resource kinds start at `v1alpha1`; API versions change only by deliberate decision.

### 4.2 Resource mapping

| Terraform resource | Group prefix | Kind |
|---|---|---|
| `posthog_project` | `project` | `Project` |
| `posthog_project_settings` | `project` | `Settings` |
| `posthog_project_default_access` | `project` | `DefaultAccess` |
| `posthog_project_member` | `project` | `Member` |
| `posthog_organization_member` | `organization` | `Member` |
| `posthog_proxy_record` | `organization` | `ProxyRecord` |
| `posthog_role` | `access` | `Role` |
| `posthog_role_membership` | `access` | `RoleMembership` |
| `posthog_access_control` | `access` | `AccessControl` |
| `posthog_action` | `analytics` | `Action` |
| `posthog_cohort` | `analytics` | `Cohort` |
| `posthog_insight` | `analytics` | `Insight` |
| `posthog_insight_variable` | `analytics` | `InsightVariable` |
| `posthog_alert` | `analytics` | `Alert` |
| `posthog_subscription` | `analytics` | `Subscription` |
| `posthog_dashboard` | `dashboard` | `Dashboard` |
| `posthog_dashboard_layout` | `dashboard` | `Layout` |
| `posthog_feature_flag` | `featureflag` | `FeatureFlag` |
| `posthog_early_access_feature` | `featureflag` | `EarlyAccessFeature` |
| `posthog_experiment` | `experiment` | `Experiment` |
| `posthog_survey` | `survey` | `Survey` |
| `posthog_hog_function` | `cdp` | `HogFunction` |
| `posthog_external_data_source` | `warehouse` | `ExternalDataSource` |
| `posthog_warehouse_table` | `warehouse` | `Table` |
| `posthog_logs_alert` | `logs` | `Alert` |
| `posthog_logs_alert_destination` | `logs` | `AlertDestination` |

Every field holding the ID of another resource in this table (for example `project_id`, `role_id`, `insight_id`, logs `alert_id`) gets generated `*Ref` and `*Selector` fields.

### 4.3 Data sources

upjet generates managed resources only. `posthog_insight` and `posthog_role` are covered by the `Insight` and `Role` kinds with `managementPolicies: ["Observe"]`; `posthog_user` and future data sources are not provided.

## 5. ProviderConfig and credentials

Config kinds: namespaced `ProviderConfig` (usable in its own namespace), cluster-scoped `ClusterProviderConfig` (usable from any namespace), and `ProviderConfigUsage`. Managed resources select one with `spec.providerConfigRef: {kind, name}`.

The credentials `source` enum is narrowed to `Secret`. The referenced key holds JSON whose fields are the upstream provider configuration attributes, which are exactly `api_key`, `host`, `organization_id` and `project_id`; the provider maps these four explicitly, values must be strings, and other keys are ignored. Absent keys take upstream defaults (`host` defaults to `https://us.posthog.com`). Malformed JSON or a missing `api_key` fails the connection with a condition naming the problem; this is specified behavior with its own tests. Upstream also falls back to `POSTHOG_*` environment variables for absent keys, so the provider pod must not set them; otherwise one pod-level value would leak into every ProviderConfig.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: posthog-creds
  namespace: team-a
stringData:
  credentials: |
    {"api_key": "phx_...", "host": "https://us.posthog.com",
     "organization_id": "<uuid | slug | @current>", "project_id": "12345"}
---
apiVersion: posthog.m.clifton.quest/v1beta1
kind: ProviderConfig
metadata:
  name: default
  namespace: team-a
spec:
  credentials:
    source: Secret
    secretRef:
      name: posthog-creds
      namespace: team-a
      key: credentials
```

`secretRef.namespace` is required by the CRD. A `ProviderConfig` overrides it with the managed resource's namespace, which is its own; a `ClusterProviderConfig` reads the Secret from `secretRef.namespace`.

## 6. External name configuration

Every resource has an explicit external name entry. The external name is the upstream Terraform state `id`, unchanged. Upstream's composite strings (`project_id/x` and similar) are `terraform import` inputs only; no-fork mode reads by state `id` plus parameters and never imports. Formats verified against upstream v1.0.25:

| Resources | State `id` | External name |
|---|---|---|
| action, alert, cohort, dashboard, early_access_feature, experiment, external_data_source, feature_flag, hog_function, insight, insight_variable, logs_alert, project, proxy_record, role, subscription, survey, warehouse_table | API ID | assigned by PostHog |
| role_membership, organization_member | membership ID (organization_member resolves by `user_uuid`) | assigned by PostHog |
| logs_alert_destination | sorted, comma-joined hog function IDs | derived by upstream; changes whenever the hog function set changes, which is accepted |
| dashboard_layout (singleton per dashboard) | dashboard ID | templated from `dashboard_id` |
| project_settings, project_default_access (singleton per project) | project ID | templated from `project_id` |
| project_member | `project_id/(role\|member)/<id>` | templated from parameters |
| access_control | `project_id/<resource>[/<resource_id>]/(default\|role/<id>\|member/<id>)` | templated from parameters |

The e2e import step (section 11) is the acceptance check.

## 7. Build

The template build submodule provides generation, the multi-arch (`linux/amd64`, `linux/arm64`) image and `.xpkg` build, the reviewable checks, and uptest. Our Go toolchain follows upstream's `go` directive (section 9).

## 8. CI/CD pipelines

| Workflow | Trigger | Outcome |
|---|---|---|
| `ci.yml` | push to `main`, pull_request | lint; generation leaves no diff; unit tests; image and xpkg build; example validation (server-side dry-run of `examples/namespaced` in kind); CRD breaking-change check against the latest release, including `v1alpha1` kinds, passing changes acknowledged in `hack/upstream-acks.yaml`, skipped when no release exists |
| `e2e.yaml` | pull_request on `upstream/v*` and `upjet/*` branches; other PRs only with label `run-e2e`; `workflow_dispatch`; push to `main` runs only the snapshot and Go cache jobs | section 11; on `main`, saves the PostHog snapshot and the provider build cache that PRs restore |
| `tag.yaml` | merge (closed and merged) of an `upstream/v*` PR; `workflow_dispatch` (version, SHA) | creates `v<version>` on the merge commit; skips if the tag exists at that SHA; fails with a `release` issue if it exists at another SHA |
| `publish-provider-package.yml` | after `tag.yaml`; `workflow_dispatch` (version) | rebuilds from the tag rather than promoting the e2e image; pushes `xpkg.upbound.io/cliftonz/provider-posthog:<version>` unless it exists; creates the GitHub release, marked latest, unless it exists; a lookup error other than not found fails; then dispatches `upstream-tracking.yml` |
| `upstream-tracking.yml` | daily schedule, `workflow_dispatch`, successful publish | section 9 |

Tracking, release (tag and publish), and e2e each run in their own `concurrency` group and authenticate with the GitHub App token (section 12), so their pushes, PRs, issues, and dispatches work and trigger downstream workflows. Reusable workflows receive secrets explicitly. These tag and publish workflows replace the template's, which push to ghcr and create no GitHub release.

Branch protection on `main` requires: generation diff clean, build, unit tests, example validation, CRD breaking-change check, and, on `upstream/v*` and `upjet/*` PRs, e2e.

## 9. Upstream tracking automation

Order: non-draft, non-prerelease upstream releases newer than our latest release are processed one at a time, oldest first. Each completes fully (merged, tagged, published) before the next starts, so each builds on a `main` containing the previous release. The oldest unreleased version blocks every newer one, whichever workflow failed, until it publishes or a human records a `skip` entry for it in `hack/upstream-acks.yaml`. Detection excludes skipped versions, a skipped version is never published, skipping closes its open `upstream/v<version>` PR, and the pipeline proceeds to the next. The `skip` issue label is triage only.

Each run acts on the oldest pending version according to its `upstream/v<version>` PR:

| PR state | Action |
|---|---|
| none | run the steps below |
| open, checks pending | nothing |
| open, checks failed | nothing; the failing workflow already opened an issue, and a human fixes or skips |
| merged, unreleased | dispatch `tag.yaml` with the merge commit, the single release path |
| closed, unmerged | open a `release` issue |

1. Fork: if a fork tag exists for the version, run the fork checks (the fork's full `go test ./...`, acceptance tests skipped without `TF_ACC`, and the external-import check) against the highest one; a failure opens a `fork-fix` issue. Otherwise rebase `public-provider` onto the upstream tag (moving new files under `internal/provider` to `provider/`), pass both fork checks, then push the branch and tag `v<version>-public`.
2. Bump: set the pins (section 2) and raise our Go toolchain to upstream's `go` directive; a dependency conflict with upjet fails as `build`.
3. Regenerate and build.
4. Gates: the breaking-change gate (against the previous release: in `config/schema.json` a removed resource, removed field, changed field type, added required field, or optional field made required; in `package/crds` a removed CRD, version, or property, a changed type, array item type, or map value schema, a newly required property, or a new `x-kubernetes-validations` rule) and the new-resource gate (an upstream resource absent from 4.2). Each passes for changes listed for that upstream version in `hack/upstream-acks.yaml`; a human adds entries alongside any needed config and reruns.
5. Open the PR with auto-merge enabled; failing to enable auto-merge fails the step. CI and e2e gate the merge.

No job that holds the GitHub App token runs upstream code: steps 1 to 4 run in jobs with a read-only `GITHUB_TOKEN` and hand a git bundle or patch to jobs that only push, open the PR, and enable auto-merge. No process that holds the token links upstream code: those jobs build `cmd/tracking`, whose dependency graph excludes the upstream module (checked in CI), while `cmd/tracking-resources`, which reads our provider config, runs only in the unprivileged generate job. Checkouts never persist credentials; tokens reach only the steps that push or call `gh`. The PR job accepts a patch touching only `apis/`, `internal/controller/`, `package/crds/`, `examples-generated/`, `config/schema.json`, `config/provider-metadata.yaml`, `go.mod`, `go.sum`, and the Makefile's version pin lines; any other path fails as `generation`, naming the paths.

Reruns reuse an existing `upstream/v<version>` branch, PR, and fork tags, and tag and publish skip work already done, so a partial release is completed rather than duplicated.

Any failure, in any workflow, opens an issue, runs nothing after the failed step, and leaves the version unreleased. The issue is titled `Upstream v<version>: <failed step>` and labeled `upstream-tracking` plus one of `fork-rebase`, `fork-fix`, `generation`, `build`, `test`, `breaking-change`, `new-resource`, `publish`, `release`. The body links the upstream release and the workflow run and, for schema failures, lists the affected resources and fields; it contains no log excerpts. An existing open issue with the same title gets a comment instead.

## 10. Versioning and release

Our version equals the upstream version it embeds; the same string is the git tag (`v<version>`, on `main`) and the OCI tag. There are no out-of-band releases: our own fixes, including upjet bumps and any code fix needed after a version is tagged, ship with the next upstream release. Releases come only from section 9, except the first, which uses `workflow_dispatch` of `tag.yaml` and `publish-provider-package.yml` after the bootstrap in section 12.

## 11. Testing strategy

| Layer | Tool | Scope |
|---|---|---|
| Generation | diff check | Generated code, CRDs, examples |
| Unit | `go test` | `internal/clients` credential mapping, including the malformed JSON and missing `api_key` conditions; external name functions |
| Fork | fork CI and section 9 | Upstream unit tests and the external-import check |
| Manifest validation | kind, server-side dry-run | Every example in `examples/namespaced` |
| End to end | uptest on kind | Every kind except `ExternalDataSource` and `Table`, against self-hosted PostHog |

Local and CI e2e run the same harness, `test/harness/`, which deploys self-hosted PostHog into a fresh kind cluster per run: the official hobby stack ported to kind, images pinned by digest, bootstrapped headlessly with a personal API key, an organization, a project, a second user, and an enterprise License row for dev/test as `ee/LICENSE` permits. The bootstrap supplies all e2e credentials; e2e uses no GitHub secrets. Cloud-only behavior: `ProxyRecord` never reaches status `valid`; `Subscription` AI prompts are unavailable; `ExternalDataSource` needs a reachable source and `Table` an https object store on a public address (PostHog rejects anything else), hence their exclusion. Webhook hog functions and webhook logs alert destinations need PostHog's Node.js CDP service, which the harness does not run, so those examples use the Teams template. The harness also runs personhog, which project deletion requires.

e2e runs once per version, on its `upstream/v*` PR, and on `upjet/*` PRs. It installs the minimum Crossplane version declared in `package/crossplane.yaml` and the package built in the same run into kind, creates a namespaced `ProviderConfig` from the bootstrap credentials, applies the examples in reference order, asserts `Ready` and `Synced`, runs uptest's update step (one uptest run per example file; every root that supports an in-place update carries `uptest.upbound.io/update-parameter`), runs uptest's import step, then deletes everything. Hooks assert through the PostHog API that a feature flag, a dashboard and a role exist after create and are gone after delete. `organization.Member` targets the bootstrap's second user. `ProxyRecord` asserts `Ready`, `Synced`, and deletion, not status `valid`; the provider does not wait for provisioning. The `Subscription` example targets an insight via email. For the singletons (`project.Settings`, `project.DefaultAccess`, `dashboard.Layout`), cleanup asserts only that the managed resource is gone.

Additional cases:

- `FeatureFlag` mirroring a lock-flag use: multivariate variants, a payload, and a per-condition variant override in `filters`; it toggles `active` and asserts the change reaches PostHog.
- A `ClusterProviderConfig` whose `secretRef` points to a namespace other than the managed resource's.

## 12. One-time setup

Manual steps by the human:

1. Create a GitHub App with contents, pull-requests, actions, and issues write permissions; install it on this repository and the fork; store its credentials as repository secrets. Enable "Allow auto-merge" on this repository. Run `hack/labels.sh` to create the issue labels.
2. Create fork tag `v1.0.25-public` on `public-provider` after it passes the fork unit tests and external-import check.
3. Create Upbound organization `cliftonz` and repository `provider-posthog`; create an Upbound robot token and store it as `XPKG_ACCESS_ID` and `XPKG_TOKEN`.
4. Publish the first release (section 10).
5. Request review in `#upbound` on Crossplane Slack with the repo URL, account, and repository name (unverified against Upbound docs).
6. After approval, `up repository update provider-posthog --publish` (up v0.39.0 or later).

`package/crossplane.yaml`:

```yaml
apiVersion: meta.pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-posthog
  annotations:
    meta.crossplane.io/maintainer: Cliftonz (https://github.com/Cliftonz)
    meta.crossplane.io/source: github.com/Cliftonz/provider-upjet-posthog
    meta.crossplane.io/license: MPL-2.0
    meta.crossplane.io/description: Crossplane provider for managing PostHog projects, feature flags, insights, dashboards, and related configuration.
    meta.crossplane.io/readme: <rendered from README.md at build time>
    friendly-name.meta.crossplane.io: Provider PostHog
spec:
  crossplane:
    version: ">=v2.0.0"
```

The PostHog name is used descriptively only; no PostHog logo until PostHog grants permission.

## 13. Maintenance runbook

- upjet bumps are manual PRs from branches prefixed `upjet/` and must pass all required gates, including e2e. Bump `crossplane-runtime` with upjet; raise `spec.crossplane.version` only when a new minimum is required. On each upjet bump, diff `.github/workflows` and `build/` against `crossplane/upjet-provider-template` and port fixes that apply.
- Deprecated upstream resources and fields stay generated while upstream ships them; removal is caught by the breaking-change gate.
- Failure issues: fix on a PR, then rerun via `workflow_dispatch`; close only after that version is published or skipped.

| Label | Action |
|---|---|
| `fork-rebase` | Resolve the conflict on `public-provider` by hand, push, rerun |
| `fork-fix` | Fix the fork, tag the fix with the next suffix (`v<version>-public.N`), rerun |
| `generation`, `build`, `publish` | Fix and rerun |
| `release` | Inspect the tag or PR; a version tagged but unpublishable is skipped, and its fix ships with the next upstream release |
| `test` | Reproduce with uptest; decide whether the cause is ours, upstream, or the harness |
| `breaking-change` | Decide the handling; if accepted, add acknowledgement entries and rerun |
| `new-resource` | Assign group and kind in 4.2, add external name config, example, and acknowledgement entry; rerun |
| any | To abandon the version, add a `skip` entry to `hack/upstream-acks.yaml` |

## 14. Upstream engagement

Automation and agents never file issues, open PRs, comment, or react on repositories we do not own; the human reviews each draft under `docs/upstream/` and files it from their own account after checking the target's `CONTRIBUTING.md`, templates, signing requirements, and duplicates. Drafts follow each target repository's AI disclosure policy.

- Public constructor: `docs/upstream/posthog-public-provider-issue.md` asks PostHog to expose the constructor, offering Option A (a public wrapper package) or Option B (move `internal/provider` to `provider/`), and links the fork branch as a working Option B; drafted, not yet filed (link added once filed). No PR until a maintainer accepts.
- upjet: [comment on crossplane/upjet#788](https://github.com/crossplane/upjet/issues/788#issuecomment-6329830093) with fix PR [crossplane/upjet#792](https://github.com/crossplane/upjet/pull/792).
- Possible security issues in upstream go through PostHog's private channel per `SECURITY.md`.
- Upstream bugs found by e2e are drafted with a reproducer.

## 15. Provisional decisions (revisit)

- Fork mechanics, tag scheme, pins, schema source: section 2.
- Groups, kinds, `v1alpha1` start, generated references, data sources: section 4.
- Secret-only credentials, `ClusterProviderConfig`, environment variable rule: section 5.
- Target platforms `linux/amd64` and `linux/arm64`: section 7.
- Concurrency groups, required checks, no backport workflow or release branches: sections 3 and 8.
- Tracking order, blocking, `skip`, run states, daily detection, gates, acknowledgements, failure issues: section 9.
- Version equals upstream, no out-of-band releases, first release v1.0.25 without backfill: section 10.
- e2e scope, cases, self-hosted harness, Crossplane version, `ExternalDataSource` exclusion, singleton cleanup: section 11 and `docs/decisions.md`.
- GitHub App, bootstrap, manual Marketplace onboarding, license, descriptive name, no logo, maintainer contact: section 12.
- Manual upjet bumps, issue handling: section 13.
- Upstream engagement rules: section 14.
