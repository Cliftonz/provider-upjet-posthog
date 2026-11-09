> Draft, not filed. Target: PostHog/terraform-provider-posthog. Duplicate check on 2026-11-09: open and closed issues and PRs searched for "external data source", "schemas", and "replacement order"; no match (only the resource's original PRs #76 and #85). Still present in v1.0.28 (`pkg/resource/external_data_source.go`, `schemas` uses `listplanmodifier.RequiresReplace()` and Read copies the API order) and on main at dad670b. The repo has no CONTRIBUTING.md, issue templates, or SECURITY.md.

**Title:** posthog_external_data_source: schemas not in alphabetical order plan a replacement on every run

We maintain a Crossplane provider for PostHog, [Cliftonz/provider-upjet-posthog](https://github.com/Cliftonz/provider-upjet-posthog), generated with upjet from this provider and running it in-process, so its resources behave exactly as they do here.

`schemas` is an ordered list with `RequiresReplace`, and `MapResponseToModel` writes the schema names in the order PostHog returns them, which is sorted by name. Any config that lists them in another order never matches state, so every plan replaces the source.

Reproduction:

1. Create a source with `schemas = ["users", "orders"]`.
2. Plan again with no change.

Expected: no changes.

Actual: state holds `["orders", "users"]`, and the plan shows `schemas` forcing replacement. Applying recreates the source and the diff comes back. Listing the schemas alphabetically is the only workaround.

Proposed fix: keep the configured order when the set of names is unchanged, and require replacement only when a schema is added or removed. State that already differs from the config in order only converges with one in-place update.

```diff
--- a/pkg/resource/external_data_source.go
+++ b/pkg/resource/external_data_source.go
@@ import (
 	"context"
 	"encoding/json"
+	"slices"
 	"strings"
@@ func (o ExternalDataSourceOps) Schema() schema.Schema {
 				PlanModifiers: []planmodifier.List{
-					listplanmodifier.RequiresReplace(),
+					listplanmodifier.RequiresReplaceIf(
+						func(ctx context.Context, req planmodifier.ListRequest, resp *listplanmodifier.RequiresReplaceIfFuncResponse) {
+							planned, d := util.StringListToSlice(ctx, req.PlanValue)
+							resp.Diagnostics.Append(d...)
+							prior, d := util.StringListToSlice(ctx, req.StateValue)
+							resp.Diagnostics.Append(d...)
+							resp.RequiresReplace = !sameSchemaNames(planned, prior)
+						},
+						"Adding or removing a schema will force destroy and recreate; reordering will not.",
+						"Adding or removing a schema will force destroy and recreate; reordering will not.",
+					),
 				},
@@ func (o ExternalDataSourceOps) MapResponseToModel(ctx context.Context, resp http
 		for _, s := range resp.Schemas {
 			names = append(names, s.Name)
 		}
-		listVal, d := types.ListValueFrom(ctx, types.StringType, names)
+		configured, d := util.StringListToSlice(ctx, model.Schemas)
 		diags.Append(d...)
-		if !diags.HasError() {
-			model.Schemas = listVal
+		if !sameSchemaNames(configured, names) {
+			listVal, d := types.ListValueFrom(ctx, types.StringType, names)
+			diags.Append(d...)
+			if !diags.HasError() {
+				model.Schemas = listVal
+			}
 		}
@@
+func sameSchemaNames(a, b []string) bool {
+	return slices.Equal(slices.Sorted(slices.Values(a)), slices.Sorted(slices.Values(b)))
+}
```

The attribute description would also say that order does not matter. A set would be the other option, but changing the attribute type changes the schema for existing users, so we kept the list. We have unit tests for reordered and changed names and can include them in a PR.
