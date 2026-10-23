// SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
//
// SPDX-License-Identifier: MPL-2.0

package main

import (
	"bytes"
	"encoding/json"
	"slices"
)

type tfSchema struct {
	ProviderSchemas map[string]struct {
		ResourceSchemas map[string]struct {
			Block tfBlock `json:"block"`
		} `json:"resource_schemas"`
	} `json:"provider_schemas"`
}

type tfBlock struct {
	Attributes map[string]tfAttribute `json:"attributes"`
	BlockTypes map[string]tfBlockType `json:"block_types"`
}

type tfBlockType struct {
	NestingMode string  `json:"nesting_mode"`
	Block       tfBlock `json:"block"`
}

type tfAttribute struct {
	Type       json.RawMessage `json:"type"`
	NestedType *tfNestedType   `json:"nested_type"`
	Required   bool            `json:"required"`
}

type tfNestedType struct {
	NestingMode string                 `json:"nesting_mode"`
	Attributes  map[string]tfAttribute `json:"attributes"`
}

func resourceBlocks(data []byte) (map[string]tfBlock, error) {
	var s tfSchema
	if err := json.Unmarshal(data, &s); err != nil {
		return nil, err
	}
	blocks := map[string]tfBlock{}
	for _, p := range s.ProviderSchemas {
		for name, r := range p.ResourceSchemas {
			blocks[name] = r.Block
		}
	}
	return blocks, nil
}

func schemaChanges(old, updated []byte) ([]string, error) {
	oldBlocks, err := resourceBlocks(old)
	if err != nil {
		return nil, err
	}
	newBlocks, err := resourceBlocks(updated)
	if err != nil {
		return nil, err
	}
	var changes []string
	for name, o := range oldBlocks {
		n, ok := newBlocks[name]
		if !ok {
			changes = append(changes, name)
			continue
		}
		changes = append(changes, blockChanges(name, o, n)...)
	}
	slices.Sort(changes)
	return slices.Compact(changes), nil
}

func blockChanges(path string, o, n tfBlock) []string {
	changes := attributeChanges(path, o.Attributes, n.Attributes)
	for name, ob := range o.BlockTypes {
		p := path + "." + name
		nb, ok := n.BlockTypes[name]
		if !ok || nb.NestingMode != ob.NestingMode {
			changes = append(changes, p)
			continue
		}
		changes = append(changes, blockChanges(p, ob.Block, nb.Block)...)
	}
	return changes
}

func attributeChanges(path string, o, n map[string]tfAttribute) []string {
	var changes []string
	for name, oa := range o {
		p := path + "." + name
		na, ok := n[name]
		if !ok || !bytes.Equal(oa.Type, na.Type) || (oa.NestedType == nil) != (na.NestedType == nil) {
			changes = append(changes, p)
			continue
		}
		if oa.NestedType == nil {
			continue
		}
		if oa.NestedType.NestingMode != na.NestedType.NestingMode {
			changes = append(changes, p)
			continue
		}
		changes = append(changes, attributeChanges(p, oa.NestedType.Attributes, na.NestedType.Attributes)...)
	}
	for name, na := range n {
		if na.Required && !o[name].Required {
			changes = append(changes, path+"."+name)
		}
	}
	return changes
}

func newResources(schema []byte, configured map[string]bool) ([]string, error) {
	blocks, err := resourceBlocks(schema)
	if err != nil {
		return nil, err
	}
	var names []string
	for name := range blocks {
		if !configured[name] {
			names = append(names, name)
		}
	}
	slices.Sort(names)
	return names, nil
}
