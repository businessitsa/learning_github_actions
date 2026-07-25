---
title: Capstone overview
description: What you will build, what it costs, and what you need before starting.
---

# Capstone overview

Everything in the course converges here. You will create a fresh repository, wire it to Azure exactly as a production team would, and deploy a small but real environment: a virtual network, a storage account, and a public web application that scales to zero when nobody is looking at it. Every change travels through pull request, plan, review, merge, human gate and apply. Nothing travels any other way.

![Capstone environment topology: the pipeline manages a resource group containing a virtual network with an app subnet, a data storage account, and a container app; state lives in its own hand-made resource group; the GitHub runner reaches Azure through an OIDC federated credential](/img/diagrams/capstone-topology.svg)

## The pieces

**`rg-capstone-prod`** is the pipeline's world: created once by a setup script (because RBAC needs an existing scope), then populated, changed and drift-checked exclusively by OpenTofu. It contains:

- **`vnet-capstone`** (10.20.0.0/16) with subnet **`snet-app`** (10.20.1.0/24): real, managed network infrastructure. In this course build, the container app runs on Azure's shared network and the VNet stands alone; production-grade VNet integration requires a dedicated /23 subnet and paid-tier considerations, and the walkthrough marks it as the natural stretch exercise.
- **A data storage account** (`stcapstone` plus a random suffix): Entra-only authentication, no shared keys, TLS 1.2 minimum.
- **A Container Apps environment and app** (`cae-capstone-prod`, `ca-capstone-prod`): a public hello-world container with external HTTPS ingress, scaling between zero and one replica.

**`rg-tofu-state`** you already own from Module 4: the state account plus, after setup, the two pipeline identities.

**The pipeline** is the hardened version from Modules 5 and 6, present from the first commit: plan with formatters, linters and security scanning on every PR; gated apply on merge; scheduled read-only drift detection; and a deliberately awkward manual destroy workflow.

## What it costs

:::warning[Money]

Idle, this environment costs effectively zero: Azure Container Apps bills consumption against an always-free monthly grant (as of July 2026: the first 180,000 vCPU-seconds, 360,000 GiB-seconds and 2 million requests per subscription per month), and a scaled-to-zero app consumes none of it while asleep. Virtual networks and subnets are free objects. The two storage accounts hold kilobytes and round to cents.

Two honest caveats. First, quotas and offers change; verify the current Container Apps free grant against the [official pricing page](https://azure.microsoft.com/en-us/pricing/details/container-apps/) before relying on it. Second, a busy public URL is not free: if something starts hammering your app, the grant can exhaust. The capstone caps `max_replicas` at one to bound the blast radius, and the teardown chapter removes everything when you are done.

:::

## Prerequisites

- Modules 1 through 6 completed. The capstone deliberately re-exercises all of it with less hand-holding.
- The state backend from Module 4 alive: `rg-tofu-state`, your key-disabled storage account, the `tfstate` container.
- `az login` valid, and your subscription and tenant IDs at hand.
- About two hours, uninterrupted for the middle stretch (the first apply takes several minutes; Container Apps environments are slow to create).

## Where the code lives

The complete worked repository is in the course's own repo, under [`capstone/`](https://github.com/businessitsa/learning_github_actions/tree/main/capstone). The next page walks through every file; the page after that is the runbook you follow to bring it to life.
