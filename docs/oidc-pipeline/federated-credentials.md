---
title: Identities and federated credentials
description: Create the pipeline's Azure identities and the trust rules that let GitHub use them.
---

# Identities and federated credentials

Azure offers two identity types that can hold federated credentials, and the official documentation presents them as equals for this scenario:

- A **user-assigned managed identity** (UAMI): a plain Azure resource. Creating one and attaching federated credentials requires only ordinary Azure permissions (Owner or Contributor where it lives), and there is no secret material at any point in its lifecycle.
- An **app registration with a service principal**: the classic route. It works identically at runtime, but creating and managing it requires Microsoft Entra **directory** roles (Application Administrator or similar), which in most organisations means a ticket to another team, and it leaves an app object in the directory to govern.

This course uses managed identities: fewer moving parts, no directory-level permissions, nothing to leak. (One boundary to know: only *user-assigned* managed identities support federated credentials; the system-assigned kind does not.)

## Two identities, on purpose

The pipeline gets **two** identities, not one, and the split *is* the security design:

| Identity | Trusted for | Azure roles |
|---|---|---|
| `id-tofu-plan` | Pull request jobs (`repo:ORG/REPO:pull_request`) | **Reader** on the target resource group, **Storage Blob Data Contributor** on the state account |
| `id-tofu-apply` | Jobs in the `prod` environment (`repo:ORG/REPO:environment:prod`) | **Contributor** on the target resource group, **Storage Blob Data Contributor** on the state account |

Follow the consequence through: any pull request in the repository can trigger a plan, so the plan identity must be safe to hand to any pull request. With Reader it can refresh and diff, and with the state data role it can read state and take the lock, but it **cannot change infrastructure**. The apply identity can, and Entra ID will only issue it to a job that GitHub attests is running in the `prod` environment, which the next page gates behind human approval. "PR runs hold no apply rights" is enforced by Azure, not by workflow etiquette.

(Both identities need the state data role because even a plan must read state and acquire the lock lease. Yes, that means a hostile pull request could vandalise state blobs. Weigh that against the alternative it replaces, a stored credential that could vandalise the infrastructure itself, and note that fork pull requests do not receive your secrets at all, so outside attackers do not even reach the exchange.)

## Creating a managed identity

```bash
# One-time setup, run by you. The identities live in the same
# resource group as the state account: persistent platform pieces together.
az identity create \
  --name id-tofu-plan \
  --resource-group rg-tofu-state \
  --location westeurope
```

Each identity has two IDs you will use, retrievable at any time:

```bash
az identity show --name id-tofu-plan --resource-group rg-tofu-state \
  --query "{clientId: clientId, principalId: principalId}"
```

- **`clientId`** goes into GitHub secrets; it is who the workflow asks to become.
- **`principalId`** is the object ID used for role assignments (with `--assignee-object-id`, as Module 3 taught).

## Attaching a federated credential

```bash
az identity federated-credential create \
  --name github-pull-request \
  --identity-name id-tofu-plan \
  --resource-group rg-tofu-state \
  --issuer 'https://token.actions.githubusercontent.com' \
  --subject 'repo:ORG/REPO:pull_request' \
  --audiences 'api://AzureADTokenExchange'
```

Replace `ORG/REPO` with the exact repository path, matching case. The three matched fields are all here: issuer (always the same for GitHub Actions), subject (the identity statement from the previous page), audience (the conventional exchange value). The same command with `--subject 'repo:ORG/REPO:environment:prod'` on `id-tofu-apply` creates the apply-side trust.

The rules that govern these, straight from the documentation and worth internalising: an identity holds at most **20** federated credentials, each issuer-and-subject pair must be unique on that identity, **no wildcards** are allowed in any field, and matching is exact or the exchange silently fails.

If you prefer the portal: on the managed identity, Settings, then Federated credentials, then Add Credential; the scenario dropdown "GitHub Actions deploying Azure resources" asks for organisation, repository and entity type (environment, branch, tag or pull request) and composes the subject string for you. Worth doing once just to see the subject assembled from parts.

## The app registration route, for completeness

You will meet this pattern in existing organisations, so here is its shape; the runtime behaviour is identical.

```bash
az ad app create --display-name tofu-pipeline        # note the appId in the output
az ad sp create --id APP-ID                          # give it a service principal

az ad app federated-credential create --id APP-ID --parameters '{
    "name": "github-prod-environment",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:ORG/REPO:environment:prod",
    "description": "Apply from the prod environment",
    "audiences": ["api://AzureADTokenExchange"]
}'
```

The `appId` plays the client ID role, and role assignments target the service principal's object ID. Everything else on this page applies unchanged.

## What GitHub stores

Three repository secrets carry the identifiers (Settings, then Secrets and variables, then Actions):

| Secret | Value |
|---|---|
| `AZURE_TENANT_ID` | `az account show --query tenantId --output tsv` |
| `AZURE_SUBSCRIPTION_ID` | `az account show --query id --output tsv` |
| `AZURE_CLIENT_ID_PLAN` | the plan identity's `clientId` |
| `AZURE_CLIENT_ID_APPLY` | the apply identity's `clientId` |

Say it once more, because it is the point of the whole module: these are identifiers. The table above contains **no credential**. There is nothing here to rotate, and nothing whose theft alone grants access.

Next: the workflows that put these identities to work.
