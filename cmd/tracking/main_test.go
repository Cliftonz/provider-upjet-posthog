// SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
//
// SPDX-License-Identifier: MPL-2.0

package main

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func writeFile(t *testing.T, content string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "file")
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
	return path
}

func runTracking(args []string, stdin string) (string, error) {
	var out bytes.Buffer
	err := run(args, strings.NewReader(stdin), &out)
	return out.String(), err
}

func TestRunGateFailsAndPrintsUnacknowledgedChanges(t *testing.T) {
	acksPath := writeFile(t, `"1.0.27":
  new_resources:
    - posthog_notebook
`)
	out, err := runTracking([]string{"gate", acksPath, v27, "new-resource"}, "posthog_notebook\nposthog_survey_v2\n")
	if err == nil || err.Error() != "new-resource gate: 1 unacknowledged changes for 1.0.27" {
		t.Errorf("run(gate) error = %v", err)
	}
	if out != "posthog_survey_v2\n" {
		t.Errorf("run(gate) printed %q", out)
	}
}

func TestRunGatePassesWhenEveryChangeIsAcknowledged(t *testing.T) {
	acksPath := writeFile(t, `"1.0.27":
  breaking:
    - posthog_dashboard.description
`)
	out, err := runTracking([]string{"gate", acksPath, v27, "breaking-change"}, "posthog_dashboard.description\n")
	if err != nil || out != "" {
		t.Errorf("run(gate) = %q, %v", out, err)
	}
}

func TestRunSkipsPrintsSkippedVersionsInOrder(t *testing.T) {
	acksPath := writeFile(t, `"1.0.28":
  skip: true
"1.0.26":
  skip: true
"1.0.27":
  new_resources:
    - posthog_notebook
`)
	out, err := runTracking([]string{"skips", acksPath}, "")
	if err != nil || out != "1.0.26\n1.0.28\n" {
		t.Errorf("run(skips) = %q, %v", out, err)
	}
}

func TestRunPatchPathsFailsAndPrintsDisallowedPaths(t *testing.T) {
	patchPath := writeFile(t, diff("hack/bump.sh", hunk)+diff("apis/x.go", hunk))
	out, err := runTracking([]string{"patch-paths", patchPath}, "")
	if err == nil || err.Error() != "patch touches 1 paths outside the generation allowlist" {
		t.Errorf("run(patch-paths) error = %v", err)
	}
	if out != "hack/bump.sh\n" {
		t.Errorf("run(patch-paths) printed %q", out)
	}
}

func TestRunRejectsUnknownCommands(t *testing.T) {
	for _, command := range []string{"publish", "fork-tag"} {
		if _, err := runTracking([]string{command, v27}, ""); err == nil || err.Error() != usage {
			t.Errorf("run(%s) error = %v, want usage", command, err)
		}
	}
}
