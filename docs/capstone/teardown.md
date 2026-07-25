---
title: Teardown and what you can now do
description: Remove everything cleanly, verify the bill is zero, and take stock.
---

# Teardown and what you can now do

Infrastructure you can create but not confidently destroy is a liability. This chapter removes the capstone in layers, in the reverse order of its creation, and each layer uses the mechanism that owns it.

## 1. Destroy the managed environment, through the pipeline

Actions, then **Destroy**, then Run workflow. Type `destroy` into the confirmation input and run. The job stops at the `prod` gate, exactly like an apply, because destruction is a deployment too. Approve it.

Watch the run: a destroy plan (`6 to destroy`), then the apply of that plan. The Container Apps environment is again the slow resource; several minutes is normal. The run summary confirms an empty state at the end.

Verify as an operator:

```bash
az resource list --resource-group rg-capstone-prod --output table
```

No resources. The group itself remains, because the pipeline never owned it.

## 2. Remove the scaffolding, by hand

You made these with the setup script; unmake them with the CLI:

```bash
az group delete --name rg-capstone-prod --yes

az identity delete --name id-capstone-plan --resource-group rg-tofu-state
az identity delete --name id-capstone-apply --resource-group rg-tofu-state
```

Deleting the identities also deletes their federated credentials and orphans their role assignments (Azure cleans those up; if you are thorough, `az role assignment list --all --output table` lets you confirm nothing dangling remains).

## 3. Decide about the state backend

If you are continuing to use OpenTofu for your own work, keep `rg-tofu-state`; it is a correctly built, key-disabled, Entra-authenticated backend costing cents. If the course was the journey and this is the destination:

```bash
az group delete --name rg-tofu-state --yes
```

:::warning[This is the point of no return]

Deleting the state group deletes every state file in it, including your lab states. That is fine if the infrastructure they describe is already destroyed (it is, if you followed the teardowns). It is data loss if you skipped one: state is the only record OpenTofu has. Before running it, `az group list --output table` and make sure nothing unexplained survives outside `rg-tofu-state`.

:::

## 4. Final audit

The habit that keeps hobby subscriptions free:

```bash
az group list --output table
az resource list --output table
```

Empty (or containing only things you can name and want). The GitHub side keeps its repositories, workflows, secrets and history at no cost; the secrets are only identifiers, and the identities they identified no longer exist.

## What you can now do

The course-level checklist, deliberately demanding. You can now:

- [ ] Explain infrastructure as code, declarative convergence, state and drift to a colleague, with a whiteboard and no notes.
- [ ] Write GitHub Actions workflows from scratch: triggers, jobs, steps, contexts, expressions, artifacts, gated environments, and read their runs like logs you own.
- [ ] Draw Azure's identity and resource model, and place tenants, subscriptions, resource groups, managed identities and RBAC on the drawing.
- [ ] Write OpenTofu for real resources, with remote, locked, Entra-authenticated state, and run the plan and apply lifecycle with intent.
- [ ] Configure OIDC federation between GitHub and Azure, with split plan and apply identities, and explain to a security reviewer why no stored credential exists.
- [ ] Harden a pipeline layer by layer: pinned actions, minimised tokens, injection-safe scripts, branch rulesets, scanners, drift detection.
- [ ] Build, operate, evolve and destroy a production-shaped environment where every change is proposed, previewed, reviewed, approved, applied and audited.

## Common failure modes, one last time

**The destroy plan wants to destroy nothing.**
The state is empty or the backend block points at the wrong `key`. `tofu state list` locally (with `az login` and the backend configured) shows what the pipeline sees.

**Destroy fails mid-run with a dependency error.**
Azure occasionally releases child resources slowly; the classic is the Container Apps environment refusing deletion moments after its app vanished. Re-run the destroy workflow; the saved-plan pattern makes a second pass safe.

**`az group delete` on the state group hangs.**
A lease is still held on a state blob, usually by a run that died. Wait a minute, or break the lease in the portal (the storage account, the container, the blob, Break lease), then retry.

**Something still costs money next month.**
The final audit missed a subscription-level object or another resource group. Cost Management in the portal names the culprit resource directly; delete by name, and add its group to your mental checklist.

## Where to go next

Three worthy directions, in increasing ambition: swap the hello-world image for an application you build (a registry, image pipelines and revisions enter the story); wire the container app into the VNet properly (the /23 subnet, private ingress, and the paid-tier trade-offs the walkthrough deferred); or introduce a second environment (`staging`, with its own state key, identities, gate and subnet) and feel the design scale.

Thank you for building all of it. The pipeline you now understand is not a toy version of the real thing; it is the real thing, small.
