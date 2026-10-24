package config

import (
	"encoding/json"
	"strings"

	ujconfig "github.com/crossplane/upjet/v2/pkg/config"
)

type canonicalJSON struct{}

func (canonicalJSON) Convert(params map[string]any, _ *ujconfig.Resource, mode ujconfig.Mode) (map[string]any, error) {
	if mode != ujconfig.ToTerraform {
		return params, nil
	}
	for key, value := range params {
		s, ok := value.(string)
		if !ok || !strings.HasSuffix(key, "_json") {
			continue
		}
		decoder := json.NewDecoder(strings.NewReader(s))
		decoder.UseNumber()
		var parsed any
		if decoder.Decode(&parsed) != nil || strings.TrimSpace(s[decoder.InputOffset():]) != "" {
			continue
		}
		var canonical strings.Builder
		encoder := json.NewEncoder(&canonical)
		encoder.SetEscapeHTML(false)
		_ = encoder.Encode(parsed) //nolint:errchkjson
		params[key] = strings.TrimSuffix(canonical.String(), "\n")
	}
	return params, nil
}
