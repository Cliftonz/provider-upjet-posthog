// SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
//
// SPDX-License-Identifier: MPL-2.0

package main

import (
	"reflect"
	"testing"
)

func schemaJSON(resources string) []byte {
	return []byte(`{"format_version":"1.0","provider_schemas":{"registry.terraform.io/posthog/posthog":{"resource_schemas":{` + resources + `}}}}`)
}

func TestSchemaChanges(t *testing.T) {
	old := schemaJSON(`
"posthog_gone": {"block": {"attributes": {"id": {"type": "string"}}}},
"posthog_kept": {"block": {
  "attributes": {
    "id": {"type": "string"},
    "removed": {"type": "string"},
    "retyped": {"type": "string"},
    "list_retyped": {"type": ["list", "string"]},
    "nested": {"nested_type": {"nesting_mode": "single", "attributes": {"inner": {"type": "bool"}, "kept": {"type": "bool"}}}},
    "nesting": {"nested_type": {"nesting_mode": "single", "attributes": {"a": {"type": "bool"}}}}
  },
  "block_types": {
    "blk": {"nesting_mode": "list", "block": {"attributes": {"x": {"type": "number"}, "y": {"type": "number"}}}},
    "blk_gone": {"nesting_mode": "list", "block": {}}
  }
}}`)
	updated := schemaJSON(`
"posthog_kept": {"block": {
  "attributes": {
    "id": {"type": "string"},
    "added": {"type": "string"},
    "retyped": {"type": "number"},
    "list_retyped": {"type": ["set", "string"]},
    "nested": {"nested_type": {"nesting_mode": "single", "attributes": {"kept": {"type": "bool"}}}},
    "nesting": {"nested_type": {"nesting_mode": "list", "attributes": {"a": {"type": "bool"}}}}
  },
  "block_types": {
    "blk": {"nesting_mode": "list", "block": {"attributes": {"x": {"type": "string"}, "y": {"type": "number"}}}}
  }
}},
"posthog_new": {"block": {"attributes": {"id": {"type": "string"}}}}`)

	got, err := schemaChanges(old, updated)
	if err != nil {
		t.Fatal(err)
	}
	want := []string{
		"posthog_gone",
		"posthog_kept.blk.x",
		"posthog_kept.blk_gone",
		"posthog_kept.list_retyped",
		"posthog_kept.nested.inner",
		"posthog_kept.nesting",
		"posthog_kept.removed",
		"posthog_kept.retyped",
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("schemaChanges() = %v, want %v", got, want)
	}
}

func TestNewResources(t *testing.T) {
	s := schemaJSON(`"posthog_a": {"block": {}}, "posthog_b": {"block": {}}, "posthog_c": {"block": {}}`)
	got, err := newResources(s, map[string]bool{"posthog_b": true})
	if err != nil {
		t.Fatal(err)
	}
	if want := []string{"posthog_a", "posthog_c"}; !reflect.DeepEqual(got, want) {
		t.Errorf("newResources() = %v, want %v", got, want)
	}
}
