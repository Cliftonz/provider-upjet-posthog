package config

import (
	ujconfig "github.com/crossplane/upjet/v2/pkg/config"
)

const zeroUUID = "00000000-0000-0000-0000-000000000000"

var (
	numericID   = ujconfig.FrameworkResourceWithComputedIdentifier("id", "0")
	uuidID      = ujconfig.FrameworkResourceWithComputedIdentifier("id", zeroUUID)
	compositeID = ujconfig.FrameworkResourceWithComputedIdentifier("id", "0/placeholder")
)

type resource struct {
	group        string
	kind         string
	externalName ujconfig.ExternalName
}

var resources = map[string]resource{
	"posthog_project":                {"project", "Project", numericID},
	"posthog_project_settings":       {"project", "Settings", numericID},
	"posthog_project_default_access": {"project", "DefaultAccess", numericID},
	"posthog_project_member":         {"project", "Member", compositeID},
	"posthog_organization_member":    {"organization", "Member", uuidID},
	"posthog_proxy_record":           {"organization", "ProxyRecord", uuidID},
	"posthog_role":                   {"access", "Role", uuidID},
	"posthog_role_membership":        {"access", "RoleMembership", uuidID},
	"posthog_access_control":         {"access", "AccessControl", compositeID},
	"posthog_action":                 {"analytics", "Action", numericID},
	"posthog_cohort":                 {"analytics", "Cohort", numericID},
	"posthog_insight":                {"analytics", "Insight", numericID},
	"posthog_insight_variable":       {"analytics", "InsightVariable", uuidID},
	"posthog_alert":                  {"analytics", "Alert", uuidID},
	"posthog_subscription":           {"analytics", "Subscription", numericID},
	"posthog_dashboard":              {"dashboard", "Dashboard", numericID},
	"posthog_dashboard_layout":       {"dashboard", "Layout", numericID},
	"posthog_feature_flag":           {"featureflag", "FeatureFlag", numericID},
	"posthog_early_access_feature":   {"featureflag", "EarlyAccessFeature", uuidID},
	"posthog_experiment":             {"experiment", "Experiment", numericID},
	"posthog_survey":                 {"survey", "Survey", uuidID},
	"posthog_hog_function":           {"cdp", "HogFunction", uuidID},
	"posthog_external_data_source":   {"warehouse", "ExternalDataSource", uuidID},
	"posthog_warehouse_table":        {"warehouse", "Table", uuidID},
	"posthog_logs_alert":             {"logs", "Alert", uuidID},
	"posthog_logs_alert_destination": {"logs", "AlertDestination", uuidID},
}

func configureResource(r *ujconfig.Resource) {
	c := resources[r.Name]
	r.ShortGroup = c.group
	r.Kind = c.kind
	r.ExternalName = c.externalName
	r.TerraformConversions = append(r.TerraformConversions, idToString{})
}

func resourceNames() []string {
	names := make([]string, 0, len(resources))
	for name := range resources {
		names = append(names, name+"$")
	}
	return names
}
