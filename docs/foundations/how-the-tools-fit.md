---
title: How the tools fit together
description: The roles of GitHub, GitHub Actions, OpenTofu and Azure in one pipeline.
---

# How the tools fit together

Four systems cooperate in the pipeline you are going to build. Each has exactly one job.

| System | Role in the pipeline |
|---|---|
| **GitHub** | Holds the code, enforces review through pull requests, and stores nothing secret about your cloud. |
| **GitHub Actions** | Runs automation when events happen in the repository: a push, a pull request, a schedule, a button press. |
| **OpenTofu** | Reads your declarative configuration, compares it with recorded state and with the real cloud, and creates, changes or destroys resources to match. |
| **Microsoft Azure** | The cloud where the resources actually live, and the authority that decides what your pipeline is allowed to touch. |

## The full picture

![The target pipeline: a commit triggers GitHub Actions, the job exchanges an OIDC token for Azure access, and OpenTofu plans and applies the infrastructure](/img/diagrams/pipeline-overview.svg)

Walk the flow once now, lightly. Each numbered step becomes a whole module later.

1. **You commit and push.** Infrastructure changes are just Git commits to files ending in `.tf`.
2. **GitHub Actions triggers.** A workflow file in the repository says "when a pull request changes infrastructure code, run these steps on a fresh virtual machine."
3. **The runner proves its identity to Azure.** This is the step that makes the whole design worth copying. The workflow holds no password, key or certificate. Instead, GitHub issues the running job a short-lived, cryptographically signed token stating exactly which repository, branch and environment it came from. Azure has been configured in advance to trust tokens with exactly those properties, and exchanges the token for a short-lived Azure credential. This mechanism is called **OpenID Connect federation** (OIDC). Module 5 is devoted to it.
4. **OpenTofu plans and applies.** On a pull request it only computes and publishes the plan, the preview of what would change. Only after review, merge and an explicit human approval does an apply run make the changes real.
5. **Azure enforces the blast radius.** The identity the pipeline uses has been granted the narrowest role that still works, on the narrowest scope that still works. Even a fully compromised pipeline cannot touch anything outside that scope.

:::tip[The security thread]

Notice what is absent: there is no "deployment password" stored anywhere, on any step. Security in this course is not a final chapter; it is a design constraint from the first line of YAML. Every credential you will ever configure is either short-lived and automatically issued, or an identifier that is useless to an attacker on its own.

:::

## Why OpenTofu and not Terraform

If you have heard of this style of tooling before, you probably heard the name Terraform. OpenTofu is a **fork** of Terraform: a copy of its source code that continued development under new governance.

The short history: Terraform was open source under the MPL 2.0 license until August 2023, when its vendor moved it to a more restrictive license. A group of companies and contributors forked the last open version, named the fork OpenTofu, and donated it to the Linux Foundation, where it remains MPL 2.0 licensed and community-governed.

Practical consequences for you:

- The CLI binary is `tofu`, not `terraform`. The workflow (`init`, `plan`, `apply`) is the same.
- Configuration language and providers are compatible. The Azure provider you will use is the same code either way; OpenTofu serves it from its own registry.
- OpenTofu has grown features Terraform lacks, two of which this course teaches: built-in **state encryption**, and a growing set of language conveniences.
- Environment variables deliberately keep the historical `TF_` prefix (for example `TF_VAR_location`), so existing tooling keeps working.

This course uses OpenTofu commands exclusively. Where an error message, document or file name still says "terraform" for compatibility reasons (and a few do, such as the default state file name `terraform.tfstate`), the text points it out so it does not surprise you.

## What "current" means here

Versions move. This course was written and verified against these versions in July 2026:

- **OpenTofu 1.12.x**, installed and version-pinned in Module 1's lab.
- **azurerm provider 4.x**, the plugin OpenTofu uses to talk to Azure.
- **GitHub Actions** on `ubuntu-latest` runners, which currently means Ubuntu 24.04.
- **Azure CLI 2.88+** for the small amount of one-time setup that is done by hand.

One honest warning learned from researching this course: official documentation examples frequently lag the released versions of the actions and tools they show. Where that matters, the course tells you both what the docs show and what is actually current.

Next: [set up your tools](lab).
