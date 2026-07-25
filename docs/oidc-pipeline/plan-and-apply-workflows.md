---
title: Plan on pull request, apply on merge
description: The two workflows and the environment gate that turn review into deployment.
---

# Plan on pull request, apply on merge

Everything so far converges here. The pipeline's rhythm has two beats: **propose and preview** (a pull request triggers a plan everyone can read), then **approve and execute** (the merge triggers an apply, held at a human gate).

![Plan on pull request, apply on merge: the PR job plans read-only and posts the diff for review; after merge, the apply workflow waits at the prod environment gate before applying](/img/diagrams/pr-plan-merge-apply.svg)

## The gate: GitHub environments

A GitHub **environment** is a named deployment target with rules. Create one in the repository under Settings, then Environments, name it `prod`, and add the protection rule **Required reviewers** with yourself as reviewer. From then on, any job that declares `environment: prod` stops before starting and waits for an approval; up to six reviewers can be listed and a single approval proceeds. Two facts to plan around: on free plans, protection rules work on **public** repositories (private ones need a paid plan), and the environment's name is part of the OIDC subject (`repo:ORG/REPO:environment:prod`), so it must match the federated credential exactly, including case.

The gate composes with the identity design from the previous page into a chain worth restating: the only identity that can change infrastructure is only issued to jobs in `prod`, and jobs in `prod` only start after a human approves. Azure enforces the first half, GitHub the second.

## The plan workflow

```yaml
# .github/workflows/tofu-plan.yml
name: Plan
on:
  pull_request:
    branches: [main]
    paths: ['infra/**']

permissions:
  id-token: write   # allows requesting the OIDC token, nothing more
  contents: read

concurrency:
  group: plan-${{ github.ref }}
  cancel-in-progress: true

env:
  ARM_USE_OIDC: 'true'
  ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID_PLAN }}
  ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
  ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

defaults:
  run:
    working-directory: infra

jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      - name: Check out the repository
        uses: actions/checkout@v7

      - name: Install OpenTofu
        uses: opentofu/setup-opentofu@v2
        with:
          tofu_version: 1.12.5
          tofu_wrapper: false

      - name: Check formatting
        run: tofu fmt -check -recursive

      - name: Initialise
        run: tofu init

      - name: Validate
        run: tofu validate

      - name: Plan
        run: tofu plan -no-color -out=tfplan

      - name: Publish the plan to the run summary
        run: |
          {
            echo '## OpenTofu plan'
            echo '```'
            tofu show -no-color tfplan
            echo '```'
          } >> "$GITHUB_STEP_SUMMARY"
```

Reading it with everything you now know:

- **`paths: ['infra/**']`** triggers only when infrastructure code changes; a README edit does not need a plan.
- **`permissions`** grants exactly the token request and repository read. Everything unlisted is `none`.
- **The `env` block does the authentication.** No login action, no credential step: the azurerm provider and backend read the `ARM_*` variables, see `ARM_USE_OIDC`, fetch the GitHub JWT from the runner, and perform the exchange from the previous pages themselves. The client ID is the **plan** identity, so this job physically cannot modify infrastructure.
- **`tofu_wrapper: false`** disables an output-wrapping convenience in the setup action that interferes with exit codes and piping; plain behaviour is what automation wants.
- **The summary step** renders the plan on the run's front page. Reviewers read the *consequences* of the diff, not just the diff. (`concurrency` with `cancel-in-progress: true` keeps only the newest plan per pull request running; stale plans of superseded commits are worthless.)

## The apply workflow

```yaml
# .github/workflows/tofu-apply.yml
name: Apply
on:
  push:
    branches: [main]
    paths: ['infra/**']

permissions:
  id-token: write
  contents: read

concurrency:
  group: tofu-apply
  cancel-in-progress: false   # never kill a running apply

env:
  ARM_USE_OIDC: 'true'
  ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID_APPLY }}
  ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
  ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

defaults:
  run:
    working-directory: infra

jobs:
  apply:
    runs-on: ubuntu-latest
    environment: prod
    steps:
      - name: Check out the repository
        uses: actions/checkout@v7

      - name: Install OpenTofu
        uses: opentofu/setup-opentofu@v2
        with:
          tofu_version: 1.12.5
          tofu_wrapper: false

      - name: Initialise
        run: tofu init

      - name: Plan
        run: tofu plan -no-color -out=tfplan

      - name: Apply the saved plan
        run: tofu apply tfplan

      - name: Publish the result to the run summary
        run: |
          {
            echo '## Applied'
            echo '```'
            tofu show -no-color
            echo '```'
          } >> "$GITHUB_STEP_SUMMARY"
```

The differences from the plan workflow are few and every one is meaningful:

- **`on: push` to `main`**: it runs when a pull request merges (or someone pushes directly, which branch protection in Module 6 will forbid).
- **`environment: prod`** engages the approval gate, and makes GitHub mint the job's OIDC token with the `environment:prod` subject that the apply identity's federated credential demands.
- **The client ID is the apply identity**, the one holding Contributor.
- **Plan-then-apply-the-file**: the job re-plans and applies exactly what it planned, atomically, on the merged code. The PR plan was for human eyes; the infrastructure change is computed from `main` as merged, so an out-of-date PR plan can never be executed by accident.
- **`concurrency` with `cancel-in-progress: false`** queues applies instead of overlapping or cancelling them. The state lock would prevent corruption anyway; this prevents even the collision.

## The flow, end to end

1. Branch, edit `infra/`, push, open a pull request.
2. The Plan workflow runs with read-only power and posts what would change.
3. A reviewer reads the plan, requests changes or approves; you merge.
4. The Apply workflow starts and immediately pauses: **Waiting for review** at the `prod` gate.
5. A reviewer approves the deployment. The job gets its token (subject: `environment:prod`), becomes the apply identity, re-plans, applies, and the run summary records the new reality.

One pipeline, two identities, three checkpoints (PR review, environment approval, state lock). Now build it.
