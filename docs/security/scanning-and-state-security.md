---
title: Scanning, state protection and drift
description: Static analysis in the pipeline, encrypting state, and catching out-of-band changes.
---

# Scanning, state protection and drift

## Static analysis: problems die before merge

Your plan workflow already refuses unformatted (`tofu fmt -check`) and invalid (`tofu validate`) code. Two scanners raise the bar from "valid" to "sound", and both run happily on OpenTofu code because they analyse standard HCL:

**tflint** catches code-quality issues: unused declarations, deprecated syntax, references that will fail at apply time. One caveat from its maintainers worth knowing: it parses `.tf` files but not OpenTofu's optional `.tofu` extension, one more reason this course sticks to `.tf`. Out of the box it runs its built-in rules; the `azurerm` ruleset plugin adds Azure-specific checks (invalid VM sizes, impossible names) and is worth adding once the basics are routine.

**Trivy** scans infrastructure code for security misconfigurations: public buckets, permissive network rules, disabled encryption, weak TLS. It inherited and extended the well-known tfsec engine. (Checkov is a respectable alternative; it explicitly supports OpenTofu. Pick one, run it on every PR.)

Both drop into the plan workflow as steps before `tofu plan`, and the lab does exactly that. The principle matters more than the tools: **the pull request is the cheapest place to catch a problem**, so load your checks there.

## State: protect the file that knows everything

Module 4 established the baseline: state lives in a private, Entra-authenticated, key-disabled storage account, reachable only by you and the two pipeline identities. Recap of why the care: state records every attribute of every managed resource, including any secrets providers return, in plain text.

OpenTofu can go one layer deeper than access control: **client-side state encryption**, an OpenTofu-exclusive feature. The state (and plan files, which carry the same data) are encrypted before they leave the machine, so even someone holding the blob has ciphertext:

```hcl
# encryption.tf (an example shape; the lab treats this as optional)
terraform {
  encryption {
    key_provider "pbkdf2" "main" {
      passphrase = var.state_passphrase   # 16 characters minimum
    }

    method "aes_gcm" "secure" {
      keys = key_provider.pbkdf2.main
    }

    state {
      method = method.aes_gcm.secure
    }

    plan {
      method = method.aes_gcm.secure
    }
  }
}
```

Key providers besides a passphrase include Azure Key Vault, AWS and GCP KMS, and OpenBao; AES-GCM is the encryption method. Existing plaintext state migrates in by declaring a `fallback` (read the old form, write the new), and the whole configuration can alternatively be supplied through the `TF_ENCRYPTION` environment variable, which is the natural fit for CI: the passphrase lives in a GitHub secret and never in code.

The honest trade-off: encrypted state is unreadable to every tool but yours, and a lost passphrase is lost state. For a learning project the access-controlled backend is adequate; know this exists, and deploy it when the state's contents warrant it.

Related, and newer: OpenTofu 1.11 introduced **ephemeral variables** and write-only attributes, values that flow through a run without ever being persisted to state. When a provider supports them for a secret-shaped attribute, prefer them; nothing beats not storing.

## Drift detection: trust, then verify on a timer

Your layers guard the pipeline's door. Drift is the window: changes made directly in the portal or CLI, bypassing code review entirely, with the best intentions and at 2 a.m. You demonstrated drift by hand in Lab 4; production catches it automatically.

The trick is one you already own: `tofu plan -detailed-exitcode` exits **0** when reality matches code, **2** when anything differs. Run it on a schedule; a non-zero-diff day fails loudly:

```yaml
# .github/workflows/tofu-drift.yml
name: Drift detection
on:
  schedule:
    - cron: '17 5 * * *'   # daily, 05:17 UTC; avoid busy on-the-hour slots
  workflow_dispatch:

permissions:
  id-token: write
  contents: read

env:
  ARM_USE_OIDC: 'true'
  ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID_PLAN }}
  ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
  ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

defaults:
  run:
    working-directory: infra

jobs:
  detect:
    runs-on: ubuntu-latest
    steps:
      - name: Check out the repository
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1

      - name: Install OpenTofu
        uses: opentofu/setup-opentofu@a1320f892987e89d278cc92dc5adc984fb93aca4  # v2.0.2
        with:
          tofu_version: 1.12.5
          tofu_wrapper: false

      - name: Initialise
        run: tofu init

      - name: Plan against reality
        id: plan
        run: |
          set +e
          tofu plan -no-color -detailed-exitcode -out=driftplan
          code=$?
          set -e
          echo "exitcode=$code" >> "$GITHUB_OUTPUT"
          if [ "$code" -eq 1 ]; then exit 1; fi

      - name: Report drift
        if: steps.plan.outputs.exitcode == '2'
        run: |
          {
            echo '## Drift detected'
            echo 'Reality no longer matches the code. The differences:'
            echo '```'
            tofu show -no-color driftplan
            echo '```'
          } >> "$GITHUB_STEP_SUMMARY"
          exit 1
```

Design notes, all deliberate:

- **It uses the plan identity.** Detection is read-only; the watcher holds no power to "fix" anything, so a compromised or misfiring drift job cannot change infrastructure. Correction happens the only way changes ever happen here: a human reads the report and opens a pull request (or reverts the manual change).
- **One new federated credential is required.** A scheduled run executes against the default branch with no environment, so its OIDC subject is `repo:ORG/REPO:ref:refs/heads/main`, the branch format from Module 5. The lab adds that credential to the plan identity.
- **Exit code 1 (a real error) fails the run at the plan step**; exit code 2 flows into a readable summary and then fails the run so the red X is visible. A failed scheduled run also emails the repository owner by default, which is a perfectly good alert channel at this scale.

Everything on this page lands in your pipeline in the lab, next.
