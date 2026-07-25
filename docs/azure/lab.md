---
title: 'Lab 3: your subscription, hands on'
description: Create an Azure account, sign in with the CLI, and exercise resource groups and RBAC.
---

# Lab 3: your subscription, hands on

Time: about 45 minutes. Cost: nothing if you follow the steps (everything created is free, and you delete it at the end). Cloud account: created right now.

## 1. Create an Azure account

Skip this section if you already have a subscription you are allowed to experiment in.

Go to [azure.microsoft.com/free](https://azure.microsoft.com/free) and sign up. As of July 2026 a new account receives **200 US dollars of credit valid for 30 days**, twelve months of popular services free within limits, and a set of always-free services.

:::warning[Money]

A credit or debit card is required for identity verification, with a small temporary authorization that is released. You are **not charged** unless you explicitly upgrade to pay-as-you-go; when the 30 days or the credit run out, the subscription is paused rather than billed. Even so, treat teardown steps in every lab as mandatory habit, because on a pay-as-you-go subscription forgotten resources are the classic way to donate money to Microsoft.

:::

## 2. Sign in and find your bearings

```bash
az login
```

A browser opens; complete the sign-in including MFA. Back in the terminal, the CLI lists your subscriptions and asks you to choose a default. Then orient yourself:

```bash
az account show --output table
```

Note two values you will use throughout the course. Fetch them properly now:

```bash
az account show --query id --output tsv          # your subscription ID
az account show --query tenantId --output tsv    # your tenant ID
```

Save both somewhere convenient. They are identifiers, not secrets, but Module 5 stores them as GitHub secrets anyway.

## 3. Create and inspect a resource group

```bash
az group create \
  --name rg-lab3 \
  --location westeurope \
  --tags course=tofu-azure purpose=lab3
```

Pick a region near you if you prefer; `southafricanorth`, `westeurope` and `eastus2` all work for everything in this course. Whatever you choose, stay consistent within a lab.

List and inspect:

```bash
az group list --output table
az group show --name rg-lab3 --query tags
```

Tags are free-form key-value labels. Organisations lean on them for cost reporting and ownership tracking; the capstone applies them from OpenTofu.

## 4. Look at RBAC from both directions

Who can do what in your new group? First, view the role definition you read about:

```bash
az role definition list --name "Contributor" \
  --query "[0].{name:roleName, id:name, actions:permissions[0].actions}" 
```

Note the `id` field: `b24988ac-6180-42a0-ab88-20f7382dd24c`, matching the table on the previous page, and the `actions` list showing `*` with explicit `notActions` carving out role management.

Now view your own access:

```bash
az role assignment list --all --assignee $(az account show --query user.name --output tsv) --output table
```

On a fresh personal subscription you hold **Owner** at subscription scope, inherited by `rg-lab3` and everything you will ever create. That is fine for a human learning on a personal subscription, and exactly what the pipeline will never get.

## 5. Practice a scoped assignment (read-only, on yourself)

Assigning a role you already exceed changes nothing about your effective power, which makes it a safe way to practice the command shape:

```bash
az role assignment create \
  --assignee $(az account show --query user.name --output tsv) \
  --role "acdd72a7-3385-48ef-bd42-f606fba81ae7" \
  --scope "/subscriptions/$(az account show --query id --output tsv)/resourceGroups/rg-lab3"
```

Confirm it exists, scoped to the group and using the Reader role ID:

```bash
az role assignment list --resource-group rg-lab3 --output table
```

In Module 5 you will run this same command twice with real consequences: Contributor for a managed identity on the capstone group, and Storage Blob Data Contributor on the state storage account.

## 6. Tear down

```bash
az group delete --name rg-lab3 --yes --no-wait
```

Deleting the group removes everything in it, including the practice role assignment scoped to it. Verify:

```bash
az group list --output table
```

The deletion runs asynchronously (`--no-wait`), so the group may linger in the list for a minute or two before disappearing.

## Checklist

You can now:

- [ ] Explain the difference between a tenant and a subscription in one sentence each.
- [ ] Sign in with `az login` and read or switch your active subscription.
- [ ] Retrieve your subscription ID and tenant ID from the CLI.
- [ ] Create, tag, inspect and delete a resource group.
- [ ] Write a role assignment command from memory: principal, role, scope.
- [ ] Say which two role assignments the pipeline identity will receive, and at which scopes.

## Common failure modes

**`az login` loops or fails on MFA.**
User sign-ins require MFA. If your organisation's tenant enforces additional conditional access (device compliance, network location), use a personal account for the course instead of fighting corporate policy.

**Multiple tenants, wrong subscription.**
If your identity exists in several tenants, `az login --tenant TENANT-ID` targets the right one, and `az account set --subscription ...` picks the subscription within it. `az account show` is always the truth of where commands will land.

**`MissingSubscriptionRegistration` when creating a resource.**
Azure activates resource providers per subscription on first use. The Azure CLI registers them automatically but can be slow the first time; rerun the command. You will meet this again in Module 4, where the azurerm provider handles registration itself.

**Role assignment fails with "Cannot find user or service principal".**
Directory replication lag, or the assignee string is not an exact match. For principals you create in scripts, always use `--assignee-object-id` with `--assignee-principal-type`, as the previous page explains.

**The resource group will not delete.**
Some resource types hold locks or take minutes to release. Re-run the delete; check `az group show --name rg-lab3` for provisioning state. Resource **locks** (a deliberate Azure feature) must be removed before deletion succeeds.

Module 3 done. You have a cloud and you understand who may touch it. Now for the tool that will do the touching.
