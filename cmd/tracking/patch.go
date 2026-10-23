// SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
//
// SPDX-License-Identifier: MPL-2.0

package main

import (
	"regexp"
	"slices"
	"strings"
)

var (
	allowedDirs  = []string{"apis/", "internal/controller/", "package/crds/", "examples-generated/"}
	allowedFiles = []string{"config/schema.json", "config/provider-metadata.yaml", "go.mod", "go.sum", "Makefile"}
	pinLine      = regexp.MustCompile(`^[+-]export TERRAFORM_PROVIDER_(VERSION|REF) \?= `)
)

func allowedPath(p string) bool {
	return slices.Contains(allowedFiles, p) || slices.ContainsFunc(allowedDirs, func(dir string) bool { return strings.HasPrefix(p, dir) })
}

func disallowedPaths(patch string) []string {
	var bad []string
	makefile, hunk := false, false
	for _, line := range strings.Split(patch, "\n") {
		switch {
		case strings.HasPrefix(line, "diff --git "):
			f := strings.Fields(line)
			paths := []string{strings.TrimPrefix(f[2], "a/"), strings.TrimPrefix(f[3], "b/")}
			makefile, hunk = slices.Contains(paths, "Makefile"), false
			bad = append(bad, slices.DeleteFunc(paths, allowedPath)...)
		case strings.HasPrefix(line, "@@"):
			hunk = true
		case makefile && hunk && (strings.HasPrefix(line, "+") || strings.HasPrefix(line, "-")) && !pinLine.MatchString(line):
			bad = append(bad, "Makefile")
		}
	}
	slices.Sort(bad)
	return slices.Compact(bad)
}
