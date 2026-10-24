package config

import (
	"regexp"
	"testing"
)

func included(name string) bool {
	for _, pattern := range resourceNames() {
		if regexp.MustCompile(pattern).MatchString(name) {
			return true
		}
	}
	return false
}

func TestIncludeListMatchesOnlyConfiguredResources(t *testing.T) {
	for name := range resources {
		if !included(name) {
			t.Errorf("%s is not included", name)
		}
	}
	for _, name := range []string{"posthog_foo_alert", "posthog_logs_alert_extra", "posthog_foo_posthog_alert", "posthog_logs_posthog_logs_alert"} {
		if included(name) {
			t.Errorf("%s is included", name)
		}
	}
}
