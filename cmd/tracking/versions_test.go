// SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
//
// SPDX-License-Identifier: MPL-2.0

package main

import (
	"strings"
	"testing"
)

func TestHighestForkTag(t *testing.T) {
	refs := strings.Split(`a1	refs/tags/v1.0.25
a2	refs/tags/v1.0.25-public
a3	refs/tags/v1.0.25-public.2
a4	refs/tags/v1.0.25-public.10
a5	refs/tags/v1.0.25-public.10^{}
a6	refs/tags/v1.0.25-publicx
a7	refs/tags/v1.0.250-public.99
a8	refs/tags/v1.0.26-public
a9	refs/tags/v1.0.26-rc.1-public.3`, "\n")

	cases := map[string]string{
		"1.0.25": "v1.0.25-public.10",
		"1.0.26": "v1.0.26-public",
		"1.0.30": "",
	}
	for v, want := range cases {
		if got := highestForkTag(refs, v); got != want {
			t.Errorf("highestForkTag(%q) = %q, want %q", v, got, want)
		}
	}
}

func TestOldestPending(t *testing.T) {
	upstream := []release{
		{Tag: "v1.0.28"},
		{Tag: "v1.0.10"},
		{Tag: "v1.0.9"},
		{Tag: "v1.0.8"},
		{Tag: "v1.0.7"},
	}
	ours := []release{{Tag: "v1.0.7"}, {Tag: "v1.0.8"}}

	cases := []struct {
		name     string
		upstream []release
		ours     []release
		acks     acks
		want     string
	}{
		{"oldest newer than our latest, by semver", upstream, ours, nil, "1.0.9"},
		{"skip entries are excluded", upstream, ours, acks{"1.0.9": {Skip: true}}, "1.0.10"},
		{"skip false is not a skip", upstream, ours, acks{"1.0.9": {Skip: false}}, "1.0.9"},
		{"drafts are excluded", []release{{Tag: "v1.0.9", Draft: true}, {Tag: "v1.0.10"}}, ours, nil, "1.0.10"},
		{"flagged prereleases are excluded", []release{{Tag: "v1.0.9", Prerelease: true}, {Tag: "v1.0.10"}}, ours, nil, "1.0.10"},
		{"semver prereleases are excluded", []release{{Tag: "v1.0.9-rc.1"}, {Tag: "v1.0.10"}}, ours, nil, "1.0.10"},
		{"non-semver upstream tags are ignored", []release{{Tag: "nightly"}, {Tag: "v1.0.11"}}, ours, nil, "1.0.11"},
		{"our drafts do not count as our latest", upstream, []release{{Tag: "v1.0.7"}, {Tag: "v2.0.0", Draft: true}}, nil, "1.0.8"},
		{"our prereleases do not count as our latest", upstream, []release{{Tag: "v1.0.7"}, {Tag: "v2.0.0", Prerelease: true}}, nil, "1.0.8"},
		{"nothing newer", []release{{Tag: "v1.0.8"}}, ours, nil, ""},
		{"no release of ours", upstream, nil, nil, ""},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := oldestPending(c.upstream, c.ours, c.acks); got != c.want {
				t.Errorf("oldestPending() = %q, want %q", got, c.want)
			}
		})
	}
}

func TestDecodeReleasesAcceptsPaginatedArrays(t *testing.T) {
	got, err := decodeReleases(strings.NewReader(`[{"tag_name":"v1.0.1","draft":true}][{"tag_name":"v1.0.2","prerelease":true}]`))
	if err != nil {
		t.Fatal(err)
	}
	want := []release{{Tag: "v1.0.1", Draft: true}, {Tag: "v1.0.2", Prerelease: true}}
	if len(got) != len(want) || got[0] != want[0] || got[1] != want[1] {
		t.Errorf("decodeReleases() = %+v, want %+v", got, want)
	}
}
