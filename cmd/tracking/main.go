// SPDX-FileCopyrightText: 2026 The provider-upjet-posthog authors
//
// SPDX-License-Identifier: MPL-2.0

package main

import (
	"bufio"
	"errors"
	"fmt"
	"io"
	"os"
	"slices"
	"strings"

	"github.com/Cliftonz/provider-upjet-posthog/config"
)

const usage = `usage:
  tracking fork-tag VERSION < git-ls-remote-tags
  tracking pending ACKS UPSTREAM_RELEASES_JSON OUR_RELEASES_JSON
  tracking skips ACKS
  tracking schema-diff OLD_SCHEMA NEW_SCHEMA
  tracking crd-diff OLD_CRD_DIR NEW_CRD_DIR
  tracking new-resources SCHEMA
  tracking gate ACKS VERSION breaking-change|new-resource < changes`

func main() {
	if err := run(os.Args[1:], os.Stdin, os.Stdout); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run(args []string, stdin io.Reader, stdout io.Writer) error {
	if len(args) == 0 {
		return errors.New(usage)
	}
	var lines []string
	var err error
	switch args[0] {
	case "fork-tag":
		lines = []string{highestForkTag(readLines(stdin), args[1])}
	case "pending":
		lines, err = pending(args[1], args[2], args[3])
	case "skips":
		lines, err = skips(args[1])
	case "schema-diff":
		lines, err = schemaDiff(args[1], args[2])
	case "crd-diff":
		lines, err = crdChanges(args[1], args[2])
	case "new-resources":
		lines, err = configuredNewResources(args[1])
	case "gate":
		return gate(args[1], args[2], args[3], readLines(stdin), stdout)
	default:
		return errors.New(usage)
	}
	if err != nil {
		return err
	}
	return printLines(stdout, lines)
}

func readLines(r io.Reader) []string {
	var lines []string
	s := bufio.NewScanner(r)
	for s.Scan() {
		if l := strings.TrimSpace(s.Text()); l != "" {
			lines = append(lines, l)
		}
	}
	return lines
}

func printLines(w io.Writer, lines []string) error {
	for _, l := range lines {
		if l == "" {
			continue
		}
		if _, err := fmt.Fprintln(w, l); err != nil {
			return err
		}
	}
	return nil
}

func loadAcks(path string) (acks, error) {
	data, err := os.ReadFile(path) //nolint:gosec
	if err != nil {
		return nil, err
	}
	return parseAcks(data)
}

func loadReleases(path string) ([]release, error) {
	f, err := os.Open(path) //nolint:gosec
	if err != nil {
		return nil, err
	}
	defer f.Close() //nolint:errcheck
	return decodeReleases(f)
}

func pending(acksPath, upstreamPath, oursPath string) ([]string, error) {
	a, err := loadAcks(acksPath)
	if err != nil {
		return nil, err
	}
	upstream, err := loadReleases(upstreamPath)
	if err != nil {
		return nil, err
	}
	ours, err := loadReleases(oursPath)
	if err != nil {
		return nil, err
	}
	return []string{oldestPending(upstream, ours, a)}, nil
}

func skips(acksPath string) ([]string, error) {
	a, err := loadAcks(acksPath)
	if err != nil {
		return nil, err
	}
	var versions []string
	for v, entry := range a {
		if entry.Skip {
			versions = append(versions, v)
		}
	}
	slices.Sort(versions)
	return versions, nil
}

func schemaDiff(oldPath, newPath string) ([]string, error) {
	old, err := os.ReadFile(oldPath) //nolint:gosec
	if err != nil {
		return nil, err
	}
	updated, err := os.ReadFile(newPath) //nolint:gosec
	if err != nil {
		return nil, err
	}
	return schemaChanges(old, updated)
}

func configuredNewResources(schemaPath string) ([]string, error) {
	schema, err := os.ReadFile(schemaPath) //nolint:gosec
	if err != nil {
		return nil, err
	}
	configured := map[string]bool{}
	for name := range config.GetProvider().Resources {
		configured[name] = true
	}
	return newResources(schema, configured)
}

func gate(acksPath, version, name string, changes []string, stdout io.Writer) error {
	a, err := loadAcks(acksPath)
	if err != nil {
		return err
	}
	remaining := unacked(changes, a[version], name)
	if err := printLines(stdout, remaining); err != nil {
		return err
	}
	if len(remaining) > 0 {
		return fmt.Errorf("%s gate: %d unacknowledged changes for %s", name, len(remaining), version)
	}
	return nil
}
