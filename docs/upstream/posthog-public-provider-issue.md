**Title:** Expose the provider constructor in a public package so it can be embedded in-process

We maintain a Crossplane provider for PostHog, [Cliftonz/provider-upjet-posthog](https://github.com/Cliftonz/provider-upjet-posthog), published at xpkg.upbound.io/cliftonz/provider-upjet-posthog, which lets teams manage PostHog resources (feature flags, dashboards, insights, surveys, projects, access control, and the rest) as Kubernetes resources that are reconciled continuously, alongside the applications that use them (GitOps). It is generated with Crossplane's upjet from this Terraform provider, so every resource and behavior comes from here, and its releases match this provider's versions (v1.0.25 to v1.0.27 so far). upjet's recommended mode runs the Terraform provider in-process, which requires importing its constructor, while the alternative mode shells out to the terraform CLI on every reconcile. Today we build against a fork that moves the package out of `internal/`, and we would like to drop that fork.

The only thing keeping us on that fork is where the constructor lives: `New` is in `internal/provider`, so Go's internal-package rule blocks other modules from importing it. In-process bridges such as upjet's no-fork mode and Pulumi's statically bridged Terraform providers must call that constructor directly.

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

B. Move the provider package out of `internal/` entirely. This is already done on our fork, if you want to see or test it: [compare view](https://github.com/PostHog/terraform-provider-posthog/compare/main...Cliftonz:terraform-provider-posthog:expose-provider). It moves the package, updates the two imports, adds `./provider/...` to `make test` and CI, and adds tests plus a CI step proving a module outside this path can import it (`test/externalimport`, a separate module with its own go.mod that CI tidies before testing); build, vet, and tests pass locally. Note that this makes every exported identifier in the package public API, so you can decide what to expose: `New`, `PostHogProvider` and its methods, `PostHogProviderModel`, and the constants `EnvPostHogAPIKey`, `EnvPostHogHost`, `EnvPostHogProjectId`, and `EnvPostHogOrganizationId`.

Neither changes anything for Terraform users: same binary, registry address, schemas, and state. Happy to open a PR for whichever option you'd take.
