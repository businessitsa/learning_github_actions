---
title: 'Lab 5: build the pipeline'
description: Wire identities, federated credentials, environments and workflows into a working deployment pipeline.
---

# Lab 5: build the pipeline

Time: about 90 minutes. Cost: cents (one storage account, plus the state account you already have). Requires: Labs 3 and 4 completed, the `rg-tofu-state` backend alive, your course repository from Lab 2.

Everything below stays alive through Module 6, which hardens it. Teardown comes at the end of that module.

Set some shell variables once; every command below uses them. Replace the placeholders with your values:

```bash
GH_REPO="YOUR-USERNAME/tofu-azure-course"     # exact path, matching case
STATE_SA="YOUR-STATE-ACCOUNT-NAME"            # from Lab 4
SUB_ID=$(az account show --query id --output tsv)
LOCATION=westeurope
```

## 1. Create the target resource group

The pipeline's power will be scoped to this group, and a scope must exist before a role can be assigned on it, so it is created by hand, once:

```bash
az group create --name rg-pipeline-lab --location $LOCATION
```

## 2. Create the two identities and their trust rules

```bash
# The plan identity: trusted by pull request jobs
az identity create --name id-tofu-plan --resource-group rg-tofu-state --location $LOCATION

az identity federated-credential create \
  --name github-pull-request \
  --identity-name id-tofu-plan \
  --resource-group rg-tofu-state \
  --issuer 'https://token.actions.githubusercontent.com' \
  --subject "repo:${GH_REPO}:pull_request" \
  --audiences 'api://AzureADTokenExchange'

# The apply identity: trusted only by jobs in the prod environment
az identity create --name id-tofu-apply --resource-group rg-tofu-state --location $LOCATION

az identity federated-credential create \
  --name github-environment-prod \
  --identity-name id-tofu-apply \
  --resource-group rg-tofu-state \
  --issuer 'https://token.actions.githubusercontent.com' \
  --subject "repo:${GH_REPO}:environment:prod" \
  --audiences 'api://AzureADTokenExchange'
```

## 3. Grant exactly enough power

```bash
PLAN_OID=$(az identity show --name id-tofu-plan --resource-group rg-tofu-state --query principalId --output tsv)
APPLY_OID=$(az identity show --name id-tofu-apply --resource-group rg-tofu-state --query principalId --output tsv)
STATE_SCOPE="/subscriptions/$SUB_ID/resourceGroups/rg-tofu-state/providers/Microsoft.Storage/storageAccounts/$STATE_SA"
TARGET_SCOPE="/subscriptions/$SUB_ID/resourceGroups/rg-pipeline-lab"

# Plan identity: Reader on the target, state data access
az role assignment create --assignee-object-id $PLAN_OID \
  --assignee-principal-type "ServicePrincipal" \
  --role "acdd72a7-3385-48ef-bd42-f606fba81ae7" --scope $TARGET_SCOPE

az role assignment create --assignee-object-id $PLAN_OID \
  --assignee-principal-type "ServicePrincipal" \
  --role "ba92f5b4-2d11-453d-a403-e96b0029c9fe" --scope $STATE_SCOPE

# Apply identity: Contributor on the target, state data access
az role assignment create --assignee-object-id $APPLY_OID \
  --assignee-principal-type "ServicePrincipal" \
  --role "b24988ac-6180-42a0-ab88-20f7382dd24c" --scope $TARGET_SCOPE

az role assignment create --assignee-object-id $APPLY_OID \
  --assignee-principal-type "ServicePrincipal" \
  --role "ba92f5b4-2d11-453d-a403-e96b0029c9fe" --scope $STATE_SCOPE
```

Every choice here was explained in Module 3: object IDs with explicit principal type, role IDs not names, and the narrowest workable scope.

## 4. Store the identifiers in GitHub

In your repository: Settings, then Secrets and variables, then Actions, then New repository secret, four times:

| Secret name | Value from |
|---|---|
| `AZURE_TENANT_ID` | `az account show --query tenantId --output tsv` |
| `AZURE_SUBSCRIPTION_ID` | `echo $SUB_ID` |
| `AZURE_CLIENT_ID_PLAN` | `az identity show --name id-tofu-plan --resource-group rg-tofu-state --query clientId --output tsv` |
| `AZURE_CLIENT_ID_APPLY` | `az identity show --name id-tofu-apply --resource-group rg-tofu-state --query clientId --output tsv` |

## 5. Create the gated environment

