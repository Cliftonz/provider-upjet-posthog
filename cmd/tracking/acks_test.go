// SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
//
// SPDX-License-Identifier: MPL-2.0

package main

import (
	"reflect"
	"testing"
)

const (
	v27      = "1.0.27"
	notebook = "posthog_notebook"
)

func TestParseAcks(t *testing.T) {
	got, err := parseAcks([]byte(`
"1.0.26":
  skip: true
"1.0.27":
  breaking:
    - posthog_insight.query
  new_resources:
    - posthog_notebook
`))
	if err != nil {
		t.Fatal(err)
	}
	want := acks{
		"1.0.26": {Skip: true},
		v27:      {Breaking: []string{"posthog_insight.query"}, NewResources: []string{notebook}},
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("parseAcks() = %+v, want %+v", got, want)
	}
}

func TestParseAcksEmptyFile(t *testing.T) {
	got, err := parseAcks([]byte("# comments only\n{}\n"))
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 0 {
		t.Errorf("parseAcks() = %+v, want empty", got)
	}
}

func TestUnacked(t *testing.T) {
	a := acks{
		v27: {
			Breaking:     []string{"posthog_insight.query", "posthog_role"},
			NewResources: []string{notebook},
		},
		"1.0.26": {Breaking: []string{"posthog_survey.name"}},
	}
	cases := []struct {
		name    string
		gate    string
		version string
		changes []string
		want    []string
	}{
		{"acknowledged breaking changes pass", gateBreaking, v27, []string{"posthog_insight.query", "posthog_role"}, nil},
		{"unacknowledged breaking changes remain", gateBreaking, v27, []string{"posthog_insight.query", "posthog_cohort.name"}, []string{"posthog_cohort.name"}},
		{"acknowledgements of another version do not apply", gateBreaking, v27, []string{"posthog_survey.name"}, []string{"posthog_survey.name"}},
		{"matching is exact", gateBreaking, v27, []string{"posthog_insight.query.kind"}, []string{"posthog_insight.query.kind"}},
		{"new resources use their own list", gateNewResource, v27, []string{notebook, "posthog_role"}, []string{"posthog_role"}},
		{"version without entries", gateNewResource, "1.0.28", []string{notebook}, []string{notebook}},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := unacked(c.changes, a[c.version], c.gate); !reflect.DeepEqual(got, c.want) {
				t.Errorf("unacked() = %v, want %v", got, c.want)
			}
		})
	}
}
