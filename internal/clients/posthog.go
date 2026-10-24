package clients

import (
	"context"
	"encoding/json"

	"github.com/crossplane/crossplane-runtime/v2/pkg/resource"
	"github.com/crossplane/upjet/v2/pkg/terraform"
	"github.com/pkg/errors"
	"github.com/posthog/terraform-provider/provider"
	"k8s.io/apimachinery/pkg/types"
	"sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/Cliftonz/provider-upjet-posthog/apis/namespaced/v1beta1"
	"github.com/Cliftonz/provider-upjet-posthog/internal/version"
)

const (
	errGetProviderConfig  = "cannot get referenced ProviderConfig"
	errTrackUsage         = "cannot track ProviderConfig usage"
	errExtractCredentials = "cannot extract credentials"
)

func TerraformSetupBuilder() terraform.SetupFn {
	return func(ctx context.Context, c client.Client, mg resource.Managed) (terraform.Setup, error) {
		pcSpec, err := resolveProviderConfig(ctx, c, mg.(resource.ModernManaged))
		if err != nil {
			return terraform.Setup{}, errors.Wrap(err, "cannot resolve provider config")
		}
		data, err := resource.CommonCredentialExtractor(ctx, pcSpec.Credentials.Source, c, pcSpec.Credentials.CommonCredentialSelectors)
		if err != nil {
			return terraform.Setup{}, errors.Wrap(err, errExtractCredentials)
		}
		cfg, err := providerConfiguration(data)
		if err != nil {
			return terraform.Setup{}, err
		}
		return terraform.Setup{
			Configuration:     cfg,
			FrameworkProvider: provider.New(version.Version)(),
		}, nil
	}
}

func providerConfiguration(data []byte) (terraform.ProviderConfiguration, error) {
	var creds struct {
		APIKey         string `json:"api_key"`
		Host           string `json:"host"`
		OrganizationID string `json:"organization_id"`
		ProjectID      string `json:"project_id"`
	}
	if err := json.Unmarshal(data, &creds); err != nil {
		return nil, errors.Wrap(err, "PostHog credentials are malformed JSON")
	}
	if creds.APIKey == "" {
		return nil, errors.New("PostHog credentials are missing api_key")
	}
	cfg := terraform.ProviderConfiguration{}
	for key, value := range map[string]string{
		"api_key":         creds.APIKey,
		"host":            creds.Host,
		"organization_id": creds.OrganizationID,
		"project_id":      creds.ProjectID,
	} {
		if value != "" {
			cfg[key] = value
		}
	}
	return cfg, nil
}

func resolveProviderConfig(ctx context.Context, c client.Client, mg resource.ModernManaged) (*v1beta1.ProviderConfigSpec, error) {
	configRef := mg.GetProviderConfigReference()
	pcRuntimeObj, err := c.Scheme().New(v1beta1.SchemeGroupVersion.WithKind(configRef.Kind))
	if err != nil {
		return nil, errors.Wrap(err, "unknown GVK for ProviderConfig")
	}
	pcObj := pcRuntimeObj.(client.Object)

	if err := c.Get(ctx, types.NamespacedName{Name: configRef.Name, Namespace: mg.GetNamespace()}, pcObj); err != nil {
		return nil, errors.Wrap(err, errGetProviderConfig)
	}

	var pcSpec v1beta1.ProviderConfigSpec
	switch pc := pcObj.(type) {
	case *v1beta1.ProviderConfig:
		pcSpec = pc.Spec
		if pcSpec.Credentials.SecretRef != nil {
			pcSpec.Credentials.SecretRef.Namespace = mg.GetNamespace()
		}
	case *v1beta1.ClusterProviderConfig:
		pcSpec = pc.Spec
	default:
		return nil, errors.New("unknown provider config type")
	}
	t := resource.NewProviderConfigUsageTracker(c, &v1beta1.ProviderConfigUsage{})
	if err := t.Track(ctx, mg); err != nil {
		return nil, errors.Wrap(err, errTrackUsage)
	}
	return &pcSpec, nil
}
