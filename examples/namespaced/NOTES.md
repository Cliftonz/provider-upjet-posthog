# Example notes

## access

- Role and RoleMembership omit organizationId; the provider-level organization_id from the harness applies.
- AccessControl omits projectId; the provider-level project_id applies. Both rules live in accesscontrol.yaml as two documents sharing one example-id.
- Project default rule uses resource survey/viewer; role-scoped rule uses feature_flag/editor via roleRef to example-role.
- role-observe.yaml needs ${OBSERVED_ROLE_ID} substituted by the e2e runner with the UUID of an existing role; it has its own example-id and no uptest timeout.
- Timeout annotation is 300 seconds on all managed examples; no measured value yet.

## analytics

- Alert: subscribedUsers is required by the provider schema; examples use an empty list because no PostHog user IDs exist in the e2e project.
- Alert and Subscription: the example Insight is bundled in the same file with a unique name so each kind file is self-contained.
- Subscription: email target uptest@example.com and a fixed future startDate; insight subject only.
- Observe example: forProvider is empty; ${OBSERVED_INSIGHT_ID} is the numeric insight ID substituted by the e2e runner.
- No uptest timeout annotations were added; none of these resources are slow to reconcile.
- Alert and Subscription set no projectId; project comes from ProviderConfig.

## cdp

- Examples omit projectId and rely on the ProviderConfig-level project.
- HogFunction uses the built-in template-webhook template with type destination; no transformation types.
- No HogFunction id reference field exists in the generated CRDs, so no HogFunction refs are used.
- Secret-backed fields (jobInputsJson, accessKey, accessSecret, webhookUrl) use a Secret document placed in the same file as the consumer, in namespace default.

## dashboard

- Layout: its Dashboard and Insight are bundled in layout.yaml, and the Insight sets no dashboardIds so the layout alone attaches it.

## experiment

- Experiment has no flag Ref field (featureFlagKey is a string), so the experiment example sets the key literally and ships its own multivariate flag in experiment/v1alpha1/experiment.yaml.
- Experiment status is a single object (state: running); uptest timeout set to 600s.

## featureflag

- EarlyAccessFeature links to a boolean, non-multivariate flag at rolloutPercentage 0 via featureFlagIdRef; both live in featureflag/v1alpha1/earlyaccessfeature.yaml.
- Lock flag variants are off 100 / notice 0 / locked 0; the staff/admin group forces notice, the catch-all group serves the default distribution.
- Payload values are JSON strings (escaped) inside the filters JSON, keyed by variant, as PostHog stores them.
- The lock flag's toggle annotations are plain metadata; the runner that patches active is not defined here.

## logs

- Alert and AlertDestination: the destination uses alertIdRef to checkout-errors, webhook type only (Slack and Teams need OAuth or external endpoints).

## organization

- Org Members set retainOnDestroy true and organizationId "@current"; reason: the harness bootstraps a single org and deletion must not remove the test user.
- ${POSTHOG_TEST_USER_UUID} is recorded in the e2e.posthog.m.clifton.quest/substitute annotation; reason: requested note that the e2e runner substitutes it, no new tooling.

## project

- Dependent MRs reference the shared Project via projectIdSelector on label testing.upbound.io/example-name: example-project (declared in project.yaml); reason: avoids duplicate Projects, requires project.yaml applied in the same uptest run.
- project/member.yaml grants access via organizationMemberRef to an in-file organization Member (role omitted); reason: Role needs the enterprise RBAC objects and the org member covers the required accessLevel path.
- The org Member dependency in project/member.yaml reuses example-id organization/v1alpha1/member; reason: same kind, avoids a new group of examples.
- Project timezone Europe/London; reason: exercise the optional field with a non-default value.
- Settings and DefaultAccess are singletons per Project; reason: e2e asserts only removal from Crossplane.

## survey

- Survey example omits linkedFlagIdRef to stay minimal.

## warehouse

- ExternalDataSource is generated but excluded from e2e via the upjet.upbound.io/manual-intervention annotation; it needs a reachable external Postgres. The annotation is not verified against the uptest version in use.
- Table: self-host support for posthog_warehouse_table is unknown. urlPattern and credentials are placeholders (WAREHOUSE_URL, WAREHOUSE_ACCESS_KEY, WAREHOUSE_ACCESS_SECRET) the e2e runner must substitute. The provider docs require an HTTPS URL; the harness http://objectstorage:19000 endpoint may be rejected.
