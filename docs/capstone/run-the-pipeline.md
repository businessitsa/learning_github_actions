---
title: Run the pipeline
description: The capstone runbook, from empty repository to a live, pipeline-managed environment.
---

# Run the pipeline

This is a runbook. Work top to bottom; each step names the module that explains it if anything feels unfamiliar.

## 1. Create the repository

Create a new empty **public** repository named `capstone-azure`, clone it, and copy in the contents of the course's [`capstone/`](https://github.com/businessitsa/learning_github_actions/tree/main/capstone) directory (including the hidden `.github` and `.gitignore`). Do not push yet.

## 2. Personalise three values

1. In `infra/main.tf`, set `storage_account_name` in the backend block to your state account's name (Lab 4).
2. In `infra/variables.tf`, set the default of `repository` to your `YOUR-USERNAME/capstone-azure` path.
3. In `scripts/setup-azure.sh`, set the three values at the top: `GH_REPO`, `STATE_SA`, and your preferred `LOCATION`.

## 3. Run the one-time Azure setup

The script gathers every hand-made step from Modules 3, 5 and 6 into one idempotent, re-runnable file. Read it before running it; it is course review in executable form, and running scripts you have not read is a habit this course declines to teach.

```bash
# scripts/setup-azure.sh
#!/usr/bin/env bash
# One-time Azure setup for the capstone pipeline. Run this as yourself,
# logged in with `az login`, from any bash shell. It is safe to re-run;
# every command either creates or updates the same objects.
set -euo pipefail

# ----- edit these three values ---------------------------------------------
GH_REPO="YOUR-USERNAME/capstone-azure"   # exact GitHub path, matching case
STATE_SA="YOUR-STATE-ACCOUNT-NAME"       # from Module 4
LOCATION="westeurope"
# ----------------------------------------------------------------------------

SUB_ID=$(az account show --query id --output tsv)
TENANT_ID=$(az account show --query tenantId --output tsv)

ISSUER="https://token.actions.githubusercontent.com"
AUDIENCE="api://AzureADTokenExchange"

ROLE_READER="acdd72a7-3385-48ef-bd42-f606fba81ae7"
ROLE_CONTRIBUTOR="b24988ac-6180-42a0-ab88-20f7382dd24c"
ROLE_BLOB_CONTRIB="ba92f5b4-2d11-453d-a403-e96b0029c9fe"

echo "==> Creating the target resource group (the pipeline's entire blast radius)"
az group create --name rg-capstone-prod --location "$LOCATION" \
  --tags project=capstone managed_by=setup-script --output none

echo "==> Creating the plan identity (read-only, trusted by PRs and scheduled runs)"
az identity create --name id-capstone-plan --resource-group rg-tofu-state \
  --location "$LOCATION" --output none

az identity federated-credential create \
  --name github-pull-request \
  --identity-name id-capstone-plan --resource-group rg-tofu-state \
  --issuer "$ISSUER" --audiences "$AUDIENCE" \
  --subject "repo:${GH_REPO}:pull_request" --output none

az identity federated-credential create \
  --name github-branch-main \
  --identity-name id-capstone-plan --resource-group rg-tofu-state \
  --issuer "$ISSUER" --audiences "$AUDIENCE" \
  --subject "repo:${GH_REPO}:ref:refs/heads/main" --output none

echo "==> Creating the apply identity (write, trusted only by the gated prod environment)"
az identity create --name id-capstone-apply --resource-group rg-tofu-state \
  --location "$LOCATION" --output none

az identity federated-credential create \
  --name github-environment-prod \
  --identity-name id-capstone-apply --resource-group rg-tofu-state \
  --issuer "$ISSUER" --audiences "$AUDIENCE" \
  --subject "repo:${GH_REPO}:environment:prod" --output none

echo "==> Assigning least-privilege roles"
PLAN_OID=$(az identity show --name id-capstone-plan --resource-group rg-tofu-state --query principalId --output tsv)
APPLY_OID=$(az identity show --name id-capstone-apply --resource-group rg-tofu-state --query principalId --output tsv)
TARGET_SCOPE="/subscriptions/${SUB_ID}/resourceGroups/rg-capstone-prod"
STATE_SCOPE="/subscriptions/${SUB_ID}/resourceGroups/rg-tofu-state/providers/Microsoft.Storage/storageAccounts/${STATE_SA}"

az role assignment create --assignee-object-id "$PLAN_OID" \
  --assignee-principal-type ServicePrincipal \
  --role "$ROLE_READER" --scope "$TARGET_SCOPE" --output none

az role assignment create --assignee-object-id "$PLAN_OID" \
  --assignee-principal-type ServicePrincipal \
  --role "$ROLE_BLOB_CONTRIB" --scope "$STATE_SCOPE" --output none

az role assignment create --assignee-object-id "$APPLY_OID" \
  --assignee-principal-type ServicePrincipal \
  --role "$ROLE_CONTRIBUTOR" --scope "$TARGET_SCOPE" --output none

az role assignment create --assignee-object-id "$APPLY_OID" \
  --assignee-principal-type ServicePrincipal \
  --role "$ROLE_BLOB_CONTRIB" --scope "$STATE_SCOPE" --output none

echo
echo "Done. Create these four repository secrets in GitHub"
echo "(Settings > Secrets and variables > Actions):"
echo
echo "  AZURE_TENANT_ID:        ${TENANT_ID}"
echo "  AZURE_SUBSCRIPTION_ID:  ${SUB_ID}"
echo "  AZURE_CLIENT_ID_PLAN:   $(az identity show --name id-capstone-plan --resource-group rg-tofu-state --query clientId --output tsv)"
echo "  AZURE_CLIENT_ID_APPLY:  $(az identity show --name id-capstone-apply --resource-group rg-tofu-state --query clientId --output tsv)"
echo
echo "Then: create the gated 'prod' environment and the branch ruleset"
echo "(course: Capstone > Run the pipeline), and set your state account name"
echo "in infra/main.tf's backend block."
echo
echo "Note: role assignments can take a few minutes to propagate."
```

