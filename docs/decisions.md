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
