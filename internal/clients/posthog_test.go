package clients

import (
	"strings"
	"testing"

	"github.com/crossplane/upjet/v2/pkg/terraform"
	"github.com/google/go-cmp/cmp"
)

func TestProviderConfiguration(t *testing.T) {
	cases := map[string]struct {
		credentials string
		want        terraform.ProviderConfiguration
		wantErr     string
	}{
		"AllKeys": {
			credentials: `{"api_key":"phx_k","host":"https://eu.posthog.com","organization_id":"@current","project_id":"12345"}`,
			want: terraform.ProviderConfiguration{
				"api_key":         "phx_k",
				"host":            "https://eu.posthog.com",
				"organization_id": "@current",
				"project_id":      "12345",
			},
		},
		"AbsentKeysOmitted": {
			credentials: `{"api_key":"phx_k"}`,
			want:        terraform.ProviderConfiguration{"api_key": "phx_k"},
		},
		"EmptyKeysOmitted": {
			credentials: `{"api_key":"phx_k","host":"","organization_id":"","project_id":""}`,
			want:        terraform.ProviderConfiguration{"api_key": "phx_k"},
		},
		"MalformedJSON": {
			credentials: `{"api_key":`,
			wantErr:     "malformed JSON",
		},
		"MissingAPIKey": {
			credentials: `{"host":"https://eu.posthog.com"}`,
			wantErr:     "missing api_key",
		},
		"EmptyAPIKey": {
			credentials: `{"api_key":""}`,
			wantErr:     "missing api_key",
		},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			got, err := providerConfiguration([]byte(tc.credentials))
			if tc.wantErr != "" {
				if err == nil || !strings.Contains(err.Error(), tc.wantErr) {
					t.Fatalf("providerConfiguration() error = %v, want error containing %q", err, tc.wantErr)
				}
				return
			}
			if err != nil {
				t.Fatalf("providerConfiguration() unexpected error: %v", err)
			}
			if diff := cmp.Diff(tc.want, got); diff != "" {
				t.Errorf("providerConfiguration() -want +got:\n%s", diff)
			}
		})
	}
}
