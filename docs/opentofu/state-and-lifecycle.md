---
title: State and the change lifecycle
description: init, plan, apply, destroy, and the state file that makes it all work.
---

# State and the change lifecycle

![The OpenTofu change cycle: edit files, plan computes the diff against state, a human reviews, apply executes and records the new reality](/img/diagrams/tofu-lifecycle.svg)

## The five commands

**`tofu init`**, once per new configuration (and after backend or provider changes). It downloads the declared providers, verifies their checksums into a **lock file** called `.terraform.lock.hcl` (commit that file: it pins exact provider builds for everyone), and wires up state storage. Everything lands in a `.terraform/` directory that must **not** be committed.

**`tofu validate`** checks syntax and internal consistency without touching the cloud or state. Cheap, fast, and the first thing the pipeline runs.

**`tofu plan`** is the heart of the model. It reads your configuration, reads the recorded state, **refreshes** by asking Azure what actually exists, and prints the exact difference as a set of planned actions:

```text
Plan: 2 to add, 1 to change, 0 to destroy.
```

Each resource line is prefixed `+` (create), `~` (update in place), `-` (destroy), or `-/+` (destroy and recreate, worth a hard look every time). Because plan refreshes against reality, **drift shows up here**: a manual portal change appears as a difference even though your code never changed.

**`tofu apply`** executes. Run bare, it computes a fresh plan and asks for interactive confirmation. In automation you split the steps: `tofu plan -out=tfplan` saves the exact plan to a file, and `tofu apply tfplan` executes precisely that plan with no prompt and no surprises, even if reality moved in between. The pipeline in Module 5 uses this two-step form.

**`tofu destroy`** plans and executes the removal of everything the state knows about. Terrifying and essential; the capstone teardown uses it deliberately.

One more you will run constantly: **`tofu fmt`** rewrites files into canonical formatting. The pipeline runs `tofu fmt -check` and fails on unformatted code, so make formatting a reflex.

:::note[Two flags the pipeline relies on]

`tofu plan -detailed-exitcode` changes the exit code into a three-way signal: **0** means no changes, **1** means error, **2** means changes are present. Automation uses it to distinguish "nothing to do" from "something would change", which is exactly how drift detection works in Module 6.

`tofu plan -out=FILE` writes the plan file mentioned above. Treat that file as sensitive: it can embed values from your configuration and state **in clear text**.

:::

## What state is, precisely

After the first apply, OpenTofu writes `terraform.tfstate` (the historical name, in JSON): its record of every resource it manages, mapping your HCL addresses like `azurerm_resource_group.lab` to real Azure resource IDs, along with each resource's last-known attributes and dependency order.

State exists because the alternative is worse. Without it, the tool could not reliably tell "create this" from "this already exists", could not know what to delete when you remove a block from the code, could not destroy things in the correct reverse order, and would have to interrogate the entire cloud on every plan.

Three practical consequences:

1. **State is the source of truth about ownership.** If state is lost, OpenTofu forgets it manages your resources; they keep existing, unmanaged. (Recovery is possible with `tofu import`, but you do not want that day.)
2. **State can contain secrets.** Any sensitive attribute a provider returns (connection strings, generated keys) is stored in plain text. Protect state like a credential store: strict access control, and optionally encryption (Module 6).
3. **Concurrent writers corrupt state.** Two applies at once is how state files die, which is why locking exists, next page.

Inspect state safely with read-only commands rather than opening the JSON:

```bash
tofu state list                          # every resource address in state
tofu state show azurerm_resource_group.lab   # full recorded attributes of one
```

## Keep state out of Git

A local state file next to your code is fine for a solo experiment and wrong for everything else, and it must never be committed: it is unmergeable JSON that may contain secrets. Add the standard ignores before your first apply:

```text
# .gitignore
.terraform/
*.tfstate
*.tfstate.*
*.tfplan
crash.log
```

(OpenTofu also has **workspaces**, multiple states from one configuration. The official docs themselves warn they are not an isolation mechanism for deployments needing separate credentials, and this course does not use them; separate directories with separate state per environment is the clearer pattern at this scale.)

Local state's real limitation is the word "local": your laptop is now the single point of failure for production infrastructure, and no pipeline can reach it. Next page fixes that properly.
