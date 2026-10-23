// SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
//
// SPDX-License-Identifier: MPL-2.0

package main

import (
	"slices"

	"k8s.io/apimachinery/pkg/util/yaml"
)

const (
	gateBreaking    = "breaking-change"
	gateNewResource = "new-resource"
)

type ack struct {
	Skip         bool     `json:"skip"`
	Breaking     []string `json:"breaking"`
	NewResources []string `json:"new_resources"`
}

type acks map[string]ack

func parseAcks(data []byte) (acks, error) {
	var a acks
	return a, yaml.Unmarshal(data, &a)
}

func unacked(changes []string, a ack, gate string) []string {
	acknowledged := a.Breaking
	if gate == gateNewResource {
		acknowledged = a.NewResources
	}
	var out []string
	for _, c := range changes {
		if !slices.Contains(acknowledged, c) {
			out = append(out, c)
		}
	}
	return out
}
