// SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
//
// SPDX-License-Identifier: MPL-2.0

package main

import (
	"io/fs"
	"os"
	"slices"
	"strings"

	apiextensionsv1 "k8s.io/apiextensions-apiserver/pkg/apis/apiextensions/v1"
	"k8s.io/apimachinery/pkg/util/yaml"
)

func loadCRDs(dir string) (map[string]apiextensionsv1.CustomResourceDefinition, error) {
	fsys := os.DirFS(dir)
	files, err := fs.Glob(fsys, "*.yaml")
	if err != nil {
		return nil, err
	}
	crds := map[string]apiextensionsv1.CustomResourceDefinition{}
	for _, f := range files {
		data, err := fs.ReadFile(fsys, f)
		if err != nil {
			return nil, err
		}
		var crd apiextensionsv1.CustomResourceDefinition
		if err := yaml.Unmarshal(data, &crd); err != nil {
			return nil, err
		}
		crds[crd.Name] = crd
	}
	return crds, nil
}

func crdChanges(oldDir, newDir string) ([]string, error) {
	oldCRDs, err := loadCRDs(oldDir)
	if err != nil {
		return nil, err
	}
	newCRDs, err := loadCRDs(newDir)
	if err != nil {
		return nil, err
	}
	var changes []string
	for name, o := range oldCRDs {
		n, ok := newCRDs[name]
		if !ok {
			changes = append(changes, name)
			continue
		}
		changes = append(changes, versionChanges(name, o.Spec.Versions, n.Spec.Versions)...)
	}
	slices.Sort(changes)
	return changes, nil
}

func versionChanges(crd string, o, n []apiextensionsv1.CustomResourceDefinitionVersion) []string {
	var changes []string
	for _, ov := range o {
		id := crd + "/" + ov.Name
		i := slices.IndexFunc(n, func(v apiextensionsv1.CustomResourceDefinitionVersion) bool { return v.Name == ov.Name })
		if i < 0 {
			changes = append(changes, id)
			continue
		}
		changes = append(changes, propertyChanges(id+":", ov.Schema.OpenAPIV3Schema, n[i].Schema.OpenAPIV3Schema)...)
	}
	return changes
}

func itemSchema(p *apiextensionsv1.JSONSchemaProps) *apiextensionsv1.JSONSchemaProps {
	if p.Items == nil {
		return nil
	}
	return p.Items.Schema
}

func propertyChanges(prefix string, o, n *apiextensionsv1.JSONSchemaProps) []string {
	var changes []string
	for name, op := range o.Properties {
		p := prefix + name
		np, ok := n.Properties[name]
		if !ok || np.Type != op.Type {
			changes = append(changes, p)
			continue
		}
		changes = append(changes, propertyChanges(p+".", &op, &np)...)
	}
	oi, ni := itemSchema(o), itemSchema(n)
	if oi == nil {
		return changes
	}
	array := strings.TrimSuffix(prefix, ".")
	if ni == nil || ni.Type != oi.Type {
		return append(changes, array)
	}
	return append(changes, propertyChanges(array+"[].", oi, ni)...)
}
