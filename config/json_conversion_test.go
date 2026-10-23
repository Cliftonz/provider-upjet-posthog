package config

import (
	"testing"

	ujconfig "github.com/crossplane/upjet/v2/pkg/config"
	"github.com/google/go-cmp/cmp"
)

func TestCanonicalJSON(t *testing.T) {
	cases := map[string]struct {
		mode ujconfig.Mode
		in   map[string]any
		want map[string]any
	}{
		"SortsAndCompactsJSONFields": {
			mode: ujconfig.ToTerraform,
			in:   map[string]any{"query_json": "{\"b\": 1, \"a\": {\"d\": 2, \"c\": 3}}\n", "name": "{\"z\": 1, \"y\": 2}"},
			want: map[string]any{"query_json": `{"a":{"c":3,"d":2},"b":1}`, "name": "{\"z\": 1, \"y\": 2}"},
		},
		"KeepsLargeIntegers": {
			mode: ujconfig.ToTerraform,
			in:   map[string]any{"ids_json": "[12345678901234567890, 1.50]"},
			want: map[string]any{"ids_json": "[12345678901234567890,1.50]"},
		},
		"LeavesInvalidJSON": {
			mode: ujconfig.ToTerraform,
			in:   map[string]any{"query_json": "not json"},
			want: map[string]any{"query_json": "not json"},
		},
		"FromTerraform": {
			mode: ujconfig.FromTerraform,
			in:   map[string]any{"query_json": "{\"b\": 1, \"a\": 2}"},
			want: map[string]any{"query_json": "{\"b\": 1, \"a\": 2}"},
		},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			got, err := canonicalJSON{}.Convert(tc.in, nil, tc.mode)
			if err != nil {
				t.Fatal(err)
			}
			if diff := cmp.Diff(tc.want, got); diff != "" {
				t.Errorf("-want +got:\n%s", diff)
			}
		})
	}
}
