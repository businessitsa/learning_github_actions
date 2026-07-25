---
title: What infrastructure as code is
description: Why describing infrastructure in files beats clicking in portals, and what declarative means.
---

# What infrastructure as code is

Infrastructure as code (IaC) means defining your servers, networks, storage and access rules in text files, and letting a tool make the real world match those files. The files live in version control next to your application code. The infrastructure becomes something you can read, review, diff and roll back.

## The problem with clicking

Suppose you build a small environment by hand in the Azure portal: a resource group, a virtual network, a storage account, a web app. It works. Six months later:

- Nobody remembers which settings were changed from the defaults, or why.
- Reproducing the environment for a test system means clicking through the same forms and hoping you remember every checkbox.
- An intern "fixes" something on a Friday. There is no record of what changed.
- The security team asks "who can access this storage account and why?" and the honest answer is archaeology.

Hand-built environments are sometimes called **snowflakes**: each one unique, none reproducible. IaC removes the snowflake problem by making a text description the single source of truth.

## Imperative versus declarative

There are two ways to automate infrastructure, and the difference matters more than any tool choice.

An **imperative** approach lists steps to execute. A shell script using the Azure CLI is imperative:

```bash
# create-environment.sh (imperative: a list of steps)
az group create --name rg-demo --location westeurope
az storage account create \
  --resource-group rg-demo \
  --name stdemo482913 \
  --sku Standard_LRS
```

Run it once and it works. Run it twice and the second run may fail because the resources already exist. If someone deleted the storage account but not the resource group, the script has no idea; it just replays its steps. The script describes **how** to get somewhere, not **where** you want to be.

A **declarative** approach describes the desired end state and lets the tool work out the steps. The same environment in OpenTofu's configuration language looks like this:

```hcl
# main.tf (declarative: a description of the end state)
resource "azurerm_resource_group" "demo" {
  name     = "rg-demo"
  location = "westeurope"
}

resource "azurerm_storage_account" "demo" {
  name                     = "stdemo482913"
  resource_group_name      = azurerm_resource_group.demo.name
  location                 = azurerm_resource_group.demo.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
```

Do not worry about the syntax yet; Module 4 covers it properly. The point is what happens when you run the tool:

- If nothing exists, it creates both resources.
- If everything exists and matches, it does nothing.
- If the storage account was deleted by hand, it recreates just the storage account.
- If someone changed the replication type in the portal, it reports the difference and offers to change it back.

The same description handles all four situations. That property, "running it again is always safe and always converges on the described state," is called **idempotency**, and it is the single biggest practical win of declarative IaC.

## What you get from IaC in practice

**Review before change.** Infrastructure changes become pull requests. A colleague sees exactly what will change before it changes. In this course, the tool even posts a preview (a **plan**) of the exact resources it would create, modify or destroy.

**History and rollback.** Git records who changed what and when. Rolling back a bad change is reverting a commit.

**Reproducibility.** Need a second environment? Apply the same files with different parameters. Disaster recovery, test environments and onboarding all stop being heroics.

**Drift detection.** **Drift** is the gap that appears when reality is changed outside the code, for example by a well-meaning portal edit. A declarative tool can compare the description against reality on a schedule and report any gap. Module 6 sets this up.

## The catch: something has to remember

A declarative tool needs to know what it created last time, so it can tell the difference between "this resource needs creating" and "this resource exists and is fine." OpenTofu records this in a **state file**: a catalog of every resource it manages and the settings it last saw.

State introduces two engineering problems that this course treats as first-class topics:

1. State must be **shared and locked** when a team (or an automated pipeline) works on the same infrastructure, otherwise two simultaneous runs can corrupt it. Module 4 solves this with Azure Storage and blob leases.
2. State can contain **sensitive values** and must be protected accordingly. Module 6 covers this.

:::note[Jargon check]

New terms so far: **IaC** (infrastructure defined in versioned text files), **imperative** (describe the steps), **declarative** (describe the end state), **idempotency** (safe to run repeatedly), **drift** (reality diverging from the code), **plan** (a preview of changes), **state** (the tool's record of what it manages).

If all seven make sense, you have the mental model the rest of the course builds on.

:::

Next: [how GitHub, Actions, OpenTofu and Azure divide the work](how-the-tools-fit).
