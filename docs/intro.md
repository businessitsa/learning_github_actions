---
slug: /
title: Start here
description: What this course teaches, what it costs, and how to work through it.
---

# From Commit to Cloud

This course takes you from zero knowledge to a real, working infrastructure deployment pipeline. By the end, you will commit OpenTofu code to a GitHub repository, a GitHub Actions runner will authenticate to Microsoft Azure without any stored password or key, and your infrastructure will be planned, reviewed, approved and built automatically.

![The target pipeline: from commit to cloud](/img/diagrams/pipeline-overview.svg)

Everything in the diagram above will make sense by Module 5. In Module 7 you will build it yourself, end to end.

## Who this is for

You are an experienced IT professional. You know your way around a terminal, you have used Git at least casually, and you understand roughly what a server, a network and a cloud provider are. You do not need to know anything about GitHub Actions, OpenTofu or Azure. Every concept from those three tools is explained on first use.

## What you will be able to do

- Write GitHub Actions workflows from scratch: triggers, jobs, steps, runners, expressions.
- Explain Azure's identity and resource model: tenants, subscriptions, resource groups, Microsoft Entra ID, role-based access control.
- Write OpenTofu configurations in HCL, manage their state remotely in Azure Storage with locking, and run the plan and apply lifecycle with confidence.
- Connect GitHub to Azure with OpenID Connect federation, so no long-lived cloud credential ever exists in your pipeline.
- Harden the whole system: pinned actions, least-privilege tokens, scanning, branch protection, drift detection.
- Reproduce a complete production-style repository that deploys a small but real Azure environment through a pull-request-driven workflow.

## How the course works

Seven modules, strictly in order. Each module ends with three things:

1. **A hands-on lab.** You build something real. Modules 1 and 2 need no cloud account at all.
2. **A checklist.** Concrete statements of what you can now do. If one feels shaky, revisit that section before moving on.
3. **Common failure modes.** The errors most people hit, what they look like, and the fix.

Commands are given for Windows (PowerShell), macOS and Linux where they differ. Every code block that belongs in a file starts with a comment naming that file, so you always know where things live.

## What it costs

:::warning[Money]

The course is designed to cost **nothing or nearly nothing**, but it does use a real Azure subscription from Module 3 onwards.

- New Azure accounts get **200 US dollars of credit for 30 days** plus a set of always-free services. A credit or debit card is required for identity verification, with a small temporary authorization; you are not charged unless you explicitly upgrade to pay-as-you-go.
- The capstone app runs on **Azure Container Apps** inside its always-free monthly grant, and scales to zero when idle.
- The OpenTofu state storage account costs **a few cents per month** at most.
- Every module that creates billable resources ends with teardown instructions, and the capstone has a dedicated teardown chapter.

Anything that can cost money is flagged with a box like this one.

:::

## Versions this course targets

Content was verified against official documentation in July 2026. The exact pages and retrieval dates are logged in [SOURCES.md](https://github.com/businessitsa/learning_github_actions/blob/main/SOURCES.md).

| Tool | Version taught |
|---|---|
| OpenTofu | 1.12.x |
| azurerm provider | 4.x |
| Azure CLI | 2.88+ |
| GitHub Actions runners | `ubuntu-latest` (Ubuntu 24.04) |

Where official documentation lags behind released versions (it happens more than you would think), the course says so explicitly.

## The course map

1. **Foundations.** What infrastructure as code is, why declarative wins, and how the three tools fit together.
2. **GitHub Actions basics.** Workflows, triggers, jobs, runners, contexts and expressions, with labs that run entirely on GitHub's free tier.
3. **Azure for IaC.** Exactly the identity and access concepts the pipeline needs, covered deeply.
4. **OpenTofu fundamentals.** HCL, providers, the plan and apply lifecycle, and remote state in Azure Storage with locking.
5. **Wiring it together with OIDC.** Federated credentials, environment protection, plan on pull request, apply on merge.
6. **Security deep dive.** Defense in depth for the whole pipeline.
7. **Capstone.** The complete worked repository, built and torn down by you.

Ready? Start with [what infrastructure as code actually is](foundations/what-is-iac).
