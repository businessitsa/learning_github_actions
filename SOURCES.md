# Sources

Official documentation each module relied on. All pages were retrieved and
verified on **2026-07-25** during the research phase for this course. Version
numbers quoted in the course (OpenTofu 1.12.5, azurerm provider 4.81.0,
Docusaurus 3.10.2, Azure CLI 2.88.0, action releases) reflect that date.

Where documentation could not confirm a detail, the course text says so
inline rather than presenting it as fact.

## GitHub Actions (Modules 2, 5, 6)

- https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax - workflow keys, triggers, permissions scopes, concurrency
- https://docs.github.com/en/actions/reference/runners/github-hosted-runners - runner labels and specs
- https://docs.github.com/en/actions/reference/workflows-and-actions/contexts - contexts
- https://docs.github.com/en/actions/reference/workflows-and-actions/expressions - expressions and functions
- https://docs.github.com/en/actions/concepts/security/github_token - GITHUB_TOKEN concept
- https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/controlling-permissions-for-github_token - least-privilege guidance
- https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository - default token permissions, action allow-list policies
- https://docs.github.com/en/actions/concepts/security/openid-connect - OIDC concepts and claims
- https://docs.github.com/en/actions/reference/security/oidc - subject claim formats, issuer, claim customisation
- https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-azure - Azure OIDC flow
- https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-cloud-providers - id-token permission, token request methods
- https://docs.github.com/en/actions/reference/security/secure-use - SHA pinning, script injection, pull_request_target guidance
- https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments - environments and protection rules
- https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments - reviewer limits, wait timers, plan availability
- https://docs.github.com/en/actions/concepts/workflows-and-actions/concurrency - concurrency
- https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows - reusable workflows (background)
- https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching - caching (background)
- https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages - Pages deployment pattern
- https://api.github.com/repos/OWNER/REPO/releases/latest and .../git/ref/tags/TAG - release tags and pinned SHAs for actions/checkout, actions/setup-node, actions/upload-artifact, actions/download-artifact, actions/upload-pages-artifact, actions/deploy-pages, actions/configure-pages, azure/login, opentofu/setup-opentofu, terraform-linters/setup-tflint, aquasecurity/trivy-action
- https://raw.githubusercontent.com/actions/checkout/main/README.md - checkout v7 fork-PR checkout behaviour

## OpenTofu (Modules 1, 4, 5, 6)

- https://opentofu.org/docs/intro/install/ (and standalone, homebrew, windows sub-pages) - installation methods
- https://github.com/opentofu/opentofu/releases - versions and dates
- https://opentofu.org/blog/opentofu-1-12-0/ · /opentofu-1-11-0/ · /opentofu-1-10-0/ - release features
- https://opentofu.org/docs/language/settings/ - terraform and language blocks
- https://opentofu.org/docs/language/values/variables/ - variables, validation, sensitive, precedence
- https://opentofu.org/docs/language/modules/sources/ - module sources and registry
- https://opentofu.org/docs/cli/commands/plan/ - plan flags and -detailed-exitcode meanings
- https://opentofu.org/docs/cli/workspaces/ - workspaces and their limits
- https://opentofu.org/docs/language/state/purpose/ - why state exists
- https://opentofu.org/docs/language/state/encryption/ - state and plan encryption
- https://opentofu.org/docs/language/settings/backends/configuration/ - backend configuration, partial config
- https://opentofu.org/docs/language/settings/backends/azurerm/ - azurerm backend arguments, OIDC, blob-lease locking
- https://opentofu.org/docs/cli/config/environment-variables/ - TF_ prefixed environment variables
- https://opentofu.org/faq/ - fork history, licensing, governance
- https://opentofu.org/docs/intro/migration/ - Terraform compatibility
- https://api.opentofu.org/registry/docs/providers/hashicorp/azurerm/index.json - provider namespace equivalence
- https://github.com/opentofu/setup-opentofu - the setup action and its inputs
- https://github.com/hashicorp/terraform-provider-azurerm/releases - provider versions
- https://raw.githubusercontent.com/hashicorp/terraform-provider-azurerm/main/website/docs/index.html.markdown - provider configuration, features block, subscription_id requirement
- https://raw.githubusercontent.com/hashicorp/terraform-provider-azurerm/main/website/docs/guides/service_principal_oidc.html.markdown - provider OIDC auth
- https://github.com/terraform-linters/tflint - tflint (`.tofu` files not parsed)
- https://github.com/aquasecurity/trivy/discussions/5069 - Trivy and OpenTofu

## Microsoft Azure (Modules 3, 5, 7)

- https://learn.microsoft.com/en-us/entra/fundamentals/how-subscriptions-associated-directory - tenant and subscription trust relationship
- https://learn.microsoft.com/en-us/azure/governance/management-groups/overview - management groups
- https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles - role definitions and IDs
- https://learn.microsoft.com/en-us/azure/role-based-access-control/role-assignments-cli - assignment syntax, scopes, least privilege, principal-type guidance
- https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation-create-trust - app registration federated credentials, matching rules, limits
- https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation-create-trust-user-assigned-managed-identity - UAMI federated credentials
- https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure-openid-connect - GitHub-to-Azure OIDC setup
- https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure - authentication options ("secret: not recommended")
- https://learn.microsoft.com/en-us/cli/azure/ad/app - az ad app commands
- https://learn.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage - state storage setup, blob-lease locking
- https://learn.microsoft.com/en-us/azure/storage/common/shared-key-authorization-prevent - disabling shared keys, Entra recommendation
- https://learn.microsoft.com/en-us/cli/azure/install-azure-cli - CLI installation and version
- https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli - az login, MFA mandate for user identities
- https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming - naming conventions
- https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-setup-guide/regions - region selection
- https://azure.microsoft.com/en-us/pricing/purchase-options/azure-account - free account offer terms
- https://learn.microsoft.com/en-us/azure/container-apps/billing - Container Apps free monthly grant
- https://learn.microsoft.com/en-us/azure/app-service/overview-hosting-plans - App Service tiers (considered and not chosen)

## Docusaurus (this site)

- https://docusaurus.io/docs/installation - version, Node requirement, scaffolding
- https://docusaurus.io/docs/typescript-support - TypeScript configuration
- https://docusaurus.io/docs/docs-introduction - docs-only mode
- https://docusaurus.io/docs/sidebar and /sidebar/items - explicit sidebars
- https://docusaurus.io/docs/markdown-features/react - MDX 3 constraints
- https://docusaurus.io/docs/markdown-features/code-blocks - code block behaviour with `${{ }}`
- https://docusaurus.io/docs/markdown-features/admonitions - admonitions
- https://docusaurus.io/docs/markdown-features/tabs - tabs
- https://docusaurus.io/docs/api/docusaurus-config - onBrokenLinks, url/baseUrl/trailingSlash
- https://docusaurus.io/docs/deployment - GitHub Pages workflow
