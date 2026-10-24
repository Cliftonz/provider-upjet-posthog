# Example notes

## e2e

- hack/e2e.sh runs uptest once per example file and skips files that carry upjet.upbound.io/manual-intervention. uptest v2.2.0 renders a broken update step when one run holds more than one root resource, so every file is self-contained: its dependencies carry the file's example-id, which keeps them from being roots.
- uptest.upbound.io/timeout is set on the root of the access examples except role-observe.yaml (300 seconds) and of project.yaml, proxyrecord.yaml and experiment.yaml (600 seconds); every other example uses the uptest default. On posthog-e2e every access apply step finished within 35 seconds.
- Placeholders use uptest's ${data.KEY} syntax; hack/e2e.sh writes the data source.
- Hooks under testhooks/ read POSTHOG_HOST, POSTHOG_API_KEY, POSTHOG_PROJECT_ID and POSTHOG_ORGANIZATION_ID from the environment hack/e2e.sh exports; a deleted object counts as gone on 404 or `deleted: true` (PostHog soft-deletes flags, actions and cohorts).

## access

- Role and RoleMembership omit organizationId; the provider-level organization_id from the harness applies.
- AccessControl omits projectId; the provider-level project_id applies. The project default rule is accesscontrol.yaml; the role-scoped rule and its Role are accesscontrol-role.yaml, since uptest handles one root per run.
- Project default rule uses resource survey/viewer; role-scoped rule uses feature_flag/editor via roleRef to a Role in the same file.
- RoleMembership brings its own Role; it has no in-place updatable field, so uptest skips its update step.
- role-observe.yaml takes ${data.OBSERVED_ROLE_ID}, the UUID of a role hack/e2e.sh creates through the API; it has its own example-id and asserts Ready and Synced only, since upjet sets Test only when the spec matches the observed state.
- role.yaml carries testhooks/role-api.sh, which asserts through the API that the role exists after create and is gone after delete.

## analytics

- Alert: subscribedUsers is required, and an empty list is dropped on update, which then fails CEL validation; the example subscribes user 1, the first user of a fresh PostHog (the harness admin).
- Alert and Subscription: the example Insight is bundled in the same file with a unique name so each kind file is self-contained.
- Subscription: email target uptest@example.com and a fixed future startDate; insight subject only.
- Observe example: forProvider is empty; ${data.OBSERVED_INSIGHT_ID} is the numeric ID of an insight hack/e2e.sh creates through the API; it asserts Ready and Synced only.
- Cohort uses the ClusterProviderConfig `default`, whose Secret lives in crossplane-system, so e2e covers a secretRef in a namespace other than the managed resource's.
- Alert and Subscription set no projectId; project comes from ProviderConfig.

## cdp

- Examples omit projectId and rely on the ProviderConfig-level project.
- HogFunction uses template-microsoft-teams with type destination. template-webhook is served by PostHog's Node.js CDP service, which the harness does not run; the harness bootstrap syncs the Python-backed templates into the database.
- No HogFunction id reference field exists in the generated CRDs, so no HogFunction refs are used.
- Secret-backed fields (jobInputsJson, accessKey, accessSecret, webhookUrl) use a Secret document placed in the same file as the consumer, in namespace default.

## dashboard

- Layout: its Dashboard and Insight are bundled in layout.yaml. The Insight attaches itself through dashboardIdsRefs, as the upstream posthog_dashboard_layout example does; without it the Insight keeps detaching itself from the dashboard the layout put it on.
- Layout has no in-place updatable field uptest can assert (tiles is a list), so uptest skips its update step.
- dashboard.yaml carries testhooks/dashboard-api.sh (API existence after create, absence after delete).

## experiment

- Experiment references its flag with featureFlagKeyRef, which resolves the key from the FeatureFlag status; with a literal key PostHog created the flag first and the FeatureFlag then failed on a duplicate key.
- allowUnknownEvents is true because the harness ingests no events and PostHog otherwise rejects metrics on unseen events.
- Experiment status is a single object (state: running).

## featureflag

- EarlyAccessFeature links to a boolean, non-multivariate flag at rolloutPercentage 0 via featureFlagIdRef; both live in featureflag/v1alpha1/earlyaccessfeature.yaml.
- Lock flag variants are off 100 / notice 0 / locked 0; the staff/admin group forces notice, the catch-all group serves the default distribution.
- Payload values are JSON strings (escaped) inside the filters JSON, keyed by variant, as PostHog stores them.
- featureflag-lock.yaml runs testhooks/lock-toggle.sh after Ready: it patches active to false and asserts through the API that the flag is inactive and keeps the three variants, the payloads and the per-condition variant override.
- featureflag.yaml carries testhooks/featureflag-api.sh (API existence after create, soft-deleted after delete).

## logs

- AlertDestination brings its own logs Alert through alertIdRef and uses type teams. PostHog builds webhook destinations from template-webhook, which needs the Node.js CDP service the harness does not run; teams uses a Python-backed template and validates the URL only when it fires. The destination has no in-place update, so uptest skips its update step.

## organization

- Org Members set retainOnDestroy true and organizationId "@current"; reason: the harness bootstraps a single org and deletion must not remove the test user.
- uptest fills ${data.POSTHOG_TEST_USER_UUID} from the data source hack/e2e.sh writes.
- organization/member.yaml updates level to admin; the org Member inside project/member.yaml carries the project example-id and is not updated, so the two never disagree on the shared membership.
- ProxyRecord has no in-place updatable field, so uptest skips its update step.

## project

- DefaultAccess, Settings and project Member each bring their own Project through projectIdRef; reason: one uptest run per file.
- project/member.yaml grants access via organizationMemberRef to an in-file organization Member (role omitted); reason: Role needs the enterprise RBAC objects and the org member covers the required accessLevel path.
- Project timezone Europe/London; reason: exercise the optional field with a non-default value.
- Settings and DefaultAccess are singletons per Project; reason: e2e asserts only removal from Crossplane.
- Project deletion is asynchronous in PostHog and calls personhog, so the harness runs personhog-replica and personhog-router.

## survey

- Survey example omits linkedFlagIdRef to stay minimal.

## warehouse

- ExternalDataSource is excluded from e2e via the upjet.upbound.io/manual-intervention annotation, which uptest v2.2.0 honors; it needs a reachable external Postgres.
- Table is excluded from e2e via upjet.upbound.io/manual-intervention: PostHog rejects URL patterns that are not https or that resolve to private addresses, so no object store inside kind qualifies. The example uses placeholder S3 values.
