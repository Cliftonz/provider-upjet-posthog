// SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
//
// SPDX-License-Identifier: MPL-2.0

package main

import (
	"encoding/json"
	"fmt"
	"os"
	"slices"

	"github.com/Cliftonz/provider-upjet-posthog/config"
)

func main() {
	if err := run(os.Args[1]); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run(schemaPath string) error {
	schema, err := os.ReadFile(schemaPath) //nolint:gosec
	if err != nil {
		return err
	}
	configured := map[string]bool{}
	for name := range config.GetProvider().Resources {
		configured[name] = true
	}
	names, err := newResources(schema, configured)
	for _, name := range names {
		fmt.Println(name)
	}
	return err
}

func newResources(schema []byte, configured map[string]bool) ([]string, error) {
	var s struct {
		ProviderSchemas map[string]struct {
			ResourceSchemas map[string]json.RawMessage `json:"resource_schemas"`
		} `json:"provider_schemas"`
	}
	if err := json.Unmarshal(schema, &s); err != nil {
		return nil, err
	}
	var names []string
	for _, p := range s.ProviderSchemas {
		for name := range p.ResourceSchemas {
			if !configured[name] {
				names = append(names, name)
			}
		}
	}
	slices.Sort(names)
	return names, nil
}
