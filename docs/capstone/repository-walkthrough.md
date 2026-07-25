---
title: Repository walkthrough
description: Every file in the capstone repository, and why it looks the way it does.
---

# Repository walkthrough

The layout, then every file. Nothing here is new machinery; the capstone's job is to show all the course's parts composed, so each commentary points back at the module that explains it.

```text
capstone-azure/
├── .github/workflows/
│   ├── tofu-plan.yml      # plan + scanners on every PR       (Modules 5, 6)
│   ├── tofu-apply.yml     # gated apply on merge              (Module 5)
│   ├── tofu-drift.yml     # scheduled drift detection         (Module 6)
│   └── tofu-destroy.yml   # manual, confirmed, gated destroy  (new)
├── infra/
│   ├── main.tf            # versions, backend, provider, target group
│   ├── variables.tf
│   ├── network.tf
│   ├── storage.tf
│   ├── app.tf
│   └── outputs.tf
├── scripts/
│   └── setup-azure.sh     # one-time identity and RBAC setup  (next page)
└── .gitignore
```

## infra/main.tf

```hcl
# infra/main.tf
terraform {
  required_version = ">= 1.12.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-tofu-state"
    storage_account_name = "REPLACE-WITH-YOUR-STATE-ACCOUNT-NAME"
    container_name       = "tfstate"
    key                  = "prod.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}
}

# The resource group is created once by scripts/setup-azure.sh, because the
# pipeline's RBAC is scoped to it and a scope must exist before a role can be
# assigned on it. The pipeline manages everything inside it.
data "azurerm_resource_group" "prod" {
  name = "rg-capstone-prod"
}

locals {
  common_tags = {
    project    = "capstone"
    managed_by = "opentofu"
    repository = var.repository
  }
}
```

Familiar pieces: the version constraints and `features {}` from Module 4, the Entra-authenticated backend from Lab 4 (state key `prod.tfstate`, same container as your lab states), and the `data` block reading the hand-made resource group, which is the scoped-RBAC consequence discussed in Lab 5. The `locals` block defines tags applied to everything, including which repository manages the resource, a small courtesy your future colleagues will thank you for when they find the resource in the portal.

## infra/variables.tf

```hcl
# infra/variables.tf
variable "repository" {
  type        = string
  description = "GitHub repository (ORG/REPO) that manages this environment, recorded as a tag"
  default     = "YOUR-USERNAME/capstone-azure"
}
```

## infra/network.tf

```hcl
# infra/network.tf
resource "azurerm_virtual_network" "capstone" {
  name                = "vnet-capstone"
  resource_group_name = data.azurerm_resource_group.prod.name
  location            = data.azurerm_resource_group.prod.location
  address_space       = ["10.20.0.0/16"]

  tags = local.common_tags
}

# The application subnet. In this course version the container apps
# environment runs on Azure's shared network to stay within the free tier
# (custom VNet integration requires a dedicated /23 subnet and is left as a
# stretch exercise); the network is still real, managed infrastructure that
# the pipeline plans, applies and drift-checks like everything else.
resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = data.azurerm_resource_group.prod.name
  virtual_network_name = azurerm_virtual_network.capstone.name
  address_prefixes     = ["10.20.1.0/24"]
}
```

Names follow the Cloud Adoption Framework conventions from Module 3 (`vnet-`, `snet-` prefixes). The subnet references the VNet by expression, which is also its dependency declaration: OpenTofu orders creation from references, not from file order.

## infra/storage.tf

```hcl
# infra/storage.tf
# Storage account names must be globally unique, lowercase alphanumeric,
# 3 to 24 characters. The random suffix keeps the name collision-free while
# the prefix keeps it recognisable.
resource "random_string" "storage_suffix" {
  length  = 8
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_storage_account" "data" {
  name                     = "stcapstone${random_string.storage_suffix.result}"
  resource_group_name      = data.azurerm_resource_group.prod.name
  location                 = data.azurerm_resource_group.prod.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  # Entra ID only, no shared keys: the same stance as the course's state
  # account, and it also keeps read-only plan refreshes free of key lookups.
  shared_access_key_enabled = false

  tags = local.common_tags
}
```

The random suffix pattern is from Lab 4; the key shutdown is the course's standing policy from Module 4, with the bonus (noted in Lab 5's failure modes) that a keyless account keeps the read-only plan identity's refresh clean.

## infra/app.tf

