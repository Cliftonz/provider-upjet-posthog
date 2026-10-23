package config

import (
	ujconfig "github.com/crossplane/upjet/v2/pkg/config"
)

var references = map[string]map[string]string{
	"posthog_access_control": {
		"role":                "posthog_role",
		"organization_member": "posthog_organization_member",
	},
	"posthog_alert": {
		"insight": "posthog_insight",
	},
	"posthog_dashboard_layout": {
		"dashboard_id":     "posthog_dashboard",
		"tiles.insight_id": "posthog_insight",
	},
	"posthog_early_access_feature": {
		"feature_flag_id": "posthog_feature_flag",
	},
	"posthog_insight": {
		"dashboard_ids": "posthog_dashboard",
	},
	"posthog_logs_alert_destination": {
		"alert_id": "posthog_logs_alert",
	},
	"posthog_project_member": {
		"role":                "posthog_role",
		"organization_member": "posthog_organization_member",
	},
	"posthog_role_membership": {
		"role_id": "posthog_role",
	},
	"posthog_subscription": {
		"dashboard_id": "posthog_dashboard",
		"insight_id":   "posthog_insight",
	},
	"posthog_survey": {
		"linked_flag_id":    "posthog_feature_flag",
		"targeting_flag_id": "posthog_feature_flag",
		"linked_insight_id": "posthog_insight",
	},
}

func configureReferences(pc *ujconfig.Provider) {
	for name, r := range pc.Resources {
		if _, ok := r.TerraformResource.Schema["project_id"]; ok {
			r.References["project_id"] = ujconfig.Reference{TerraformName: "posthog_project"}
		}
		for field, target := range references[name] {
			r.References[field] = ujconfig.Reference{TerraformName: target}
		}
	}
	pc.Resources["posthog_experiment"].References["feature_flag_key"] = ujconfig.Reference{
		TerraformName: "posthog_feature_flag",
		Extractor:     `github.com/crossplane/upjet/v2/pkg/resource.ExtractParamPath("key", true)`,
	}
}
