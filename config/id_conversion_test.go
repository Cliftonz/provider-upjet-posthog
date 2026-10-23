package config

import (
	"testing"

	ujconfig "github.com/crossplane/upjet/v2/pkg/config"
	"github.com/google/go-cmp/cmp"
)

func TestIDToString(t *testing.T) {
	cases := map[string]struct {
		mode ujconfig.Mode
		in   map[string]any
		want map[string]any
	}{
		"NumericIDFromTerraform": {
			mode: ujconfig.FromTerraform,
			in:   map[string]any{"id": int64(42), "name": "x"},
			want: map[string]any{"id": "42", "name": "x"},
		},
		"StringIDFromTerraform": {
			mode: ujconfig.FromTerraform,
			in:   map[string]any{"id": "0/feature_flag/default"},
			want: map[string]any{"id": "0/feature_flag/default"},
		},
		"ToTerraform": {
			mode: ujconfig.ToTerraform,
			in:   map[string]any{"id": "42"},
			want: map[string]any{"id": "42"},
		},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			got, err := idToString{}.Convert(tc.in, nil, tc.mode)
			if err != nil {
				t.Fatal(err)
			}
			if diff := cmp.Diff(tc.want, got); diff != "" {
				t.Errorf("-want +got:\n%s", diff)
			}
		})
	}
}
