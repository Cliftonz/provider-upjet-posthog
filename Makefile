# ====================================================================================
# Setup Project

PROJECT_NAME ?= provider-posthog
PROJECT_REPO ?= github.com/Cliftonz/provider-upjet-posthog

export TERRAFORM_VERSION ?= 1.5.7

# Do not allow a version of terraform greater than 1.5.x, due to versions 1.6+ being
# licensed under BSL, which is not permitted.
TERRAFORM_VERSION_VALID := $(shell [ "$(TERRAFORM_VERSION)" = "`printf "$(TERRAFORM_VERSION)\n1.6" | sort -V | head -n1`" ] && echo 1 || echo 0)

export TERRAFORM_PROVIDER_SOURCE ?= posthog/posthog
export TERRAFORM_PROVIDER_REPO ?= https://github.com/Cliftonz/terraform-provider-posthog
export TERRAFORM_PROVIDER_VERSION ?= 1.0.25
export TERRAFORM_PROVIDER_REF ?= e708a31f117cf7111e700092ccc734def4b29c25
export TERRAFORM_PROVIDER_MODULE ?= github.com/posthog/terraform-provider
export TERRAFORM_DOCS_PATH ?= docs/resources


PLATFORMS ?= linux_amd64 linux_arm64

-include build/makelib/common.mk

# ====================================================================================
# Setup Output

-include build/makelib/output.mk

# ====================================================================================
# Setup Go

NPROCS ?= 1
GO_TEST_PARALLEL := $(shell echo $$(( $(NPROCS) / 2 )))

GO_REQUIRED_VERSION ?= 1.27
GOLANGCILINT_VERSION ?= 2.14.0
GO_STATIC_PACKAGES = $(GO_PROJECT)/cmd/provider $(GO_PROJECT)/cmd/generator
GO_LDFLAGS += -X $(GO_PROJECT)/internal/version.Version=$(VERSION)
GO_SUBDIRS += cmd internal apis
-include build/makelib/golang.mk

# ====================================================================================
# Setup Kubernetes tools

KIND_VERSION = v0.32.0
CROSSPLANE_CLI_VERSION = v2.2.1
# for e2e testing
CROSSPLANE_VERSION = 2.2.1
-include build/makelib/k8s_tools.mk

# ====================================================================================
# Setup Images

REGISTRY_ORGS ?= xpkg.upbound.io/cliftonz
IMAGES = $(PROJECT_NAME)
-include build/makelib/imagelight.mk

# ====================================================================================
# Setup XPKG

XPKG_REG_ORGS ?= xpkg.upbound.io/cliftonz
XPKG_REG_ORGS_NO_PROMOTE ?= xpkg.upbound.io/cliftonz
XPKGS = $(PROJECT_NAME)
-include build/makelib/xpkg.mk

# ====================================================================================
# Fallthrough

fallthrough: submodules
	@echo Initial setup complete. Running make again . . .
	@make

xpkg.build.provider-posthog: do.build.images

build.init: $(UP) $(CROSSPLANE_CLI) check-terraform-version

# ====================================================================================
# Setup Terraform for fetching provider schema
TERRAFORM := $(TOOLS_HOST_DIR)/terraform-$(TERRAFORM_VERSION)
TERRAFORM_WORKDIR := $(WORK_DIR)/terraform
TERRAFORM_PROVIDER_SCHEMA := config/schema.json

check-terraform-version:
ifneq ($(TERRAFORM_VERSION_VALID),1)
	$(error invalid TERRAFORM_VERSION $(TERRAFORM_VERSION), must be less than 1.6.0 since that version introduced a not permitted BSL license))
endif

$(TERRAFORM): check-terraform-version
	@$(INFO) installing terraform $(HOSTOS)-$(HOSTARCH)
	@mkdir -p $(TOOLS_HOST_DIR)/tmp-terraform
	@curl -fsSL https://releases.hashicorp.com/terraform/$(TERRAFORM_VERSION)/terraform_$(TERRAFORM_VERSION)_$(SAFEHOST_PLATFORM).zip -o $(TOOLS_HOST_DIR)/tmp-terraform/terraform.zip
	@unzip $(TOOLS_HOST_DIR)/tmp-terraform/terraform.zip -d $(TOOLS_HOST_DIR)/tmp-terraform
	@mv $(TOOLS_HOST_DIR)/tmp-terraform/terraform $(TERRAFORM)
	@rm -fr $(TOOLS_HOST_DIR)/tmp-terraform
	@$(OK) installing terraform $(HOSTOS)-$(HOSTARCH)

$(TERRAFORM_PROVIDER_SCHEMA): $(TERRAFORM)
	@$(INFO) generating provider schema for $(TERRAFORM_PROVIDER_SOURCE) $(TERRAFORM_PROVIDER_VERSION)
	@rm -rf $(TERRAFORM_WORKDIR)
	@mkdir -p $(TERRAFORM_WORKDIR)/bin
	@$(GO) build -o $(TERRAFORM_WORKDIR)/bin/terraform-provider-posthog $(TERRAFORM_PROVIDER_MODULE)
	@printf 'provider_installation {\n  dev_overrides {\n    "registry.terraform.io/%s" = "%s"\n  }\n  direct {}\n}\n' "$(TERRAFORM_PROVIDER_SOURCE)" "$(abspath $(TERRAFORM_WORKDIR)/bin)" > $(TERRAFORM_WORKDIR)/terraformrc
	@echo '{"terraform":[{"required_providers":[{"posthog":{"source":"'"$(TERRAFORM_PROVIDER_SOURCE)"'"}}],"required_version":"'"$(TERRAFORM_VERSION)"'"}]}' > $(TERRAFORM_WORKDIR)/main.tf.json
	@TF_CLI_CONFIG_FILE=$(abspath $(TERRAFORM_WORKDIR)/terraformrc) $(TERRAFORM) -chdir=$(TERRAFORM_WORKDIR) providers schema -json=true > $(TERRAFORM_PROVIDER_SCHEMA) 2> $(TERRAFORM_WORKDIR)/terraform-logs.txt
	@$(OK) generating provider schema for $(TERRAFORM_PROVIDER_SOURCE) $(TERRAFORM_PROVIDER_VERSION)

