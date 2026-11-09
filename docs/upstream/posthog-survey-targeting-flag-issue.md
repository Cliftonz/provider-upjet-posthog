> Draft, not filed. Target: PostHog/terraform-provider-posthog. Duplicate check on 2026-11-09: open and closed issues and PRs searched for "survey", "targeting flag", "targeting_flag", and "remove_targeting_flag"; no match (closest: #145 and PR #196, both about question ids in `questions_json`). Still present in v1.0.28 (`pkg/resource/survey.go`, `mapSurveyRelationshipFields`) and on main at dad670b. The repo has no CONTRIBUTING.md, issue templates, or SECURITY.md.

**Title:** posthog_survey: the first update after creating with targeting_flag_filters_json removes the targeting flag

We maintain a Crossplane provider for PostHog, [Cliftonz/provider-upjet-posthog](https://github.com/Cliftonz/provider-upjet-posthog), generated with upjet from this provider and running it in-process, so its resources behave exactly as they do here.

A survey created with `targeting_flag_filters_json` gets a targeting flag that PostHog creates from those filters, and the create response returns it as `targeting_flag`. `mapSurveyRelationshipFields` maps that id into `targeting_flag_id`, an attribute meant for an existing flag the user chose. On the next update the plan has `targeting_flag_id` null (it is not in the config) and the state has the id, so `applySurveyTargetingClear` sends `remove_targeting_flag: true` and drops the filters from the request. PostHog deletes the flag and the survey loses its targeting.

Reproduction, as we observed it in-process and with curl against PostHog:

1. Create a survey with `targeting_flag_filters_json = jsonencode({ groups = [{ properties = [], rollout_percentage = 50 }] })` and no `targeting_flag_id`.
2. Change any other attribute, for example `description`, and apply.

Expected: the PATCH carries `targeting_flag_filters` and PostHog updates the existing targeting flag in place.

Actual: the PATCH carries `remove_targeting_flag: true` and no filters; PostHog deletes the targeting flag. In our provider the deleted id was then sent back as `targeting_flag_id`, and every later update failed with 400 "Targeting Feature Flag with this ID does not exist".

Through the terraform CLI we expect the create itself to fail with "Provider produced inconsistent result after apply" on `targeting_flag_id`, since it is Optional without Computed and the config leaves it null. We have not run that path; our bridge does not run Terraform core's post-apply check.

Proposed fix: map the response flag into `targeting_flag_id` only when the filters are not configured. With this, a PATCH with the filters alone updates the existing flag in place, which we verified against PostHog.

```diff
--- a/pkg/resource/survey.go
+++ b/pkg/resource/survey.go
@@ func mapSurveyRelationshipFields(resp httpclient.Survey, model *SurveyTFModel) {
 	model.LinkedFlagID = int64ValueFromMapOrNull(resp.LinkedFlag)
-	model.TargetingFlagID = int64ValueFromMapOrNull(resp.TargetingFlag)
+	if !core.IsKnown(model.TargetingFlagFiltersJSON) {
+		model.TargetingFlagID = int64ValueFromMapOrNull(resp.TargetingFlag)
+	}
```

Known limits of this change: removing `targeting_flag_filters_json` from the config afterwards leaves the targeting flag in PostHog, setting both `targeting_flag_id` and `targeting_flag_filters_json` stays unsupported, and import still maps `targeting_flag_id` from the response. We have a unit test that creates with filters, updates, and asserts the PATCH has `targeting_flag_filters` and neither `remove_targeting_flag` nor `targeting_flag_id`. Happy to open a PR with both.
