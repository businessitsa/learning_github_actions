---
title: Triggers, contexts and expressions
description: The events that start workflows and the data available inside them.
---

# Triggers, contexts and expressions

## The four triggers this course uses

The `on` key accepts dozens of event types. Four of them power the entire pipeline you are building, so learn these well and look the rest up when needed.

```yaml
# .github/workflows/trigger-reference.yml
name: Trigger reference
on:
  push:
    branches: [main]

  pull_request:
    branches: [main]

  workflow_dispatch:
    inputs:
      environment:
        description: Where to deploy
        type: choice
        options: [staging, production]

  schedule:
    - cron: '30 5 * * 1-5'

permissions:
  contents: read

jobs:
  show:
    runs-on: ubuntu-latest
    steps:
      - run: echo "Triggered by ${{ github.event_name }}"
```

**`push`** fires when commits land on a matching branch. In the pipeline, a push to `main` (which in practice means a merged pull request) triggers the apply workflow.

**`pull_request`** fires when a pull request against a matching base branch is opened or updated. This is where the plan runs: propose a change, see its consequences, before anything is real.

**`workflow_dispatch`** adds a "Run workflow" button in the Actions tab, with optional typed inputs. You will use it for deliberately manual operations, like the capstone's destroy workflow. Note: the button only appears once the workflow file exists on the default branch.

**`schedule`** runs on a cron expression (five fields: minute, hour, day of month, month, day of week). The example means 05:30 on weekdays. The shortest allowed interval is five minutes, schedules run in UTC unless you add a `timezone` key next to the cron line, and GitHub may delay scheduled runs by a few minutes under load. Module 6 uses a schedule for drift detection.

:::note

`pull_request` has a dangerous sibling called `pull_request_target` with elevated privileges. Never reach for it casually; Module 6 explains the trap.

:::

## Contexts: the data available to a run

Inside `${{ ... }}` you can read **contexts**: structured objects describing the run. The ones that matter for this course:

| Context | What it holds | Example |
|---|---|---|
| `github` | Everything about the event and repository | `github.actor`, `github.ref`, `github.sha`, `github.repository`, `github.event_name` |
| `secrets` | Encrypted values you store in repository or environment settings | `secrets.AZURE_CLIENT_ID` |
| `vars` | Non-secret configuration variables from settings | `vars.LOCATION` |
| `env` | Environment variables you defined | `env.TF_VERSION` |
| `needs` | Outputs and results of jobs this job depends on | `needs.plan.outputs.exitcode` |
| `steps` | Outputs of earlier steps in the same job | `steps.plan.outputs.stdout` |
| `inputs` | Values from `workflow_dispatch` inputs | `inputs.environment` |
| `runner` | Facts about the machine | `runner.os` |

Two of these deserve a closer look now.

**`github.ref`** is the fully qualified Git reference the run is for, such as `refs/heads/main` or `refs/tags/v2`. Azure will later match against this exact string when deciding whether to trust a token from your pipeline, so remember its shape.

**`secrets`** values are write-only through the UI, encrypted at rest, and masked if they appear in logs. In this course secrets hold only Azure **identifiers** (client, tenant and subscription IDs). Treat them as secrets anyway; defense in depth costs nothing here.

## Expressions

Expressions combine contexts with operators and functions. They work in most YAML values and in the `if` key that conditionally skips jobs or steps.

```yaml
# .github/workflows/expressions-demo.yml
name: Expressions demo
on: push

permissions:
  contents: read

jobs:
  demo:
    runs-on: ubuntu-latest
    steps:
      - name: Only on main
        if: github.ref == 'refs/heads/main'
        run: echo "This is the main branch"

      - name: String helpers
        run: echo "${{ format('repo is {0}', github.repository) }}"

      - name: Dump the github context as JSON
        env:
          GH_CONTEXT: ${{ toJSON(github) }}
        run: echo "$GH_CONTEXT"
```

Useful pieces, in the order you will need them:

- Comparison and logic: `==`, `!=`, `<`, `>`, `&&`, `||`, `!`. String comparison is case-insensitive.
- `contains()`, `startsWith()`, `endsWith()`, `format()`, `join()`.
- `toJSON()` and `fromJSON()` convert between objects and strings.
- `hashFiles('**/package-lock.json')` fingerprints files, used for cache keys.
- Status functions for steps that should run on failure or always: `success()`, `failure()`, `always()`, `cancelled()`. A cleanup step with `if: always()` runs even when an earlier step failed.

:::warning[The one habit to build now]

Look again at the "Dump the github context" step. The value goes into an **environment variable first**, and the shell reads the variable. Never write `run: echo "${{ toJSON(github) }}"` directly: expression values are pasted into the script **before** the shell runs, so attacker-influenced values (a pull request title, a branch name) can inject commands. Passing through `env:` keeps untrusted data out of the script text. The course follows this pattern everywhere, and Module 6 shows the actual attack.

:::

## Passing data between steps and jobs

Steps communicate through **outputs**. A step writes `name=value` to the file GitHub provides in `$GITHUB_OUTPUT`, and later steps read it via the `steps` context. Jobs re-export step outputs through the `outputs` key, and downstream jobs declare `needs` to read them:

```yaml
# .github/workflows/outputs-demo.yml
name: Outputs demo
on: push

permissions:
  contents: read

jobs:
  produce:
    runs-on: ubuntu-latest
    outputs:
      build-id: ${{ steps.gen.outputs.build-id }}
    steps:
      - name: Generate an ID
        id: gen
        run: echo "build-id=build-$(date +%s)" >> "$GITHUB_OUTPUT"

  consume:
    runs-on: ubuntu-latest
    needs: produce
    steps:
      - name: Use the ID
        env:
          BUILD_ID: ${{ needs.produce.outputs.build-id }}
        run: echo "Received $BUILD_ID"
```

`needs` does two jobs at once: it orders the jobs (consume waits for produce) and it carries the data. In Module 5, a plan job will pass its computed plan to an apply job in exactly this shape, with one addition: because jobs run on separate fresh machines, files (as opposed to small string outputs) travel between jobs as **artifacts**, uploaded by one job and downloaded by the next. The lab tries both.

That is all the theory Module 2 needs. Time to run some workflows.