pull-docs:
	@if [ ! -d "$(WORK_DIR)/$(TERRAFORM_PROVIDER_SOURCE)" ]; then \
		mkdir -p "$(WORK_DIR)/$(TERRAFORM_PROVIDER_SOURCE)" && \
		git -C "$(WORK_DIR)/$(TERRAFORM_PROVIDER_SOURCE)" init -q && \
		git -C "$(WORK_DIR)/$(TERRAFORM_PROVIDER_SOURCE)" remote add origin "$(TERRAFORM_PROVIDER_REPO)" && \
		git -C "$(WORK_DIR)/$(TERRAFORM_PROVIDER_SOURCE)" sparse-checkout set "$(TERRAFORM_DOCS_PATH)"; \
	fi
	@git -C "$(WORK_DIR)/$(TERRAFORM_PROVIDER_SOURCE)" fetch -q --depth 1 --filter=blob:none origin "$(TERRAFORM_PROVIDER_REF)"
	@git -C "$(WORK_DIR)/$(TERRAFORM_PROVIDER_SOURCE)" -c advice.detachedHead=false checkout -q FETCH_HEAD

generate.init: $(TERRAFORM_PROVIDER_SCHEMA) pull-docs

.PHONY: $(TERRAFORM_PROVIDER_SCHEMA) pull-docs check-terraform-version
# ====================================================================================
# Targets

submodules:
	@git submodule sync
	@git submodule update --init --recursive

run: go.build
	@$(INFO) Running Crossplane locally out-of-cluster . . .
	$(GO_OUT_DIR)/provider --debug

# ====================================================================================
# End to End Testing
CROSSPLANE_NAMESPACE = crossplane-system
-include build/makelib/local.xpkg.mk
-include build/makelib/controlplane.mk

# uptest v2.2.0 mangles JSON update parameters; the fix is on main but unreleased.
UPTEST_COMMIT = f85cc370e3dab6365919e58a4607584d4b260224
UPTEST := $(TOOLS_HOST_DIR)/uptest-$(UPTEST_COMMIT)
$(UPTEST):
	@$(INFO) installing uptest $(UPTEST_COMMIT)
	@rm -rf $(WORK_DIR)/uptest
	@git clone -q https://github.com/crossplane/uptest $(WORK_DIR)/uptest
	@git -C $(WORK_DIR)/uptest checkout -q $(UPTEST_COMMIT)
	@cd $(WORK_DIR)/uptest && $(GO) build -o $(UPTEST) ./cmd/uptest
	@$(OK) installing uptest $(UPTEST_COMMIT)

# This target requires the following environment variables to be set:
# - UPTEST_EXAMPLE_LIST, a comma-separated list of examples to test
#   To ensure the proper functioning of the end-to-end test resource pre-deletion hook, it is crucial to arrange your resources appropriately.
#   You can check the basic implementation here: https://github.com/crossplane/uptest/blob/main/internal/templates/03-delete.yaml.tmpl.
# - UPTEST_CLOUD_CREDENTIALS, the PostHog credentials JSON that cluster/test/setup.sh stores in the provider Secret.
# - UPTEST_DATASOURCE_PATH (optional), please see https://github.com/crossplane/uptest#injecting-dynamic-values-and-datasource
uptest: $(UPTEST) $(KUBECTL) $(CHAINSAW) $(CROSSPLANE_CLI)
	@$(INFO) running automated tests
	@KUBECTL=$(KUBECTL) CHAINSAW=$(CHAINSAW) CROSSPLANE_CLI=$(CROSSPLANE_CLI) CROSSPLANE_NAMESPACE=$(CROSSPLANE_NAMESPACE) $(UPTEST) e2e "${UPTEST_EXAMPLE_LIST}" --data-source="${UPTEST_DATASOURCE_PATH}" --setup-script=cluster/test/setup.sh --default-conditions="Test" $(UPTEST_ARGS) || $(FAIL)
	@$(OK) running automated tests

local-deploy: build controlplane.up local.xpkg.deploy.provider.$(PROJECT_NAME)
	@$(INFO) running locally built provider
	@$(KUBECTL) wait provider.pkg $(PROJECT_NAME) --for condition=Healthy --timeout 5m
	@$(KUBECTL) -n crossplane-system wait --for=condition=Available deployment --all --timeout=5m
	@$(OK) running locally built provider

e2e: local-deploy uptest

e2e.provider: $(YQ) $(UPTEST) $(CHAINSAW) $(CROSSPLANE_CLI) local.xpkg.deploy.provider.$(PROJECT_NAME)

e2e-local:
	@hack/e2e.sh

.PHONY: submodules fallthrough run e2e.provider e2e-local

# ====================================================================================
# Special Targets

define CROSSPLANE_MAKE_HELP
Crossplane Targets:
    submodules            Update the submodules, such as the common build scripts.
    run                   Run crossplane locally, out-of-cluster. Useful for development.

endef
export CROSSPLANE_MAKE_HELP

crossplane.help:
	@echo "$$CROSSPLANE_MAKE_HELP"

help-special: crossplane.help

.PHONY: crossplane.help help-special

vendor: modules.download
vendor.check: modules.check
