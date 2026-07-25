---
title: Remote state in Azure Storage
description: Shared state with automatic locking, authenticated with Entra ID instead of storage keys.
---

# Remote state in Azure Storage

A **backend** tells OpenTofu where state lives. The `azurerm` backend stores it as a blob in an Azure Storage container, which buys three things at once: the state survives your laptop, the pipeline and every teammate read the same truth, and Azure Blob Storage provides **locking** for free.

![State locking with Azure blob leases: run A acquires the lease on the state blob, run B must wait](/img/diagrams/state-locking.svg)

The locking mechanism is a **blob lease**, Azure's native exclusive-access primitive. Before any operation that writes state, OpenTofu acquires a lease on the state blob; a second run arriving mid-operation cannot acquire it and waits or fails with a clear lock error instead of corrupting anything. No extra infrastructure, no lock table; the storage account you already need does it all. Encryption at rest is likewise automatic on Azure Storage.

## The chicken-and-egg resource

State storage is the one piece of infrastructure that cannot manage itself: OpenTofu needs it to exist before OpenTofu can do anything. The clean answer is to create it **once, by hand**, and regard it as pre-infrastructure. Lab 4 does exactly this and the capstone reuses it.

```bash
# One-time state backend setup. Pick your own globally unique
# storage account name: lowercase letters and digits, 3 to 24 chars.
STATE_RG=rg-tofu-state
STATE_SA=sttofustate$RANDOM$RANDOM     # e.g. sttofustate2841722913
LOCATION=westeurope

az group create --name $STATE_RG --location $LOCATION

az storage account create \
  --resource-group $STATE_RG \
  --name $STATE_SA \
  --sku Standard_LRS \
  --encryption-services blob

az storage container create \
  --name tfstate \
  --account-name $STATE_SA
```

:::warning[Money]

This storage account holds a few kilobytes and costs at most a few cents per month at Standard_LRS. It is the only resource in the course that stays alive between modules.

:::

## No storage keys, on principle

Every Azure storage account is born with two **account access keys**: long-lived symmetric secrets granting full data access. They are exactly the kind of credential this course forbids, and Microsoft's own guidance is unambiguous: Entra ID authorization is recommended over shared keys. So we do two things.

First, grant your own user the data-plane role on the account (control-plane ownership does not imply data access, as Module 3 explained):

```bash
SUB_ID=$(az account show --query id --output tsv)
ME=$(az ad signed-in-user show --query id --output tsv)

az role assignment create \
  --assignee-object-id $ME \
  --assignee-principal-type "User" \
  --role "ba92f5b4-2d11-453d-a403-e96b0029c9fe" \
  --scope "/subscriptions/$SUB_ID/resourceGroups/$STATE_RG/providers/Microsoft.Storage/storageAccounts/$STATE_SA"
```

Then disable the keys entirely, so nothing can ever use them:

```bash
az storage account update \
  --name $STATE_SA \
  --resource-group $STATE_RG \
  --allow-shared-key-access false
```

From this moment the account only accepts Entra ID identities that hold a data role. Give the role assignment a few minutes to propagate before the first use.

## Pointing OpenTofu at it

```hcl
# backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tofu-state"
    storage_account_name = "sttofustate2841722913"  # your unique name
    container_name       = "tfstate"
    key                  = "lab4.tfstate"           # the blob's name
    use_azuread_auth     = true
  }
}
```

`use_azuread_auth = true` is the line that honours the key shutdown: state reads and writes go through Entra ID. Locally that means your Azure CLI login; in the pipeline it will mean the OIDC-federated identity (the backend accepts `use_oidc = true` and picks up the GitHub token automatically, as Module 5 shows). The `key` is simply the blob name, so one container can hold state for many configurations.

Adding a backend is a change to state storage, so it takes an `init`:

```bash
tofu init
```

If a local `terraform.tfstate` already exists, OpenTofu detects it and asks whether to **migrate** the existing state into the new backend; answer yes and it copies your state up to the blob. Afterwards, delete the stale local file and confirm the world still makes sense with `tofu state list` and a `tofu plan` that reports no changes.

:::note[Keep the account name out of your head]

Backend blocks cannot be parameterised freely, but OpenTofu (unlike Terraform) does allow variables and locals in backend configuration as long as they resolve at init time, and both tools accept **partial configuration**: leave arguments out of the block and supply them at init with `-backend-config="storage_account_name=..."`. The capstone uses the simple fully-written form for clarity; know the flexible forms exist for real codebases with several environments.

:::

## One more OpenTofu exclusive: state encryption

Even with tight access control, defense in depth argues for encrypting state contents themselves. OpenTofu (and not Terraform) can encrypt state and plan files client-side, so the blob at rest is ciphertext even to someone who obtains it. Module 6 shows the configuration; it is a few lines with a passphrase-derived key. Nothing about the backend above needs to change.

Now put all of it together with your own hands.
