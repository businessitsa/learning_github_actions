---
title: 'Lab 4: from zero to remote state'
description: Build real infrastructure locally, watch drift appear, then move state into Azure Storage.
---

# Lab 4: from zero to remote state

Time: about 90 minutes. Cost: a few cents at most, and only the state storage account survives the lab (it is needed for Modules 5 to 7). Requires: Lab 3 completed, `az login` still valid.

You will build a small environment with OpenTofu, inspect and deliberately drift it, then migrate its state into the remote backend you will use for the rest of the course.

## 1. Set up the project

Work inside your course repository from Lab 2, in a new directory:

```bash
cd tofu-azure-course
mkdir infra-lab4 && cd infra-lab4
```

Protect yourself before anything exists. State and plan files must never reach Git:

```text
# .gitignore (repository root; add these lines)
.terraform/
*.tfstate
*.tfstate.*
*.tfplan
crash.log
```

Now the configuration, three files:

```hcl
# infra-lab4/main.tf
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
}

provider "azurerm" {
  features {}
}

# Storage account names must be globally unique across all of Azure,
# lowercase alphanumeric only. A random suffix makes collisions a non-issue.
resource "random_string" "suffix" {
  length  = 8
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-tofu-lab"
  location = var.location

  tags = {
    course  = "tofu-azure"
    purpose = "lab4"
  }
}

resource "azurerm_storage_account" "lab" {
  name                     = "stlab4${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.lab.name
  location                 = azurerm_resource_group.lab.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = azurerm_resource_group.lab.tags
}
```

```hcl
# infra-lab4/variables.tf
variable "location" {
  type        = string
  description = "Azure region for all lab resources"
  default     = "westeurope"
}
```

```hcl
# infra-lab4/outputs.tf
output "storage_account_name" {
  description = "The generated, globally unique storage account name"
  value       = azurerm_storage_account.lab.name
}
```

:::warning[Money]

The storage account is billed by stored data at Standard_LRS rates; empty, it rounds to cents per month, and you destroy it at the end of this lab.

:::

## 2. Initialise and give the provider its subscription

```bash
tofu init
```

Watch what it did: providers downloaded into `.terraform/`, and a `.terraform.lock.hcl` created. Commit the lock file with your code.

The azurerm provider requires a subscription ID. Supply it as an environment variable so the code stays portable:

```bash
# bash / zsh
export ARM_SUBSCRIPTION_ID=$(az account show --query id --output tsv)
```

```powershell
# PowerShell
$env:ARM_SUBSCRIPTION_ID = az account show --query id --output tsv
```

## 3. Plan, read, apply

```bash
tofu validate
tofu plan
```

Read the plan slowly, once in your life, top to bottom. Three resources, all prefixed `+`, ending in `Plan: 3 to add, 0 to change, 0 to destroy.` Note that even `random_string` is a resource: its generated value will be recorded in state so it stays stable across runs.

```bash
tofu apply
```

Type `yes` at the prompt. When it finishes, the output block prints your storage account's generated name. Verify reality independently:

```bash
az storage account list --resource-group rg-tofu-lab --output table
```

## 4. Inspect state, then cause drift

```bash
tofu state list
tofu state show azurerm_storage_account.lab
tofu output storage_account_name
```

Now be the well-meaning colleague who edits infrastructure by hand:

```bash
az group update --name rg-tofu-lab --set tags.purpose=changed-in-portal
```

Ask OpenTofu what it thinks of the world:

```bash
tofu plan
```

The plan shows `~ update in-place` on the resource group, with the tag change from `"changed-in-portal"` back to `"lab4"`. Your code never changed; **drift** did. Run `tofu apply` to reconcile reality back to the code. This tiny loop, detect and correct drift from a declarative source of truth, is the entire operational value proposition of IaC, live in your terminal.

## 5. Create the permanent state backend

Run the backend setup from the [previous page](remote-state-azure), all five commands: resource group `rg-tofu-state`, uniquely named storage account, `tfstate` container, the Storage Blob Data Contributor assignment to yourself, and the shared-key shutdown. Note the storage account name it generated; you need it in the next step and again in Module 5.

Wait a few minutes after the role assignment; data-plane role propagation is not instant.

## 6. Migrate your state

```hcl
# infra-lab4/backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tofu-state"
    storage_account_name = "REPLACE-WITH-YOUR-STATE-ACCOUNT-NAME"
    container_name       = "tfstate"
    key                  = "lab4.tfstate"
    use_azuread_auth     = true
  }
}
```

```bash
tofu init
```

OpenTofu notices state exists locally and a backend was added, and asks whether to copy the existing state into the new backend. Answer `yes`. Then confirm nothing was lost in the move:

```bash
tofu state list        # same three resources
tofu plan              # No changes. Your infrastructure matches the configuration.
rm terraform.tfstate terraform.tfstate.backup
```

Your state now lives in a locked, Entra-authenticated blob. See it:

```bash
az storage blob list \
  --account-name YOUR-STATE-ACCOUNT-NAME \
  --container-name tfstate \
  --auth-mode login \
  --output table
```

## 7. Tear down the lab, keep the backend

```bash
tofu destroy
```

Review the destroy plan (3 to destroy), confirm, and verify with `az group list --output table`. Two things remain, deliberately: the `rg-tofu-state` group with your state account (Modules 5 to 7 need it), and the now-empty `lab4.tfstate` blob recording that OpenTofu manages nothing. Commit your lab code (the `.gitignore` keeps state artifacts out):

```bash
cd .. && git add . && git commit -m "Lab 4: OpenTofu with remote state" && git push
```

## Checklist

You can now:

- [ ] Write a configuration with the `terraform`, `provider`, `resource`, `variable` and `output` blocks from memory.
- [ ] Explain what `tofu init`, `validate`, `plan`, `apply` and `destroy` each do, and what `-out` and `-detailed-exitcode` change.
- [ ] Read a plan and identify create, update, destroy and replace actions.
- [ ] Demonstrate drift and reconcile it.
- [ ] Explain why state exists, why it is sensitive, and why it must not live in Git.
- [ ] Configure the azurerm backend with Entra ID auth and migrate existing state into it.

## Common failure modes

**`subscription_id is a required provider property`** (or similar) on plan.
`ARM_SUBSCRIPTION_ID` is not set in this shell. Environment variables do not survive new terminal windows; re-export it.

**403 or authorization error touching state after step 6.**
Either the Storage Blob Data Contributor assignment has not propagated yet (wait a few minutes), or it is missing, or you skipped `use_azuread_auth = true` so OpenTofu tried key auth against an account with keys disabled. Each produces a slightly different error; all three have the same checklist.

**`Error acquiring the state lock`.**
A previous run died holding the blob lease, or another run is genuinely in progress. If you are certain nothing is running, `tofu force-unlock LOCK-ID` (the error message prints the ID). Never force-unlock when a run might actually be live.

**Storage account name conflict on apply.**
Someone on Earth owns that name. The random suffix makes this rare; rerun apply and `random_string` keeps its value, so if you hit it, shorten your prefix or re-create the `random_string` with `tofu taint random_string.suffix` then apply.

**Plan wants to destroy and recreate (`-/+`) the storage account after an innocent edit.**
You changed a create-only attribute, most commonly `name`. Azure cannot rename storage accounts; OpenTofu can only replace. This is what the `-/+` marker is for: read it as "data inside will be lost" and decide deliberately.

Module 4 done. You can now do everything the pipeline will do, by hand. Time to take your hands off.
