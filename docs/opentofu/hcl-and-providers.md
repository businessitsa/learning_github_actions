---
title: HCL, providers and variables
description: The configuration language, the plugin model, and parameterising your code.
---

# HCL, providers and variables

OpenTofu configurations are written in **HCL** (HashiCorp Configuration Language): a declarative language built from **blocks** and **arguments**. You saw a taste in Module 1; now the real tour.

## A complete minimal configuration

```hcl
# main.tf
terraform {
  required_version = ">= 1.12.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-tofu-lab"
  location = "westeurope"

  tags = {
    course = "tofu-azure"
  }
}
```

Everything OpenTofu reads is a file ending in `.tf` in the current directory. OpenTofu merges all of them, so splitting code across `main.tf`, `variables.tf` and `outputs.tf` is convention, not requirement. Keep the extension `.tf`: some ecosystem tools (the linter in Module 6 among them) do not parse OpenTofu's alternative `.tofu` extension.

## Block by block

**`terraform {}`** configures OpenTofu itself. Yes, the block is still called `terraform`; it is kept for compatibility with the vast existing ecosystem, and this course uses it for exactly that reason. (OpenTofu 1.12 introduced an equivalent `language {}` block as the forward-looking name; fine to adopt once the ecosystem catches up.) Inside it:

- `required_version` constrains which OpenTofu versions may run this code. Version constraints use operators like `>=` and `~>`; `~> 4.0` means "any 4.x, but not 5.0", the **pessimistic constraint** you will see everywhere.
- `required_providers` declares the plugins this configuration needs.

**`provider` blocks** configure those plugins. A **provider** is the translation layer between HCL and one particular API; `azurerm` speaks to Azure Resource Manager. OpenTofu downloads providers from its own registry at `registry.opentofu.org`. The address `hashicorp/azurerm` works unchanged: the OpenTofu registry serves the same provider code under both the `hashicorp/` and `opentofu/` namespaces.

Two azurerm-specific facts that trip up everyone on 4.x:

1. `features {}` is **mandatory**, even empty. It exists to hold opt-in behaviour flags; its absence is a hard error.
2. The provider must know your **subscription ID** for plan and apply. You can write `subscription_id = "..."` in the provider block, but hard-coding it makes code less portable; the course supplies it through the environment variable `ARM_SUBSCRIPTION_ID` instead.

With no explicit credentials configured, the provider walks a chain of authentication methods; on your workstation it lands on your **Azure CLI login**, which is exactly right for local work. In the pipeline it will land on OIDC. Same code, different ambient identity; that is the design working as intended.

**`resource` blocks** declare a thing that should exist: `resource "TYPE" "LOCAL-NAME" { ... }`. The local name (`lab` above) is how other code refers to it; it is not the Azure name. References look like `azurerm_resource_group.lab.name`, and OpenTofu builds its dependency graph from those references automatically: whatever a resource refers to gets created first.

**`data` blocks** (not shown) read existing things you do not manage, for example looking up your current client configuration with `data "azurerm_client_config" "current" {}`.

## Variables: parameterising configurations

Hard-coded strings make code single-use. **Input variables** fix that:

```hcl
# variables.tf
variable "location" {
  type        = string
  description = "Azure region for all resources"
  default     = "westeurope"
}

variable "environment" {
  type        = string
  description = "Deployment environment name"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}
```

Reference them as `var.location`. Types cover `string`, `number`, `bool`, and structured types (`list(...)`, `map(...)`, `object(...)`). A variable without a `default` must be supplied at run time, and `validation` blocks reject bad values before anything touches the cloud.

Values can arrive several ways, applied in this order of precedence (later wins):

1. Environment variables named `TF_VAR_<name>`, for example `TF_VAR_location=westeurope`.
2. A `terraform.tfvars` file, then any `*.auto.tfvars` files.
3. Explicit `-var` and `-var-file` flags on the command line.

:::warning[`sensitive` hides output, not data]

Marking a variable `sensitive = true` redacts it from plan and apply output, which is worth doing. It does **not** encrypt it, and its value still lands in the state file in plain text. State protection is a storage problem, handled two pages from now, plus optional encryption in Module 6. (OpenTofu 1.11+ also has `ephemeral` variables that never touch state at all, useful for passing short-lived tokens.)

:::

## Outputs and locals

**Outputs** publish values from your configuration: the URL of a deployed app, the name of a generated resource. They print after apply and are readable with `tofu output`.

```hcl
# outputs.tf
output "resource_group_name" {
  description = "Name of the lab resource group"
  value       = azurerm_resource_group.lab.name
}
```

**Locals** are named intermediate expressions for readability and reuse within the configuration:

```hcl
# main.tf (fragment illustrating locals; used in the capstone)
locals {
  common_tags = {
    course      = "tofu-azure"
    managed_by  = "opentofu"
    environment = var.environment
  }
}
```

## Modules, in one paragraph

A **module** is a reusable folder of `.tf` files, called with a `module` block and its own variables, from a local path or a registry. Modules are how real codebases stay maintainable, and the public registry offers well-built modules for common Azure patterns. This course deliberately writes raw resources instead, because you are here to learn what the modules would be hiding. Reach for modules in your own work once the raw resources hold no mysteries.

Next: what actually happens when you run the tool.