Settings, then Environments, then New environment. Name it exactly `prod` (the federated credential's subject says `environment:prod`; case matters). Inside it, enable **Required reviewers**, add yourself, save. Approving your own deployments is fine while learning solo; a real team would also tick "prevent self-review".

## 6. Add the infrastructure and the workflows

The pipeline needs something to manage. A storage account keeps it cheap and real:

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
    key                  = "pipeline.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}
}

# The resource group is created and owned outside the pipeline;
# the pipeline reads it and manages its contents.
data "azurerm_resource_group" "target" {
  name = "rg-pipeline-lab"
}

resource "random_string" "suffix" {
  length  = 8
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_storage_account" "demo" {
  name                     = "stpipe${random_string.suffix.result}"
  resource_group_name      = data.azurerm_resource_group.target.name
  location                 = data.azurerm_resource_group.target.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # No key-based access here either; this course means it.
  shared_access_key_enabled = false

  tags = {
    course     = "tofu-azure"
    managed_by = "opentofu"
  }
}
```

Then create `.github/workflows/tofu-plan.yml` and `.github/workflows/tofu-apply.yml` exactly as printed on the [previous page](plan-and-apply-workflows).

## 7. Run the whole flow

```bash
git checkout -b add-pipeline
git add infra .github/workflows
git commit -m "Add OIDC deployment pipeline"
git push --set-upstream origin add-pipeline
```

Open a pull request on GitHub. Then, in order:

1. **Watch the Plan check appear on the PR.** Open the run, read the job summary: your storage account, `+` prefixed, `Plan: 2 to add`. This job authenticated to Azure with no stored credential; let that land.
2. **Merge the pull request.**
3. **Watch the Apply workflow start and stop.** It shows "Waiting for review" at the `prod` gate. This is the moment the whole design protects.
4. **Approve it** (Review deployments, tick prod, approve). The job resumes, becomes the apply identity, and applies.
5. **Verify reality:**

```bash
az storage account list --resource-group rg-pipeline-lab --output table
```

Take one more minute and try to break the fence: run the Plan workflow's identity test by opening a second PR that changes a tag, and confirm the plan job succeeds while holding no write power (the run log shows the plan; nothing changed in Azure until merge and approval).

## Checklist

You can now:

- [ ] Create a managed identity and attach a federated credential with the CLI.
- [ ] Recite the three matched fields of a federated credential and the two subject formats this pipeline uses.
- [ ] Explain why plan and apply use different identities, and what each can and cannot do.
- [ ] Configure a gated environment and connect it to an OIDC subject.
- [ ] Read a plan from a PR run summary and follow a change through merge, gate, apply and verification.

## Common failure modes

**Entra error: no matching federated identity record found (AADSTS70021 or similar).**
The subject GitHub sent does not exactly match any federated credential on the client ID you supplied. Compare `repo:ORG/REPO:pull_request` or `repo:ORG/REPO:environment:prod` against your repository path (case!), the environment name (case!), and which secret the workflow used. Renamed the repository? Every subject just broke; update the credentials.

**Error fetching the OIDC token: `ACTIONS_ID_TOKEN_REQUEST_URL` missing or empty.**
The job lacks `permissions: id-token: write`. Remember the permissions rule: specifying any permission zeroes the rest, so a workflow that added `permissions: contents: read` alone has switched the token request off.

**Plan succeeds, apply fails with 403 on Azure resources.**
The apply workflow is using the plan identity's client ID (check the secret name in the `env` block), or Contributor was assigned to the wrong object ID or scope. `az role assignment list --resource-group rg-pipeline-lab --output table` shows the truth.

**403 on state access from either workflow.**
Storage Blob Data Contributor missing for that identity, or not yet propagated (minutes, occasionally longer). Same checklist as Lab 4's version of this failure.

**A plan-time authorization error mentioning `listKeys`.**
Some provider resources try to fetch data-plane keys while refreshing, which Reader does not permit. The storage account above avoids this by disabling shared keys entirely. If you add resource types later that insist on key retrieval, decide deliberately: grant the plan identity that specific action, or configure the resource to stop using keys.

**The Apply workflow never asks for approval and just runs.**
The job is missing `environment: prod`, or the environment exists but has no required reviewers. If the job runs *without* the environment, its OIDC subject will not match the apply credential and Azure will refuse it; two symptoms, one root cause.

**Nothing triggers at all.**
The `paths: ['infra/**']` filter only matches changes under `infra/`. A PR touching only workflow files does not plan; that is by design.

Module 5 done. The pipeline exists. Now make it hard to abuse.
