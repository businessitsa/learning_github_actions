---
title: 'Lab 2: run real workflows'
description: Create a practice repository and exercise triggers, contexts, outputs and artifacts.
---

# Lab 2: run real workflows

Time: about 45 minutes. Cost: nothing (public repository, standard runners). Cloud account: not needed.

You will create the repository that carries you through the rest of the course, and run three workflows that exercise everything from the previous two pages.

## 1. Create your course repository

Create a new **public** repository on GitHub named `tofu-azure-course` (any name works; the course uses this one in examples). Initialize it with a README so it has a `main` branch, then clone it:

```bash
git clone https://github.com/YOUR-USERNAME/tofu-azure-course.git
cd tofu-azure-course
mkdir -p .github/workflows
```

:::note[Why public?]

Two GitHub features this course relies on are free only for public repositories: unlimited Actions minutes, and (in Module 5) environment protection rules with required reviewers. Everything can be done in a private repository too, but the protection rules then require a paid plan. Keep any real infrastructure code you write after the course in whatever visibility your organisation requires; there will be no secrets in this repository in the credential sense, which is rather the point of the whole design.

:::

## 2. Workflow one: see the contexts

```yaml
# .github/workflows/hello-context.yml
name: Hello context
run-name: Triggered by ${{ github.actor }} via ${{ github.event_name }}

on:
  push:
  workflow_dispatch:
    inputs:
      greeting:
        description: What should the job say?
        type: string
        default: hello

permissions:
  contents: read

jobs:
  inspect:
    runs-on: ubuntu-latest
    steps:
      - name: Show the basics
        env:
          ACTOR: ${{ github.actor }}
          REF: ${{ github.ref }}
          SHA: ${{ github.sha }}
          EVENT: ${{ github.event_name }}
        run: |
          echo "Actor:  $ACTOR"
          echo "Ref:    $REF"
          echo "Commit: $SHA"
          echo "Event:  $EVENT"

      - name: Greet, when dispatched manually
        if: github.event_name == 'workflow_dispatch'
        env:
          GREETING: ${{ inputs.greeting }}
        run: | 
          echo "You asked me to say: $GREETING"
```

Commit and push it:

```bash
git add .github/workflows/hello-context.yml
git commit -m "Add context inspection workflow"
git push
```

The push itself triggers the workflow. Open the repository's **Actions** tab, click the run, click the `inspect` job, and expand each step. Find the `refs/heads/main` value; you will meet that exact string again in Module 5, where Azure matches on it.

Now trigger it the second way: Actions tab, select "Hello context" in the left sidebar, press **Run workflow**, type a greeting, run it, and confirm the conditional step executed this time.

## 3. Workflow two: outputs and artifacts

This one models the shape of the real pipeline: a first job produces something, a second job consumes it, and they communicate two ways at once (a small string via job outputs, a file via an artifact).

```yaml
# .github/workflows/produce-consume.yml
name: Produce and consume
on: workflow_dispatch

permissions:
  contents: read

jobs:
  produce:
    runs-on: ubuntu-latest
    outputs:
      summary: ${{ steps.build.outputs.summary }}
    steps:
      - name: Check out the repository
        uses: actions/checkout@v7

      - name: Build a report file and an output
        id: build
        run: |
          echo "Report generated at $(date -u)" > report.txt
          echo "Repository has $(ls | wc -l) top-level items" >> report.txt
          echo "summary=report with $(wc -l < report.txt) lines" >> "$GITHUB_OUTPUT"

      - name: Upload the report as an artifact
        uses: actions/upload-artifact@v7
        with:
          name: report
          path: report.txt

  consume:
    runs-on: ubuntu-latest
    needs: produce
    steps:
      - name: Download the report
        uses: actions/download-artifact@v8
        with:
          name: report

      - name: Use both channels
        env:
          SUMMARY: ${{ needs.produce.outputs.summary }}
        run: |
          echo "Job output said: $SUMMARY"
          echo "Artifact contents:"
          cat report.txt
```

Push it, run it from the Actions tab, and study the run page: the two jobs are drawn as a graph with an arrow, the artifact appears at the bottom of the run summary, and the `consume` job shows the file contents produced by a completely different virtual machine.

## 4. Break something on purpose

Diagnosing failures is the real skill. Edit `produce-consume.yml` and change `needs: produce` to `needs: produces` (a typo), push, and look at the Actions tab. GitHub refuses the workflow with an error naming the unknown job. Fix it back.

Now make a step fail: add this step to the `consume` job, push and run.

```yaml
      - name: Fail on purpose
        run: |
          echo "About to fail"
          exit 1
```

The run turns red, the job log opens at the failing step, and the exit code appears in the log. Any step that exits non-zero fails the job, and jobs that need it are skipped. Delete the step, push, and rerun to see green again.

## Checklist

You can now:

- [ ] Put a workflow file in the right place and explain each of its keywords.
- [ ] Trigger a workflow by push and by manual dispatch, with an input.
- [ ] Read run logs and expand a failing step to find its error.
- [ ] Pass a string between jobs with outputs and `needs`, and a file with artifacts.
- [ ] Explain why expression values are passed through `env:` instead of interpolated into scripts.
- [ ] State the default GITHUB_TOKEN stance this course takes (`permissions: contents: read` on every workflow).

## Common failure modes

**The workflow does not appear in the Actions tab at all.**
The file is not on the default branch, is outside `.github/workflows/`, or has a YAML syntax error. GitHub shows syntax errors in the Actions tab under the workflow name; a common one is a tab character where YAML wants spaces.

**"Run workflow" button is missing.**
`workflow_dispatch` must be present in the version of the file that is on the **default branch**. Push it to `main` first, then look again.

**The conditional step ran (or did not) unexpectedly.**
Check `github.event_name` in the run logs against your `if:` expression. Remember string comparison is case-insensitive, but the event names themselves are exact: `workflow_dispatch`, not `dispatch`.

**`needs` job name typo.**
The workflow is rejected before running, with an error naming the missing job. Job identifiers are the YAML keys under `jobs:`, not the `name:` labels.

**Artifact download fails with "not found".**
The producing job must finish before the consumer starts (that is what `needs` guarantees), and the `name:` values on upload and download must match exactly.

Module 2 done. You can run automation on GitHub's machines; next you need a cloud worth automating. On to Azure.
