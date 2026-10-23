**Title:** Expose the provider constructor in a public package so it can be embedded in-process

`New` lives in `internal/provider`, so Go's internal-package rule blocks other modules from importing it. In-process bridges such as Crossplane's upjet (no-fork mode) and Pulumi's statically bridged Terraform providers must call that constructor directly; we hit this building [Cliftonz/provider-upjet-posthog](https://github.com/Cliftonz/provider-upjet-posthog).

Two options, whichever you prefer:

A. Add a public package that re-exports the constructor, with `main.go` importing it so the binary uses the public path:

```go
// provider/provider.go
package provider

import (
	"github.com/hashicorp/terraform-plugin-framework/provider"

	internalprovider "github.com/posthog/terraform-provider/internal/provider"
)

func New(version string) func() provider.Provider {
	return internalprovider.New(version)
}
```

B. Move the provider package out of `internal/` entirely. This is already done on our fork, if you want to see or test it: [compare view](https://github.com/PostHog/terraform-provider-posthog/compare/main...Cliftonz:terraform-provider-posthog:public-provider). It moves the package, updates the two imports, and adds tests plus a CI step proving a module outside this path can import it (`test/externalimport`, a separate module with its own go.mod that CI tidies before testing); build, vet, and tests pass locally. Note that this makes every exported identifier in the package public API, so you can decide what to expose: `New`, `PostHogProvider` and its `provider.Provider` methods, `PostHogProviderModel`, and the constants `EnvPostHogAPIKey`, `EnvPostHogHost`, `EnvPostHogProjectId`, and `EnvPostHogOrganizationId`.

Neither changes anything for Terraform users: same binary, registry address, schemas, and state. Happy to open a PR for whichever option you'd take.
