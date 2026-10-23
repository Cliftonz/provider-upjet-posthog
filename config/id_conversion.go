package config

import (
	"strconv"

	ujconfig "github.com/crossplane/upjet/v2/pkg/config"
)

type idToString struct{}

func (idToString) Convert(params map[string]any, _ *ujconfig.Resource, mode ujconfig.Mode) (map[string]any, error) {
	if id, ok := params["id"].(int64); ok && mode == ujconfig.FromTerraform {
		params["id"] = strconv.FormatInt(id, 10)
	}
	return params, nil
}