Run it:

```bash
bash scripts/setup-azure.sh
```

## 4. Configure the repository

With the script's output in front of you:

1. **Secrets** (Settings, then Secrets and variables, then Actions): create the four secrets exactly as printed.
2. **Environment** (Settings, then Environments): create `prod`, exact spelling, and add yourself as a required reviewer (Lab 5, step 5).
3. **Ruleset** (Settings, then Rules, then Rulesets): as in Lab 6, target the default branch, require a pull request with one approval, and require the `plan` status check. One capstone-specific wrinkle: the `plan` check will not be searchable until it has run once, so create the ruleset now with the PR requirement, and return to add the status check requirement after your first pull request has run.

## 5. First push, first pull request

Ship the whole repository in one initial push to `main` (do this before activating the ruleset's pull request requirement, or grant yourself a one-time bypass):

```bash
git add .
git commit -m "Capstone: infrastructure and pipeline"
git push
```

That push triggers the Apply workflow, which stops at the `prod` gate. **Reject it** (Review deployments, then Reject): the point of this build is that infrastructure arrives through reviewed pull requests, and this run had no reviewed plan. The rejected run is your pipeline's first artifact of discipline; leave it in the history.

Now make the first change by the front door. Give the storage account a tag, on a branch:

```bash
git checkout -b first-change
```

Edit `infra/storage.tf` and add a line to the storage account's `tags` (for example `first_change = "true"` inside a `merge(local.common_tags, {...})`, or simply widen `common_tags` in `main.tf`). Commit, push, open the pull request.

Watch the plan check run. Its summary shows the **entire environment**, `6 to add`, because nothing exists yet: both identities are working, the scanners passed, and the plan identity read your empty state from the backend. Have the reviewer's conversation with yourself: does the plan contain exactly what the walkthrough promised?

## 6. Merge, gate, apply

Merge the pull request. The Apply workflow starts, and pauses: **Waiting for review**. Approve it.

Now wait properly: the Container Apps environment is the slow resource, and the whole apply can take several minutes. When it finishes, open the run summary; the outputs block prints your `app_url`.

## 7. Verify like an operator, then like a user

```bash
az resource list --resource-group rg-capstone-prod --output table
```

Five entries: virtual network, storage account, the managed environment, the container app (subnets ride inside the VNet). Then the user's test: open the `app_url` in a browser. The first request after idling wakes the app from zero, so give it a few seconds; then Microsoft's hello-world page confirms that a Git commit became a running, TLS-terminated web application with no credential stored anywhere on the way.

Confirm the fleet is complete with one more glance at the Actions tab: the drift workflow is scheduled and can be exercised with Run workflow (it should report green, freshly applied), and the destroy workflow sits armed for the teardown chapter.

## If something failed

Every failure in this runbook is one of the course's catalogued ones. Authentication errors: Lab 5's failure modes (subject mismatches, wrong client ID, missing `id-token: write`). State errors: Lab 4's (role propagation, `use_azuread_auth`). Gate anomalies: Lab 5's. Scanner failures: Lab 6's. Read the failing step's log, name the layer it belongs to, and go to that module's failure table; diagnosing from logs is the skill the labs have been building all along.

Live system achieved. Last chapter: kill it cleanly, and take stock of what you can now do.
