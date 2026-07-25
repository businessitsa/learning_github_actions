---
title: 'Lab 6: harden the pipeline'
description: Pin, scan, protect and watch the pipeline from Module 5, then tear the lab down.
---

# Lab 6: harden the pipeline

Time: about 60 minutes. Cost: nothing new. Requires: the working pipeline from Lab 5.

Work on a branch throughout; the pipeline you are hardening is also the thing deploying your changes, which is the appropriately real experience:

```bash
cd tofu-azure-course
git checkout main && git pull
git checkout -b harden-pipeline
```

## 1. Pin every action

Replace each `uses:` tag reference in **both** workflows with its pinned SHA. These were resolved from the GitHub API in July 2026 (re-resolve them yourself for practice, or when versions have moved):

```yaml
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1
      - uses: opentofu/setup-opentofu@a1320f892987e89d278cc92dc5adc984fb93aca4  # v2.0.2
```

## 2. Add the scanners to the plan workflow

In `.github/workflows/tofu-plan.yml`, insert these steps after "Validate" and before "Plan":

```yaml
      - name: Lint with tflint
        uses: terraform-linters/setup-tflint@6e1e0642c0289bd619021bf6b34e3c08ed1e005a  # v6.3.0

      - name: Run tflint
        run: |
          tflint --init
          tflint --format compact

      - name: Scan for misconfigurations with Trivy
        uses: aquasecurity/trivy-action@ed142fd0673e97e23eac54620cfb913e5ce36c25  # v0.36.0
        with:
          scan-type: config
          scan-ref: infra
          exit-code: '1'
          severity: HIGH,CRITICAL
```

tflint here runs its built-in rules, which need no configuration file. Trivy's `exit-code: '1'` makes findings of the listed severities fail the check, which is the entire point: a finding blocks the merge, a human decides. When you later add the tflint azurerm ruleset or tune Trivy policies, those decisions belong in versioned config files (`.tflint.hcl`, `trivy.yaml`) reviewed like any other code.

## 3. Add drift detection

Create `.github/workflows/tofu-drift.yml` exactly as printed on the [previous page](scanning-and-state-security). It authenticates as the plan identity from a scheduled run on `main`, which is a new OIDC subject, so grant the trust:

```bash
GH_REPO="YOUR-USERNAME/tofu-azure-course"

az identity federated-credential create \
  --name github-branch-main \
  --identity-name id-tofu-plan \
  --resource-group rg-tofu-state \
  --issuer 'https://token.actions.githubusercontent.com' \
  --subject "repo:${GH_REPO}:ref:refs/heads/main" \
  --audiences 'api://AzureADTokenExchange'
```

Ship everything so far through your own pipeline:

```bash
git add .github/workflows
git commit -m "Pin actions, add scanners and drift detection"
git push --set-upstream origin harden-pipeline
```

Open the PR. Note the plan check now runs the scanners (no `infra/` change means no plan trigger; that path filter includes workflow changes? It does not, so if the check does not appear, add a whitespace-only change under `infra/` to the branch, or extend `paths:` to include the workflow files, which is a defensible permanent choice). Merge, approve the (empty) apply if it runs, and confirm `main` now carries the hardened workflows.

## 4. Protect the branch

Settings, then Rules, then Rulesets, then New ruleset:

- Name: `protect-main`. Enforcement: Active. Target: the default branch.
- Require a pull request before merging, one approval.
- Require status checks to pass: search for and add the check named `plan`.
- Leave block force pushes enabled.

Then prove it works:

```bash
git checkout main && git pull
echo "# direct push test" >> README.md
git add README.md && git commit -m "Test direct push"
git push
```

The push is rejected with a rule violation. Reset your local branch to match reality again:

```bash
git reset --hard origin/main
```

From now on, every change walks through the front door, including yours, including "urgent" ones. That is the feature.

## 5. Flip the scanning switches

Settings, then Advanced Security: enable **Secret scanning** and **Push protection** if not already on. No further action; they work in the background.

## 6. See drift detection catch you

Make some drift, exactly as a hurried colleague would:

```bash
az storage account update \
  --name $(az storage account list --resource-group rg-pipeline-lab --query "[0].name" --output tsv) \
  --resource-group rg-pipeline-lab \
  --set tags.hotfix=true
```

Run the drift workflow manually: Actions, then "Drift detection", then Run workflow. It fails (that is success), and its run summary shows the tag difference. Fix the drift the honest way, deciding the code is right:

```bash
az storage account update \
  --name $(az storage account list --resource-group rg-pipeline-lab --query "[0].name" --output tsv) \
  --resource-group rg-pipeline-lab \
  --remove tags.hotfix
```

Re-run the drift workflow; green. (Reality moved back to match the code. The other legitimate resolution is a PR that adopts the change into code; either way, code and reality agree again, deliberately.)

## 7. Tear down the module 5 and 6 lab

The infrastructure goes out the same door it came in. On a branch, delete the `azurerm_storage_account` and `random_string` resources from `infra/main.tf` (leave the `terraform`, `provider` and `data` blocks), open a PR, and read the plan: `1 to destroy` and the storage account prefixed `-`. Merge and approve. The pipeline destroys its own creation, with review and approval, which is how production infrastructure should die.

Then remove the scaffolding by hand (you created it by hand):

```bash
az group delete --name rg-pipeline-lab --yes
az identity delete --name id-tofu-plan --resource-group rg-tofu-state
az identity delete --name id-tofu-apply --resource-group rg-tofu-state
```

Keep `rg-tofu-state` and the state account: the capstone needs them. The four GitHub secrets can stay; the capstone repository will get its own.

## Checklist

You can now:

- [ ] Explain why a SHA is the only immutable action reference, and resolve one from a tag.
- [ ] Write a least-privilege `permissions` block and state the everything-else-becomes-none rule.
- [ ] Recognise script injection in a workflow and fix it with `env:` indirection.
- [ ] Say what `pull_request_target` does and why it is dangerous.
- [ ] Add lint and security scanning that blocks merges on findings.
- [ ] Protect a branch so the pipeline is the only path to production.
- [ ] Build a read-only, scheduled drift detector and explain each design choice in it.

## Common failure modes

**Drift workflow fails at authentication.**
The scheduled/manual run's subject is `repo:ORG/REPO:ref:refs/heads/main`; if you skipped the third federated credential (or typed the branch as `refs/head/main`, missing the `s`), Entra refuses. Same character-by-character diff as always.

**The `plan` status check never appears in the ruleset's search box.**
GitHub learns check names from runs. The plan workflow must have run at least once on a PR (it has, in Lab 5); search for the job name `plan`, not the workflow name.

**Trivy fails the build on findings you did not introduce.**
The scanners judge the whole `infra/` directory, not the diff. That is correct behaviour on day one of adopting a scanner: fix the findings, or record explicit, commented exceptions in versioned config. Silence is a decision; make it in code review.

**Your own push to main was rejected right after you created the ruleset.**
Working as designed, including for administrators. If you gave yourself a bypass when creating the ruleset, remove it; a bypass you use routinely is a rule you do not have.

**The scheduled drift run did not fire at 05:17 sharp.**
Schedules run on shared infrastructure and can be delayed by minutes; the offset minute (17) avoids the on-the-hour crowd but promises nothing. If a run matters to the minute, schedules are the wrong trigger.

Module 6 done. Five layers, all real. One thing left: build the whole system again, from nothing, as if it were production. That is the capstone.
