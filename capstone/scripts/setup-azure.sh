#!/usr/bin/env bash
# scripts/setup-azure.sh
# One-time Azure setup for the capstone pipeline. Run this as yourself,
# logged in with `az login`, from any bash shell. It is safe to re-run;
# every command either creates or updates the same objects.
#
# Prerequisites (from the course, Modules 4 and 5):
#   - The state backend exists: resource group rg-tofu-state with your
#     Entra-authenticated, key-disabled storage account and tfstate container.
#   - You know your state storage account's name.
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
