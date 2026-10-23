package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/crossplane/upjet/v2/pkg/pipeline"
	tjtypes "github.com/crossplane/upjet/v2/pkg/types"

	"github.com/Cliftonz/provider-upjet-posthog/config"
)

func main() {
	if len(os.Args) < 2 || os.Args[1] == "" {
		panic("root directory is required to be given as argument")
	}
	rootDir := os.Args[1]
	absRootDir, err := filepath.Abs(rootDir)
	if err != nil {
		panic(fmt.Sprintf("cannot calculate the absolute path with %s", rootDir))
	}
	pc := config.GetProvider()
	runner := &pipeline.PipelineRunner{
		DirAPIs:               filepath.Join(absRootDir, "apis", "namespaced"),
		DirControllers:        filepath.Join(absRootDir, "internal", "controller", "namespaced"),
		DirExamples:           filepath.Join(absRootDir, "examples-generated", "namespaced"),
		DirHack:               filepath.Join(absRootDir, "hack"),
		ModulePathAPIs:        filepath.Join(pc.ModulePath, "apis", "namespaced"),
		ModulePathControllers: filepath.Join(pc.ModulePath, "internal", "controller", "namespaced"),
		Scope:                 tjtypes.CRDScopeNamespaced,
	}
	runner.Run(pc)
}
