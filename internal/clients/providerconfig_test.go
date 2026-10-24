package clients

import (
	"context"
	"strings"
	"testing"

	xpv2 "github.com/crossplane/crossplane/apis/v2/core/v2"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/client/fake"

	apisNamespaced "github.com/Cliftonz/provider-upjet-posthog/apis/namespaced"
	"github.com/Cliftonz/provider-upjet-posthog/apis/namespaced/access/v1alpha1"
	"github.com/Cliftonz/provider-upjet-posthog/apis/namespaced/v1beta1"
)

func credentials(namespace string) v1beta1.ProviderCredentials {
	return v1beta1.ProviderCredentials{
		Source: xpv2.CredentialsSourceSecret,
		CommonCredentialSelectors: xpv2.CommonCredentialSelectors{
			SecretRef: &xpv2.SecretKeySelector{
				SecretReference: xpv2.SecretReference{Name: "posthog-creds", Namespace: namespace},
				Key:             "credentials",
			},
		},
	}
}

func resolve(t *testing.T, ref xpv2.ProviderConfigReference, objs ...client.Object) (*v1beta1.ProviderConfigSpec, error) {
	t.Helper()
	scheme := runtime.NewScheme()
	if err := apisNamespaced.AddToScheme(scheme); err != nil {
		t.Fatal(err)
	}
	c := fake.NewClientBuilder().WithScheme(scheme).WithObjects(objs...).Build()
	mg := &v1alpha1.Role{ObjectMeta: metav1.ObjectMeta{Name: "r", Namespace: "team-a", UID: "uid"}}
	mg.SetProviderConfigReference(&ref)
	return resolveProviderConfig(context.Background(), c, mg)
}

func TestProviderConfigReadsSecretFromManagedResourceNamespace(t *testing.T) {
	config := &v1beta1.ProviderConfig{
		ObjectMeta: metav1.ObjectMeta{Name: "default", Namespace: "team-a"},
		Spec:       v1beta1.ProviderConfigSpec{Credentials: credentials("elsewhere")},
	}
	spec, err := resolve(t, xpv2.ProviderConfigReference{Kind: "ProviderConfig", Name: "default"}, config)
	if err != nil {
		t.Fatal(err)
	}
	if got := spec.Credentials.SecretRef.Namespace; got != "team-a" {
		t.Errorf("secretRef namespace = %q, want team-a", got)
	}
}

func TestResolveProviderConfigRejectsOtherKinds(t *testing.T) {
	usage := &v1beta1.ProviderConfigUsage{ObjectMeta: metav1.ObjectMeta{Name: "default", Namespace: "team-a"}}
	_, err := resolve(t, xpv2.ProviderConfigReference{Kind: "ProviderConfigUsage", Name: "default"}, usage)
	if err == nil || !strings.Contains(err.Error(), "unknown provider config type") {
		t.Fatalf("error = %v, want unknown provider config type", err)
	}
}