```hcl
# infra/app.tf
# A consumption-plan Container Apps environment. No Log Analytics workspace
# is attached, deliberately: application logs go nowhere in this teaching
# setup, which keeps it inside the free tier with zero standing cost. In
# production you would attach a workspace here.
resource "azurerm_container_app_environment" "capstone" {
  name                = "cae-capstone-prod"
  resource_group_name = data.azurerm_resource_group.prod.name
  location            = data.azurerm_resource_group.prod.location

  tags = local.common_tags
}

resource "azurerm_container_app" "hello" {
  name                         = "ca-capstone-prod"
  container_app_environment_id = azurerm_container_app_environment.capstone.id
  resource_group_name          = data.azurerm_resource_group.prod.name
  revision_mode                = "Single"

  template {
    # min_replicas = 0 is the cost story: the app scales to zero when idle
    # and consumes nothing from the monthly free grant while asleep.
    min_replicas = 0
    max_replicas = 1

    container {
      name   = "hello"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }

  ingress {
    external_enabled = true
    target_port      = 80

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  tags = local.common_tags
}
```

The only genuinely new resource types in the capstone. A Container Apps **environment** is the compute boundary (think: the cluster you do not manage); the **app** runs Microsoft's public hello-world image with a quarter CPU and half a gigabyte of memory, the smallest standard combination. External ingress gives it a public HTTPS URL on port 443 forwarding to the container's port 80. `min_replicas = 0` with `max_replicas = 1` is both the cost design and the blast-radius cap from the overview.

## infra/outputs.tf

```hcl
# infra/outputs.tf
output "app_url" {
  description = "Public URL of the capstone container app"
  value       = "https://${azurerm_container_app.hello.ingress[0].fqdn}"
}

output "storage_account_name" {
  description = "Generated name of the data storage account"
  value       = azurerm_storage_account.data.name
}

output "virtual_network_id" {
  description = "Resource ID of the capstone virtual network"
  value       = azurerm_virtual_network.capstone.id
}
```

The apply workflow prints these in its run summary, so the app's URL lands in front of the approver the moment the apply finishes.

## The workflows

`tofu-plan.yml`, `tofu-apply.yml` and `tofu-drift.yml` are the hardened versions you built across Modules 5 and 6, with every action SHA-pinned and the scanners in place from the first commit; read them in the repository and confirm you can account for every line. Two small evolutions from the lab versions:

- The `paths:` filters include `.github/workflows/**` as well as `infra/**`, adopting the fix from Lab 6: changes to the pipeline itself deserve a pipeline run.
- The plan workflow's client ID secret is the **capstone** plan identity; the setup script creates fresh identities per repository, because federated credential subjects embed the repository path.

The destroy workflow is new, and its design is the cost-control philosophy made executable:

```yaml
# .github/workflows/tofu-destroy.yml
# Deliberately manual, deliberately awkward: destroying the environment
# requires pressing the button, typing the word destroy, and then approving
# the prod gate. Cost control should be easy; accidents should be hard.
name: Destroy
on:
  workflow_dispatch:
    inputs:
      confirm:
        description: Type destroy to confirm you mean it
        type: string
        required: true

permissions:
  id-token: write
  contents: read

concurrency:
  group: tofu-apply           # shares the apply group: never overlap with an apply
  cancel-in-progress: false

env:
  ARM_USE_OIDC: 'true'
  ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID_APPLY }}
  ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
  ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

defaults:
  run:
    working-directory: infra

jobs:
  destroy:
    runs-on: ubuntu-latest
    if: inputs.confirm == 'destroy'
    environment: prod
    steps:
      - name: Check out the repository
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1

      - name: Install OpenTofu
        uses: opentofu/setup-opentofu@a1320f892987e89d278cc92dc5adc984fb93aca4  # v2.0.2
        with:
          tofu_version: 1.12.5
          tofu_wrapper: false

      - name: Initialise
        run: tofu init

      - name: Plan the destruction
        run: tofu plan -destroy -no-color -out=destroyplan

      - name: Destroy
        run: tofu apply destroyplan

      - name: Publish the result to the run summary
        run: |
          {
            echo '## Destroyed'
            echo 'All managed resources have been removed. State is now empty:'
            echo '```'
            tofu state list || true
            echo '(no resources)'
            echo '```'
          } >> "$GITHUB_STEP_SUMMARY"
```

Three fences stand between a stray click and deleted infrastructure: the typed confirmation checked by the job's `if:`, the `prod` environment gate (a human approves destroys exactly as they approve applies, using the same apply identity and federated credential), and the shared concurrency group so a destroy can never interleave with a running apply. The saved-plan pattern (`plan -destroy -out`, then `apply` the file) is Module 4's two-step discipline pointed in the other direction.

Next: bring it all to life.
