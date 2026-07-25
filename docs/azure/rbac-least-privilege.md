---
title: RBAC and least privilege
description: Roles, scopes, role assignments, and how to give the pipeline exactly enough power.
---

# RBAC and least privilege

Authentication answers "who are you." **Authorization** answers "what may you do," and in Azure that is the job of **role-based access control** (RBAC). One sentence holds the whole model:

> A **role assignment** grants a **security principal** a **role** at a **scope**.

All four words are load-bearing.

- The **security principal** is a user, service principal or managed identity (previous page).
- The **role** is a named bundle of permitted operations.
- The **scope** is where it applies: management group, subscription, resource group, or a single resource. Assignments are inherited by everything beneath their scope.

## The roles this course touches

Azure ships hundreds of built-in roles. The docs sort them into **privileged administrator roles** (broad control-plane power) and **job function roles** (scoped to a task). You need exactly four:

| Role | Kind | What it grants | Used here for |
|---|---|---|---|
| **Contributor** | Privileged | Create, change and delete resources; cannot grant roles to others | The pipeline identity, scoped to one resource group |
| **Reader** | Job function | View everything, change nothing | Exploring safely; audit-style access |
| **Storage Blob Data Contributor** | Job function | Read, write and delete blob **data** (not the account itself) | The pipeline reading and writing OpenTofu state |
| **Owner** | Privileged | Everything, including granting roles | Only you, the human, on your own subscription |

Storage Blob Data Contributor illustrates a subtlety worth pausing on: Azure separates the **control plane** (managing a storage account: Contributor territory) from the **data plane** (reading and writing the bytes inside it). Contributor on a storage account does not by itself grant data access through Entra ID. The state backend in Module 4 authenticates to the data plane with Entra ID, which is why the pipeline needs this dedicated data role.

## Assigning a role

The CLI shape, using a resource group scope:

```bash
az role assignment create \
  --assignee "someone@example.com" \
  --role "Reader" \
  --scope "/subscriptions/SUB-ID/resourceGroups/rg-example"
```

Scopes are path-like strings: a subscription is `/subscriptions/SUB-ID`, a resource group appends `/resourceGroups/NAME`, a single resource appends its full resource path. The narrower the path, the smaller the blast radius.

When the assignee is a **freshly created service principal or managed identity**, use this stricter form:

```bash
az role assignment create \
  --assignee-object-id "PRINCIPAL-OBJECT-ID" \
  --assignee-principal-type "ServicePrincipal" \
  --role "b24988ac-6180-42a0-ab88-20f7382dd24c" \
  --scope "/subscriptions/SUB-ID/resourceGroups/rg-example"
```

Three deliberate choices in there, all from the official guidance:

1. **Object ID, not name or app ID.** A brand-new principal takes time to replicate through the directory; assigning by name can fail or, worse, bind the wrong object. The object ID with an explicit principal type avoids the lookup entirely.
2. **Role ID instead of role name.** `b24988ac-6180-42a0-ab88-20f7382dd24c` is Contributor's immutable ID. Names are display strings; scripts should use IDs.
3. **Resource group scope, not subscription.** The pipeline will manage one resource group. It gets power over that group and nothing else.

The role IDs used in this course, so you never have to hunt for them:

| Role | ID |
|---|---|
| Contributor | `b24988ac-6180-42a0-ab88-20f7382dd24c` |
| Reader | `acdd72a7-3385-48ef-bd42-f606fba81ae7` |
| Storage Blob Data Contributor | `ba92f5b4-2d11-453d-a403-e96b0029c9fe` |

## Least privilege, concretely

The official guidance says it twice in one page: grant the least privilege needed, and avoid broader **scope** just as much as broader **role**. For this course's pipeline that resolves to a precise recipe, which Module 5 implements:

- **Contributor** on `rg-capstone-prod` only. The pipeline can build and destroy the capstone environment. It cannot see other resource groups, cannot touch the subscription, and crucially **cannot change role assignments**, so a compromised pipeline cannot promote itself.
- **Storage Blob Data Contributor** on the state storage account only. It can read and write state blobs, nothing else.
- Nothing at subscription scope. Ever.

:::tip[Test your model]

A colleague proposes giving the pipeline Owner at subscription scope "so we never hit a permissions error again." What are the two distinct escalations you would be accepting? (Answers: every resource in every group becomes writable, and the pipeline gains the power to grant roles, meaning any compromise becomes permanent and subscription-wide.) If you can articulate that, this page did its job.

:::

Next: get your own subscription and try all of it.
