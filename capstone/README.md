# Capstone: OpenTofu on Azure via GitHub Actions with OIDC

This directory is the complete worked repository for Module 7 of the course.
It deploys a small but real Azure environment (virtual network, storage
account, and a container app that scales to zero) through a pull-request
driven pipeline with no long-lived cloud credentials anywhere.

## How to use it

1. Create a new, empty **public** GitHub repository (the course uses the name
   `capstone-azure`) and copy the contents of this directory into its root.
2. Follow the course's capstone chapters, starting at "Capstone overview".
   In short: run `scripts/setup-azure.sh`, add the four repository secrets,
   create the gated `prod` environment and the branch ruleset, then open your
   first pull request.
3. Tear everything down with the "Teardown" chapter when you are done.

## Layout

```text
.
├── .github/workflows/
│   ├── tofu-plan.yml      # plan + scanners on every pull request
│   ├── tofu-apply.yml     # gated apply on merge to main
│   ├── tofu-drift.yml     # scheduled read-only drift detection
│   └── tofu-destroy.yml   # manual, gated, confirmed destroy
├── infra/
│   ├── main.tf            # versions, backend, provider, target resource group
│   ├── variables.tf
│   ├── network.tf         # vnet + subnet
│   ├── storage.tf         # data storage account
│   ├── app.tf             # container apps environment + app
│   └── outputs.tf
├── scripts/
│   └── setup-azure.sh     # one-time identity, trust and RBAC setup
└── .gitignore
```

## Costs

Designed to idle at effectively zero: the container app scales to zero inside
Azure Container Apps' always-free monthly grant, the network resources are
free, and the storage accounts hold pennies' worth of data. See the course's
cost notes, and always run the teardown when finished.
