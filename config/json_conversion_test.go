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
		"KeepsHTMLCharacters": {
			mode: ujconfig.ToTerraform,
			in:   map[string]any{"query_json": `{"q": "<a> & <b>"}`},
			want: map[string]any{"query_json": `{"q":"<a> & <b>"}`},
		},
		"LeavesTrailingData": {
			mode: ujconfig.ToTerraform,
			in:   map[string]any{"a_json": `{"b": 1} {"c": 2}`, "b_json": `{"b": 1} x`, "c_json": `{"b": 1}}`},
			want: map[string]any{"a_json": `{"b": 1} {"c": 2}`, "b_json": `{"b": 1} x`, "c_json": `{"b": 1}}`},
		},
		"LeavesEmptyString": {
			mode: ujconfig.ToTerraform,
			in:   map[string]any{"query_json": ""},
			want: map[string]any{"query_json": ""},
		},
		"KeepsNonASCII": {
			mode: ujconfig.ToTerraform,
			in:   map[string]any{"query_json": `{"name": "café ✓ 日本"}`},
			want: map[string]any{"query_json": `{"name":"café ✓ 日本"}`},
		},
		"SortsObjectsInArrays": {
			mode: ujconfig.ToTerraform,
			in:   map[string]any{"filters_json": `[{"b": 1, "a": 2}, {"d": [{"f": 3, "e": 4}]}]`},
			want: map[string]any{"filters_json": `[{"a":2,"b":1},{"d":[{"e":4,"f":3}]}]`},
		},
		"LeavesNonStringValues": {
			mode: ujconfig.ToTerraform,
			in:   map[string]any{"a_json": nil, "b_json": 1.5, "c_json": map[string]any{"b": 1}},
			want: map[string]any{"a_json": nil, "b_json": 1.5, "c_json": map[string]any{"b": 1}},
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
