// SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
//
// SPDX-License-Identifier: MPL-2.0

package controller

import (
	ctrl "sigs.k8s.io/controller-runtime"

	"github.com/crossplane/upjet/v2/pkg/controller"

	accesscontrol "github.com/Cliftonz/provider-upjet-posthog/internal/controller/namespaced/access/accesscontrol"
	role "github.com/Cliftonz/provider-upjet-posthog/internal/controller/namespaced/access/role"
	rolemembership "github.com/Cliftonz/provider-upjet-posthog/internal/controller/namespaced/access/rolemembership"
	action "github.com/Cliftonz/provider-upjet-posthog/internal/controller/namespaced/analytics/action"
	alert "github.com/Cliftonz/provider-upjet-posthog/internal/controller/namespaced/analytics/alert"
	cohort "github.com/Cliftonz/provider-upjet-posthog/internal/controller/namespaced/analytics/cohort"
	insight "github.com/Cliftonz/provider-upjet-posthog/internal/controller/namespaced/analytics/insight"
	insightvariable "github.com/Cliftonz/provider-upjet-posthog/internal/controller/namespaced/analytics/insightvariable"
	subscription "github.com/Cliftonz/provider-upjet-posthog/internal/controller/namespaced/analytics/subscription"
	hogfunction "github.com/Cliftonz/provider-upjet-posthog/internal/controller/namespaced/cdp/hogfunction"
	dashboard "github.com/Cliftonz/provider-upjet-posthog/internal/controller/namespaced/dashboard/dashboard"
	layout "github.com/Cliftonz/provider-upjet-posthog/internal/controller/namespaced/dashboard/layout"
	experiment "github.com/Cliftonz/provider-upjet-posthog/internal/controller/namespaced/experiment/experiment"
	earlyaccessfeature "github.com/Cliftonz/provider-upjet-posthog/internal/controller/namespaced/featureflag/earlyaccessfeature"
	featureflag "github.com/Cliftonz/provider-upjet-posthog/internal/controller/namespaced/featureflag/featureflag"
	alertlogs "github.com/Cliftonz/provider-upjet-posthog/internal/controller/namespaced/logs/alert"
	alertdestination "github.com/Cliftonz/provider-upjet-posthog/internal/controller/namespaced/logs/alertdestination"
	member "github.com/Cliftonz/provider-upjet-posthog/internal/controller/namespaced/organization/member"
	proxyrecord "github.com/Cliftonz/provider-upjet-posthog/internal/controller/namespaced/organization/proxyrecord"
	defaultaccess "github.com/Cliftonz/provider-upjet-posthog/internal/controller/namespaced/project/defaultaccess"
	memberproject "github.com/Cliftonz/provider-upjet-posthog/internal/controller/namespaced/project/member"
	project "github.com/Cliftonz/provider-upjet-posthog/internal/controller/namespaced/project/project"
	settings "github.com/Cliftonz/provider-upjet-posthog/internal/controller/namespaced/project/settings"
	providerconfig "github.com/Cliftonz/provider-upjet-posthog/internal/controller/namespaced/providerconfig"
	survey "github.com/Cliftonz/provider-upjet-posthog/internal/controller/namespaced/survey/survey"
	externaldatasource "github.com/Cliftonz/provider-upjet-posthog/internal/controller/namespaced/warehouse/externaldatasource"
	table "github.com/Cliftonz/provider-upjet-posthog/internal/controller/namespaced/warehouse/table"
)

// Setup creates all controllers with the supplied logger and adds them to
// the supplied manager.
func Setup(mgr ctrl.Manager, o controller.Options) error {
	for _, setup := range []func(ctrl.Manager, controller.Options) error{
		accesscontrol.Setup,
		role.Setup,
		rolemembership.Setup,
		action.Setup,
		alert.Setup,
		cohort.Setup,
		insight.Setup,
		insightvariable.Setup,
		subscription.Setup,
		hogfunction.Setup,
		dashboard.Setup,
		layout.Setup,
		experiment.Setup,
		earlyaccessfeature.Setup,
		featureflag.Setup,
		alertlogs.Setup,
		alertdestination.Setup,
		member.Setup,
		proxyrecord.Setup,
		defaultaccess.Setup,
		memberproject.Setup,
		project.Setup,
		settings.Setup,
		providerconfig.Setup,
		survey.Setup,
		externaldatasource.Setup,
		table.Setup,
	} {
		if err := setup(mgr, o); err != nil {
			return err
		}
	}
	return nil
}

// SetupGated creates all controllers with the supplied logger and adds them to
// the supplied manager gated.
func SetupGated(mgr ctrl.Manager, o controller.Options) error {
	for _, setup := range []func(ctrl.Manager, controller.Options) error{
		accesscontrol.SetupGated,
		role.SetupGated,
		rolemembership.SetupGated,
		action.SetupGated,
		alert.SetupGated,
		cohort.SetupGated,
		insight.SetupGated,
		insightvariable.SetupGated,
		subscription.SetupGated,
		hogfunction.SetupGated,
		dashboard.SetupGated,
		layout.SetupGated,
		experiment.SetupGated,
		earlyaccessfeature.SetupGated,
		featureflag.SetupGated,
		alertlogs.SetupGated,
		alertdestination.SetupGated,
		member.SetupGated,
		proxyrecord.SetupGated,
		defaultaccess.SetupGated,
		memberproject.SetupGated,
		project.SetupGated,
		settings.SetupGated,
		providerconfig.SetupGated,
		survey.SetupGated,
		externaldatasource.SetupGated,
		table.SetupGated,
	} {
		if err := setup(mgr, o); err != nil {
			return err
		}
	}
	return nil
}

// SetupWebhookWithManager registers conversion webhooks for all resource kinds in the group.
func SetupWebhookWithManager(mgr ctrl.Manager) error {
	for _, setup := range []func(ctrl.Manager) error{
		accesscontrol.SetupWebhookWithManager,
		role.SetupWebhookWithManager,
		rolemembership.SetupWebhookWithManager,
		action.SetupWebhookWithManager,
		alert.SetupWebhookWithManager,
		cohort.SetupWebhookWithManager,
		insight.SetupWebhookWithManager,
		insightvariable.SetupWebhookWithManager,
		subscription.SetupWebhookWithManager,
		hogfunction.SetupWebhookWithManager,
		dashboard.SetupWebhookWithManager,
		layout.SetupWebhookWithManager,
		experiment.SetupWebhookWithManager,
		earlyaccessfeature.SetupWebhookWithManager,
		featureflag.SetupWebhookWithManager,
		alertlogs.SetupWebhookWithManager,
		alertdestination.SetupWebhookWithManager,
		member.SetupWebhookWithManager,
		proxyrecord.SetupWebhookWithManager,
		defaultaccess.SetupWebhookWithManager,
		memberproject.SetupWebhookWithManager,
		project.SetupWebhookWithManager,
		settings.SetupWebhookWithManager,
		providerconfig.SetupWebhookWithManager,
		survey.SetupWebhookWithManager,
		externaldatasource.SetupWebhookWithManager,
		table.SetupWebhookWithManager,
	} {
		if err := setup(mgr); err != nil {
			return err
		}
	}
	return nil
}
