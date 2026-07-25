---
title: Identity and the resource hierarchy
description: Tenants, subscriptions, resource groups, and the identities that act on them.
---

# Identity and the resource hierarchy

Azure has two worlds that beginners constantly conflate: the world of **identities** (who can act) and the world of **resources** (what exists and gets billed). They are linked but distinct, and the pipeline touches both. Get this page solid and Module 5 will feel obvious instead of magical.

![Azure identity hierarchy: a Microsoft Entra tenant holds identities, subscriptions trust the tenant, resource groups live in subscriptions, resources live in resource groups](/img/diagrams/azure-identity-hierarchy.svg)

## The identity world: Microsoft Entra ID

**Microsoft Entra ID** is Azure's identity service. You will find older material calling it Azure Active Directory or Azure AD; same product, renamed. Current documentation never says Azure AD, and neither does this course.

A **tenant** is one instance of that directory: a container of identities. When your organisation signed up, it got a tenant; when you create a personal Azure account in the lab, you get your own. Everything that can authenticate lives in a tenant as some kind of **security principal**:

- **Users**: people who sign in interactively.
- **Service principals**: identities for software. Created from an **app registration** (the definition of an application) which gets a service principal (the identity that acts) in the tenant. Historically these authenticated with client secrets, which is precisely what this course refuses to do.
- **Managed identities**: identities whose credentials Azure manages entirely; there is nothing to leak, rotate or store. A **user-assigned managed identity** is a standalone Azure resource you create and can attach to things, and, importantly for us, it can be trusted directly by external systems through federation. (A **system-assigned** managed identity is bolted to a single resource and dies with it; it cannot be used for the federation we need.)

The pipeline you build will authenticate as a user-assigned managed identity. Module 5 explains exactly why it beats an app registration for this job, and shows both.

## The resource world: subscriptions and resource groups

A **subscription** is Azure's unit of billing and access boundary. Every resource belongs to exactly one subscription. The official docs put the relationship precisely: all Azure subscriptions have a trust relationship with a Microsoft Entra tenant; a subscription trusts exactly one tenant, while one tenant may be trusted by many subscriptions. In short: **the tenant holds identities, the subscription holds resources**.

A **resource group** is a container inside a subscription. Every resource lives in exactly one resource group. Groups are free, creating and deleting them costs nothing, and deleting a group deletes everything inside it, which makes them ideal blast-radius containers and ideal teardown levers. The capstone leans on both properties.

Above subscriptions sit **management groups**, used by organisations to apply policy and access across many subscriptions at once (up to six levels of nesting, with a root group per tenant). You will not need them in this course; know they exist so the diagram in your head is complete, and so nothing surprises you in a corporate environment.

The scopes nest, and access flows downward:

```text
Management group  >  Subscription  >  Resource group  >  Resource
```

A permission granted at a scope is inherited by everything below it. This inheritance is the mechanism behind the least-privilege choices on the next page.

## How a human signs in

The Azure CLI from Lab 1 authenticates you like this:

```bash
az login
```

A browser opens, you sign in (multi-factor authentication is **mandatory for user identities** since late 2025; have your phone ready), and the CLI shows the subscriptions your identity can see and asks you to pick a default. Two commands manage that context afterwards:

```bash
az account show                     # which subscription am I pointed at?
az account set --subscription "My Subscription Name or ID"
```

:::warning[Humans log in interactively. Software does not.]

The MFA mandate killed username-and-password sign-ins for scripts, and that is a feature. Any automation, including your pipeline, must use a **workload identity**: a service principal or managed identity. When Module 5 wires GitHub to Azure, GitHub's runner will authenticate as your managed identity through OIDC federation, with MFA-grade assurances and no password anywhere.

:::

Next: what an identity is allowed to do once Azure knows who it is.
