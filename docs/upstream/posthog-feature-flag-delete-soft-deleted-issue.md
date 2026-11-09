> Draft, not filed. Target: PostHog/terraform-provider-posthog. Duplicate check on 2026-11-09: open and closed issues and PRs searched for "soft-deleted", "deleted flag", "invalid_key", and "feature flag delete"; no match (closest: PR #31, drift detection for flags removed outside Terraform, which covers restore, not delete). Still present in v1.0.28 (`pkg/httpclient/feature_flags.go`, `DeleteFeatureFlag` sends the key it reads back) and on main at dad670b. The repo has no CONTRIBUTING.md, issue templates, or SECURITY.md.

**Title:** posthog_feature_flag: deleting a flag that is already soft-deleted fails with 400 invalid_key

We maintain a Crossplane provider for PostHog, [Cliftonz/provider-upjet-posthog](https://github.com/Cliftonz/provider-upjet-posthog), generated with upjet from this provider and running it in-process, so its resources behave exactly as they do here.

PostHog soft-deletes a flag by setting `deleted: true` and renaming its key to `<key>:deleted:<id>`. `DeleteFeatureFlag` reads the flag and PATCHes `deleted: true` with the key it read. When the flag is already soft-deleted, that key is the renamed one, and PostHog rejects it with 400 `invalid_key`, so the delete can never succeed.

Reproduction:

1. Create a flag through the provider.
2. Soft-delete it outside the provider, or let an earlier delete succeed without the provider recording it.
3. Delete it through the provider.

Expected: the delete succeeds, since the flag is already deleted.

Actual: 400 `invalid_key` on the PATCH. In our provider the controller retries the delete, so the resource stayed on its finalizer indefinitely. With the terraform CLI we expect `terraform destroy` of a flag soft-deleted in the UI to fail the same way, since Read keeps a soft-deleted flag in state; we have not run that path.

Proposed fix: return success when the flag read for deletion is already soft-deleted.

```diff
--- a/pkg/httpclient/feature_flags.go
+++ b/pkg/httpclient/feature_flags.go
@@ func (c *PosthogClient) DeleteFeatureFlag(ctx context.Context, projectID, id string) (HTTPStatusCode, error) {
-	existing, _, err := c.GetFeatureFlag(ctx, projectID, id)
+	existing, status, err := c.GetFeatureFlag(ctx, projectID, id)
 	if err != nil {
 		return 0, fmt.Errorf("failed to get feature flag for deletion: %w", err)
 	}
+	if existing.Deleted != nil && *existing.Deleted {
+		return status, nil
+	}
```

We have a unit test that serves a soft-deleted flag, answers any PATCH with 400 `invalid_key`, and asserts the delete succeeds, and can include it in a PR.
