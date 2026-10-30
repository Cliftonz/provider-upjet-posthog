<p align="center"><img src="extensions/icons/icon.svg" alt="provider-posthog icon" width="200"></p>

# Provider PostHog

`provider-posthog` is a Crossplane v2 provider, generated with
[upjet](https://github.com/crossplane/upjet), that manages PostHog
configuration as namespaced managed resources. It embeds the PostHog
Terraform provider and covers all 26 of its resources.

## Install

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-posthog
spec:
  package: ghcr.io/cliftonz/provider-upjet-posthog:v1.0.25
```

The same package will also be on `xpkg.upbound.io/cliftonz/provider-upjet-posthog` once the Upbound robot token is configured.

## Configure

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: posthog-creds
  namespace: team-a
stringData:
  credentials: |
    {"api_key": "phx_...", "host": "https://us.posthog.com",
     "organization_id": "@current", "project_id": "12345"}
---
apiVersion: posthog.m.clifton.quest/v1beta1
kind: ProviderConfig
metadata:
  name: default
  namespace: team-a
spec:
  credentials:
    source: Secret
    secretRef:
      name: posthog-creds
      namespace: team-a
      key: credentials
```

A `ProviderConfig` always reads the Secret from its own namespace;
`secretRef.namespace` is required by the CRD. A `ClusterProviderConfig`
reads it from `secretRef.namespace`.

## More

- [SPEC.md](SPEC.md): design, API groups and kinds, credentials, release process
- [examples/namespaced](examples/namespaced): example manifests
- `test/harness`: local PostHog for end-to-end tests (coming)

## Upstream

The provider embeds `github.com/PostHog/terraform-provider-posthog` through the
fork `github.com/Cliftonz/terraform-provider-posthog`, which only makes the
provider constructor importable. The fork is dropped once upstream exposes the
constructor.

## License

[MPL-2.0](LICENSE)
