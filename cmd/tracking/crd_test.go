// SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
//
// SPDX-License-Identifier: MPL-2.0

package main

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func writeCRDs(t *testing.T, files map[string]string) string {
	t.Helper()
	dir := t.TempDir()
	for name, body := range files {
		if err := os.WriteFile(filepath.Join(dir, name), []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	return dir
}

const roleCRDOld = `apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: roles.access.posthog.m.clifton.quest
spec:
  group: access.posthog.m.clifton.quest
  names: {kind: Role, plural: roles}
  scope: Namespaced
  versions:
  - name: v1alpha1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              forProvider:
                type: object
                properties:
                  name: {type: string}
                  removed: {type: string}
                  retyped: {type: string}
                  ids:
                    type: array
                    items: {type: string}
                  tags:
                    type: array
                    items:
                      type: object
                      properties:
                        key: {type: string}
                        value: {type: string}
  - name: v1alpha2
    served: true
    storage: false
    schema:
      openAPIV3Schema:
        type: object
`

const roleCRDNew = `apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: roles.access.posthog.m.clifton.quest
spec:
  group: access.posthog.m.clifton.quest
  names: {kind: Role, plural: roles}
  scope: Namespaced
  versions:
  - name: v1alpha1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              forProvider:
                type: object
                properties:
                  name: {type: string}
                  added: {type: string}
                  retyped: {type: number}
                  ids:
                    type: array
                    items: {type: number}
                  tags:
                    type: array
                    items:
                      type: object
                      properties:
                        key: {type: string}
`

const goneCRD = `apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: gones.access.posthog.m.clifton.quest
spec:
  group: access.posthog.m.clifton.quest
  names: {kind: Gone, plural: gones}
  scope: Namespaced
  versions:
  - name: v1alpha1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
`

func TestCRDChanges(t *testing.T) {
	oldDir := writeCRDs(t, map[string]string{"role.yaml": roleCRDOld, "gone.yaml": goneCRD})
	newDir := writeCRDs(t, map[string]string{"role.yaml": roleCRDNew})

	got, err := crdChanges(oldDir, newDir)
	if err != nil {
		t.Fatal(err)
	}
	want := []string{
		"gones.access.posthog.m.clifton.quest",
		"roles.access.posthog.m.clifton.quest/v1alpha1:spec.forProvider.ids",
		"roles.access.posthog.m.clifton.quest/v1alpha1:spec.forProvider.removed",
		"roles.access.posthog.m.clifton.quest/v1alpha1:spec.forProvider.retyped",
		"roles.access.posthog.m.clifton.quest/v1alpha1:spec.forProvider.tags[].value",
		"roles.access.posthog.m.clifton.quest/v1alpha2",
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("crdChanges() = %v, want %v", got, want)
	}
}

func TestCRDChangesNoneWhenIdentical(t *testing.T) {
	dir := writeCRDs(t, map[string]string{"role.yaml": roleCRDOld})
	got, err := crdChanges(dir, dir)
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 0 {
		t.Errorf("crdChanges() = %v, want none", got)
	}
}
