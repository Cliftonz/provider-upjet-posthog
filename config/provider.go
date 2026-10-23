package config

import (
	_ "embed"

	ujconfig "github.com/crossplane/upjet/v2/pkg/config"
	"github.com/posthog/terraform-provider/provider"

	"github.com/Cliftonz/provider-upjet-posthog/internal/version"
)

const (
	resourcePrefix = "posthog"
	modulePath     = "github.com/Cliftonz/provider-upjet-posthog"
)

//go:embed schema.json
var providerSchema string

//go:embed provider-metadata.yaml
var providerMetadata string

func GetProvider() *ujconfig.Provider {
	pc := ujconfig.NewProvider([]byte(providerSchema), resourcePrefix, modulePath, []byte(providerMetadata),
		ujconfig.WithRootGroup("posthog.m.clifton.quest"),
		ujconfig.WithIncludeList(nil),
		ujconfig.WithTerraformPluginFrameworkIncludeList(resourceNames()),
		ujconfig.WithTerraformPluginFrameworkProvider(provider.New(version.Version)()),
		ujconfig.WithFeaturesPackage("internal/features"),
		ujconfig.WithDefaultResourceOptions(configureResource),
		ujconfig.WithExampleManifestConfiguration(ujconfig.ExampleManifestConfiguration{
			ManagedResourceNamespace: "crossplane-system",
		}))

	configureReferences(pc)
	pc.ConfigureResources()
	return pc
}
