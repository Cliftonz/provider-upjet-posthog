// SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
//
// SPDX-License-Identifier: MPL-2.0

package main

import (
	"reflect"
	"strings"
	"testing"
)

func diff(path, body string) string {
	return "diff --git a/" + path + " b/" + path + "\nindex 1..2 100644\n--- a/" + path + "\n+++ b/" + path + "\n" + body
}

const pinHunk = `@@ -12,5 +12,5 @@
 export TERRAFORM_PROVIDER_REPO ?= https://github.com/Cliftonz/terraform-provider-posthog
-export TERRAFORM_PROVIDER_VERSION ?= 1.0.25
-export TERRAFORM_PROVIDER_REF ?= e708a31
+export TERRAFORM_PROVIDER_VERSION ?= 1.0.26
+export TERRAFORM_PROVIDER_REF ?= v1.0.26-public
 export TERRAFORM_PROVIDER_MODULE ?= github.com/posthog/terraform-provider
`

const hunk = "@@ -1 +1 @@\n-a\n+b\n"

func TestDisallowedPaths(t *testing.T) {
	allowed := strings.Join([]string{
		diff("apis/project/v1alpha1/zz_project_types.go", hunk),
		diff("internal/controller/project/zz_controller.go", hunk),
		diff("package/crds/project.yaml", hunk),
		diff("config/schema.json", hunk),
		diff("config/provider-metadata.yaml", hunk),
		diff("examples-generated/namespaced/project.yaml", hunk),
		diff("go.mod", hunk),
		diff("go.sum", hunk),
		diff("Makefile", pinHunk),
		"diff --git a/apis/new.go b/apis/new.go\nnew file mode 100644\nindex 0..1\nGIT binary patch\nliteral 2\nJcmZQ%000\n\n",
	}, "")

	cases := []struct {
		name  string
		patch string
		want  []string
	}{
		{"allowlisted paths and pin lines pass", allowed, nil},
		{"other paths are rejected", allowed + diff("hack/open-pr.sh", hunk) + diff("cmd/tracking/main.go", hunk) + diff("config/provider.go", hunk), []string{"cmd/tracking/main.go", "config/provider.go", "hack/open-pr.sh"}},
		{"a prefix match is not a directory match", diff("apis-extra/x.go", hunk) + diff("go.mod.bak", hunk), []string{"apis-extra/x.go", "go.mod.bak"}},
		{"renames check both paths", "diff --git a/apis/x.go b/hack/x.go\nsimilarity index 100%\nrename from apis/x.go\nrename to hack/x.go\n", []string{"hack/x.go"}},
		{"other Makefile hunks are rejected", diff("Makefile", pinHunk+"@@ -40 +40 @@\n-build: x\n+build: y\n"), []string{"Makefile"}},
		{"a removed Makefile line starting with dashes is checked", diff("Makefile", "@@ -40 +40 @@\n--- comment\n+export TERRAFORM_PROVIDER_REF ?= x\n"), []string{"Makefile"}},
		{"a pin value with a make expansion is rejected", diff("Makefile", "@@ -12 +12 @@\n-export TERRAFORM_PROVIDER_REF ?= x\n+export TERRAFORM_PROVIDER_REF ?= $(shell id)\n"), []string{"Makefile"}},
		{"a pin value with a space is rejected", diff("Makefile", "@@ -12 +12 @@\n-export TERRAFORM_PROVIDER_REF ?= x\n+export TERRAFORM_PROVIDER_REF ?= x y\n"), []string{"Makefile"}},
		{"a pin value with quotes is rejected", diff("Makefile", "@@ -12 +12 @@\n-export TERRAFORM_PROVIDER_VERSION ?= 1.0.25\n+export TERRAFORM_PROVIDER_VERSION ?= \"1.0.26\"\n"), []string{"Makefile"}},
		{"an empty pin value is rejected", diff("Makefile", "@@ -12 +12 @@\n-export TERRAFORM_PROVIDER_VERSION ?= 1.0.25\n+export TERRAFORM_PROVIDER_VERSION ?= \n"), []string{"Makefile"}},
		{"a pin value with semver suffixes passes", diff("Makefile", "@@ -12 +12 @@\n-export TERRAFORM_PROVIDER_VERSION ?= 1.0.25\n+export TERRAFORM_PROVIDER_VERSION ?= 1.0.26-rc.1+build_2\n"), nil},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := disallowedPaths(c.patch); !reflect.DeepEqual(got, c.want) {
				t.Errorf("disallowedPaths() = %v, want %v", got, c.want)
			}
		})
	}
}
