---
title: Workflow anatomy
description: Workflows, events, jobs, steps and runners, and where each piece lives.
---

# Workflow anatomy

GitHub Actions is GitHub's automation service. You describe **workflows** in YAML files, commit them to your repository, and GitHub runs them on its own virtual machines when the events you named occur. Nothing to install, nothing to host.

![Anatomy of a workflow: events trigger workflows, workflows contain jobs, jobs contain steps, steps run on runners](/img/diagrams/workflow-anatomy.svg)

## Where workflows live

Workflow files go in one exact place: the `.github/workflows/` directory at the root of the repository. The file name is yours to choose; the `.yml` extension is required. A repository can contain many workflow files, and each one is an independent automation.

Here is a complete, real workflow. Read it top to bottom; every keyword is explained below.

```yaml
# .github/workflows/hello.yml
name: Hello
run-name: Hello run started by ${{ github.actor }}

on:
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  greet:
    runs-on: ubuntu-latest
    steps:
      - name: Check out the repository
        uses: actions/checkout@v7

      - name: Say hello
        run: echo "Hello from commit ${{ github.sha }} on ${{ github.ref }}"
```

## The keywords, one by one

**`name`** labels the workflow in the Actions tab. **`run-name`** labels each individual run and may use expressions, like the username of whoever triggered it.

**`on`** declares the **events** that trigger the workflow. Here it is a push to the `main` branch. The next page covers the trigger types you will actually use.

**`permissions`** controls what the workflow's built-in GitHub credential is allowed to do. Every job automatically receives a token called `GITHUB_TOKEN` for talking to the GitHub API. Least privilege applies from your very first workflow, so this course always declares permissions explicitly. `contents: read` means "this job may read the repository and nothing more." One rule worth memorising: as soon as you specify **any** permission, every permission you did not mention becomes `none`.

**`jobs`** is a map of one or more **jobs**. Each job gets a fresh virtual machine and runs independently. By default all jobs in a workflow run in parallel; you create ordering with `needs`, covered in the lab.

**`runs-on`** picks the virtual machine image, called a **runner**. GitHub-hosted options as of July 2026:

| Label | What you get |
|---|---|
| `ubuntu-latest` | Ubuntu 24.04, x64, 4 vCPU, 16 GB RAM |
| `windows-latest` | Windows Server 2025, x64, 4 vCPU, 16 GB RAM |
| `macos-latest` | macOS 15 on arm64 (Apple Silicon), 3 vCPU, 7 GB RAM |

Standard runners are **free with no minute limit for public repositories**. Private repositories get a monthly free allowance before billing starts. This course uses `ubuntu-latest` everywhere; it is the fastest to start and everything we run is Linux-friendly.

**`steps`** is the ordered list of things the job does. Steps run sequentially on the same machine, so files created by one step are visible to the next. A step is one of two kinds:

- **`run`** executes shell commands. On Linux runners the default shell is bash.
- **`uses`** invokes an **action**: a reusable, published unit of automation. `actions/checkout` is the one you will see most; a fresh runner starts empty, and checkout clones your repository onto it. The part after `@` selects a version.

:::warning[Version references are a security decision]

`actions/checkout@v7` refers to a Git tag, and tags can be moved by whoever controls that repository. Convenient for learning, but for production pipelines the only immutable reference is a full commit SHA. Module 6 converts everything you have built to pinned SHAs and explains the attack this prevents. Until then, the course uses major version tags of official `actions/*` actions only.

:::

**`env`** (not shown above) defines environment variables, at workflow, job or step level. **`defaults`** sets default shell or working directory. **`concurrency`** stops runs of the same workflow from overlapping; it becomes important the moment OpenTofu enters the picture, and Module 5 uses it.

## Watching a run

When a workflow triggers, the **Actions** tab of the repository shows the run: every job, every step, and the live log output of each. When something fails, the failing step is expanded with its error. Reading these logs is a skill the labs deliberately exercise, because a failed `tofu plan` in Module 5 will be diagnosed exactly the same way as a failed `echo` today.

You now know what a workflow is made of. Next: the events that start one, and the data available inside it.
