// SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
//
// SPDX-License-Identifier: MPL-2.0

package main

import (
	"reflect"
	"testing"
)

func TestNewResources(t *testing.T) {
	s := []byte(`{"format_version":"1.0","provider_schemas":{"registry.terraform.io/posthog/posthog":{"resource_schemas":{"posthog_a": {"block": {}}, "posthog_b": {"block": {}}, "posthog_c": {"block": {}}}}}}`)
	got, err := newResources(s, map[string]bool{"posthog_b": true})
	if err != nil {
		t.Fatal(err)
	}
	if want := []string{"posthog_a", "posthog_c"}; !reflect.DeepEqual(got, want) {
		t.Errorf("newResources() = %v, want %v", got, want)
	}
}
