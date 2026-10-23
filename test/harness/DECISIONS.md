# Decisions

- Pinned PostHog to commit `11eeef67` (the `latest` image when the harness was built) and fetch its config files at that commit; config and app image cannot drift apart.
- ClickHouse `idl` and `user_scripts` are copied from the pinned PostHog image by an init container; the UDF binaries are too large for ConfigMaps.
- Skipped `autoresearch-row-policies.sql` from the ClickHouse init dir; it targets a user that exists only in `users-dev.xml`.
- One Deployment plus Service per compose service, named like the compose services, so PostHog's config files resolve hosts unchanged.
- The ClickHouse pod sets `hostname: clickhouse`; otherwise `clickhouse` resolves to the Service IP, ClickHouse does not recognise itself in the `ON CLUSTER` host list, and every distributed DDL in the migrations hangs.
- Worker and temporal-django-worker crash loop until migrations finish (async migration check reads a missing table); compose behaves the same, and Kubernetes restarts them, so no extra wait was added.
- `enableServiceLinks: false` on every pod; Kubernetes service env vars like `TEMPORAL_PORT=tcp://...` otherwise override PostHog and Temporal settings.
- Storage is `emptyDir`; the harness is disposable and data only needs to survive container restarts, not pod deletion.
- Omitted plugins, ingestion, capture, feature-flags, personhog, livestream, browserless, cymbal, valkey, the session recording seaweedfs, Elasticsearch and Caddy; the REST API used by the provider does not need them. `PERSONHOG_ENABLED` is left unset.
- Redpanda runs with `--smp=1 --memory=1G` and binds RPC on `0.0.0.0` with no seed list, since a pod cannot bind its Service hostname.
- Topic creation is a Job that waits for the broker, then creates every topic from `topics.txt` in one `rpk` call.
- `POSTHOG_HOST` is `http://host.docker.internal:30800` (kind port mapping to a NodePort); Docker Desktop resolves that name both on Windows and inside containers, so one value works from host and pods.
- Fixed, non-secret `SECRET_KEY` and `ENCRYPTION_SALT_KEYS` in the manifest; the instance is local and throwaway.
- `bootstrap.py` is idempotent: it reuses the admin, organization, project, member and license, and replaces the API key on every run.
- `POSTHOG_PROJECT_ID` is the default team id.
- kind v0.32.0 was installed into WSL Ubuntu at `~/.local/bin/kind`.
