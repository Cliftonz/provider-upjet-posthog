> Draft, not filed. Target: PostHog/terraform-provider-posthog. Duplicate check on 2026-11-09: open and closed issues and PRs searched for "already being deleted", "being deleted", and "project delete"; no match. Still present in v1.0.28 (`pkg/resource/project.go`, `ProjectOps.Delete` returns the DELETE error unchanged) and on main at dad670b. The repo has no CONTRIBUTING.md, issue templates, or SECURITY.md.

**Title:** posthog_project: a repeat delete during PostHog's purge fails with 400 "This project is already being deleted."

We maintain a Crossplane provider for PostHog, [Cliftonz/provider-upjet-posthog](https://github.com/Cliftonz/provider-upjet-posthog), generated with upjet from this provider and running it in-process, so its resources behave exactly as they do here.

PostHog purges a project asynchronously after the first DELETE and answers any further DELETE with 400 "This project is already being deleted." until the purge finishes. `ProjectOps.Delete` returns that error as is, so a delete that is repeated while the purge runs fails even though the project is going away.

Reproduction:

1. Delete a project through the provider.
2. Delete it again before PostHog finishes purging it.

Expected: the second delete succeeds, since the project is already being removed.

Actual: the second delete fails with 400 "This project is already being deleted." In our provider the controller retries deletes until the resource is gone, so it logged this error on every retry until the purge finished. With the terraform CLI it shows up when a destroy is re-run after an earlier run whose DELETE PostHog had already accepted.

Proposed fix: treat that specific 400 as success. Any other 400 still fails.

```diff
--- a/pkg/resource/project.go
+++ b/pkg/resource/project.go
@@ import (
 	"context"
+	"net/http"
+	"strings"
@@ func (o ProjectOps) Delete(ctx context.Context, client httpclient.PosthogClient, model ProjectTFModel) (httpclient.HTTPStatusCode, error) {
-	return client.DeleteProject(ctx, model.GetEffectiveOrganizationID(), model.GetID())
+	status, err := client.DeleteProject(ctx, model.GetEffectiveOrganizationID(), model.GetID())
+	if status == http.StatusBadRequest && strings.Contains(err.Error(), "already being deleted") {
+		return status, nil
+	}
+	return status, err
 }
```

Matching on the message is the only signal the API gives today; if PostHog returns a stable error code for this case, matching on that would be better. We have unit tests for this 400 and for a different 400 that must still fail, and can include them in a PR.
