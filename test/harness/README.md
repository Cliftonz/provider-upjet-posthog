# PostHog test harness

A kind cluster named `posthog-e2e` running a self-hosted PostHog, bootstrapped headlessly so end to end tests get real credentials. Crossplane and the provider are installed into the same cluster separately.

PostHog no longer ships a maintained Kubernetes deployment, so `manifests/` ports the subset of the hobby compose stack that the REST API needs. Every image is pinned by digest in `images.env`; the PostHog configuration files ClickHouse, Redpanda and Temporal need are fetched from the PostHog commit that matches the pinned app image.

## Run

Requires Docker, kind, kubectl, curl and envsubst; run under bash (WSL Ubuntu or Git Bash).

```sh
test/harness/up.sh     # create cluster if missing, deploy, wait, bootstrap
test/harness/down.sh   # delete the cluster
```

First boot runs all PostHog migrations and takes about 50 minutes on 4 CPUs; `up.sh` waits up to 90 minutes.

`up.sh` writes `test/harness/.out/posthog.env`:

| Variable | Meaning |
|---|---|
| `POSTHOG_HOST` | `http://localhost:30800`, reachable from the host (kind maps the NodePort) |
| `POSTHOG_CLUSTER_HOST` | `http://web.posthog.svc.cluster.local:8000`, reachable from pods in the cluster, such as the provider |
| `POSTHOG_API_KEY` | personal API key with scope `*` for the admin user |
| `POSTHOG_ORGANIZATION_ID` | organization of the admin user |
| `POSTHOG_PROJECT_ID` | default project of that organization |
| `POSTHOG_TEST_USER_UUID` | a second member of the organization |

An enterprise license row is inserted so EE features are available; PostHog's `ee/LICENSE` permits this for development and testing.
