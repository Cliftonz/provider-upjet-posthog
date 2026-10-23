# Decisions

| Date | Decision | Reason |
|---|---|---|
| 2026-10-22 | Port the official PostHog hobby stack into kind; running compose beside kind is the fallback | The human asked for PostHog in kind |
| 2026-10-22 | Bootstrap an enterprise License row for local dev/test | `ee/LICENSE` permits dev/test use |
| 2026-10-22 | Adopt the e2e expectation matrix from research; `warehouse_table` is unknown pending the harness | Self-hosted behavior per resource was researched; `warehouse_table` cannot be confirmed until the harness runs |
| 2026-10-22 | e2e credentials (API key, organization ID, project ID, second user UUID) come from the harness bootstrap locally and in CI; e2e GitHub secrets and the absent-secret skip/fail rules are removed | CI runs the same harness on the runner, so e2e always runs where required |
| 2026-10-22 | Remove the e2e sweeper workflow and cloud test organization references | Each e2e run uses a fresh kind cluster, so nothing leaks between runs |
| 2026-10-22 | `ProxyRecord` stays in e2e, asserting `Ready`, `Synced`, and deletion but not status `valid` | The provider does not wait for provisioning status, and `valid` is unreachable on self-host |
| 2026-10-22 | The `Subscription` example targets an insight via email, not an AI prompt | AI prompts are cloud-only |
| 2026-10-22 | Module path `github.com/Cliftonz/provider-upjet-posthog`, provider name `posthog`, root group `posthog.m.clifton.quest`, package `provider-posthog`, image and xpkg orgs `xpkg.upbound.io/cliftonz` | Section 1 identity and Upbound organization |
| 2026-10-22 | `go.mod` requires `github.com/posthog/terraform-provider v1.0.25` replaced by `Cliftonz/terraform-provider-posthog@e708a31` (resolved to a pseudo-version) until fork tags exist; upjet `v2.5.1`; MVS lifts terraform-plugin-sdk/v2 to v2.40.0, which builds with plugin-go v0.31.0 | Section 2 pins; the fork tag `v1.0.25-public` is a later human step |
| 2026-10-22 | `config/provider.go` uses `WithIncludeList(nil)`, a framework include list of all 26 resources, and `WithTerraformPluginFrameworkProvider(provider.New(version)())` | No-fork mode; a resource on both paths panics at startup |
| 2026-10-22 | `cmd/generator` runs a single namespaced `PipelineRunner`; the storage-version and lifecycle post-generation hooks are dropped | `pipeline.Run` cannot generate namespaced-only, and there is a single version `v1alpha1` |
| 2026-10-22 | `cmd/provider` is namespaced only, sets an `OperationTrackerStore`, and has no Terraform flags | No Terraform CLI path at runtime |
| 2026-10-22 | Cluster-scoped trees and the legacy cluster `ProviderConfig` are removed; `ProviderConfig`, `ClusterProviderConfig`, `ProviderConfigUsage` stay in `posthog.m.clifton.quest/v1beta1` | Section 1 scope |
| 2026-10-22 | Every resource has an explicit short group and kind per section 4.2; managed resource version is upjet's default `v1alpha1` | Section 4 |
| 2026-10-22 | External names use `FrameworkResourceWithComputedIdentifier("id", placeholder)`: `0` for Int64 IDs and the project-ID singletons, the zero UUID for UUID IDs, `0/placeholder` for `project_member` and `access_control` | Upstream reads singletons, `dashboard_layout`, `project_member`, `access_control` and `organization_member` from parameters, so the placeholder only has to be non-empty and never match a real ID; the external name becomes the upstream state ID after the first read |
| 2026-10-22 | References: `project_id` on every project-scoped kind, plus role, organization member, insight, dashboard, feature flag and logs alert ID fields; `organization_id`, `user_uuid`, experiment `holdout_id`, access control `resource_id`, subscription `integration_id` get none | No kind owns those IDs, or the target kind varies |
| 2026-10-22 | Cross-group import cycles in resolvers are broken with upjet's resolver transform and `internal/apis.GetManagedResource` | `analytics` and `dashboard`, `project` and `access` reference each other |
| 2026-10-22 | Credentials Secret JSON keys `api_key`, `host`, `organization_id`, `project_id` are passed through only when non-empty; an empty `api_key` counts as missing | An empty string must never reach upstream, which treats a set value as authoritative |
| 2026-10-22 | `config/schema.json` is built from the fork binary via terraform 1.5.7 `dev_overrides`, without `init`; `pull-docs` fetches the fork at `TERRAFORM_PROVIDER_REF` | Section 2 schema source; `dev_overrides` worked so no filesystem mirror is needed |
| 2026-10-22 | Runtime image contains only the provider binary | Section 2 |
| 2026-10-22 | golangci-lint raised to 2.14.0 and `goconst` excluded under `config/` | 2.13.0 cannot read Go 1.27 export data; the resource tables repeat group and resource names by design |
| 2026-10-22 | `secretRef.namespace` stays required on `ProviderConfig`; the provider overrides it with the managed resource's namespace | The CRD requires the field; dropping it would diverge from the shared credentials schema |
| 2026-10-22 | An empty `api_key` is treated as missing | An empty string must never reach upstream |
| 2026-10-22 | Non-string credential values are rejected as malformed JSON | Every credential key is a string in the upstream provider configuration |
