// SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
//
// SPDX-License-Identifier: MPL-2.0

package main

import (
	"encoding/json"
	"errors"
	"io"
	"regexp"
	"strings"

	"k8s.io/apimachinery/pkg/util/version"
)

type release struct {
	Tag        string `json:"tag_name"`
	Draft      bool   `json:"draft"`
	Prerelease bool   `json:"prerelease"`
}

func highestForkTag(refs []string, upstreamVersion string) string {
	pattern := regexp.MustCompile(`^v` + regexp.QuoteMeta(upstreamVersion) + `-public(\.\d+)?$`)
	var best string
	var bestVersion *version.Version
	for _, ref := range refs {
		fields := strings.Fields(ref)
		tag := strings.TrimPrefix(fields[len(fields)-1], "refs/tags/")
		if !pattern.MatchString(tag) {
			continue
		}
		v := version.MustParseSemantic(tag)
		if bestVersion == nil || v.GreaterThan(bestVersion) {
			best, bestVersion = tag, v
		}
	}
	return best
}

func latestRelease(ours []release) *version.Version {
	var latest *version.Version
	for _, r := range ours {
		v := version.MustParseSemantic(r.Tag)
		if latest == nil || v.GreaterThan(latest) {
			latest = v
		}
	}
	return latest
}

func pendingVersion(r release, latest *version.Version, a acks) *version.Version {
	if r.Draft || r.Prerelease {
		return nil
	}
	v := version.MustParseSemantic(r.Tag)
	if v.PreRelease() != "" || !v.GreaterThan(latest) || a[v.String()].Skip {
		return nil
	}
	return v
}

func oldestPending(upstream, ours []release, a acks) string {
	latest := latestRelease(ours)
	if latest == nil {
		return ""
	}
	var oldest *version.Version
	for _, r := range upstream {
		if v := pendingVersion(r, latest, a); v != nil && (oldest == nil || v.LessThan(oldest)) {
			oldest = v
		}
	}
	if oldest == nil {
		return ""
	}
	return oldest.String()
}

func decodeReleases(r io.Reader) ([]release, error) {
	var all []release
	dec := json.NewDecoder(r)
	for {
		var page []release
		err := dec.Decode(&page)
		if errors.Is(err, io.EOF) {
			return all, nil
		}
		if err != nil {
			return nil, err
		}
		all = append(all, page...)
	}
}
