---
title: OIDC, the end of stored cloud secrets
description: How a workflow job proves its identity to Azure with a short-lived signed token.
---

# OIDC, the end of stored cloud secrets

Here is the problem, stated plainly. Your pipeline needs to authenticate to Azure. The traditional answer was a service principal with a **client secret**: a long-lived password stored in GitHub's secret store. It works, and it is a liability from day one: it can leak into logs or forks, whoever holds it can use it from anywhere on the internet, it expires at the worst moment or never, and rotating it is a manual chore everyone defers. Microsoft's own documentation now labels that method "not recommended."

The current answer removes the stored credential entirely. **OpenID Connect** (OIDC) is an open standard for one party issuing signed, verifiable identity tokens that another party can choose to trust. GitHub runs an OIDC **identity provider** for Actions: any workflow job can request a token that cryptographically states *which repository, branch or environment, and workflow* it is. Azure can be configured, in advance and by you, to trust tokens carrying exactly one specific identity statement.

![OIDC token exchange, step by step: the job requests an ID token from GitHub, exchanges the signed JWT at Microsoft Entra ID, which checks it against the federated credential and returns a short-lived access token](/img/diagrams/oidc-token-exchange.svg)

## The exchange, step by step

1. **The job requests an ID token.** This requires one permission in the workflow: `id-token: write`. The docs are careful about what that means: it grants the ability to *request the token*, nothing else; it is not write access to any resource.
2. **GitHub's OIDC provider returns a signed JWT.** A JSON Web Token: a small signed document of **claims**. The issuer claim is always `https://token.actions.githubusercontent.com`. The claim that carries the job's identity is the **subject** (`sub`), and its format is worth memorising because you will type it into Azure:

   | The job ran because of | Subject claim format |
   |---|---|
   | A job bound to environment `prod` | `repo:ORG/REPO:environment:prod` |
   | A push to branch `main` (no environment) | `repo:ORG/REPO:ref:refs/heads/main` |
   | A pull request | `repo:ORG/REPO:pull_request` |

   There is `refs/heads/main` again, exactly as you saw it in Lab 2's logs.

3. **The job presents the JWT to Microsoft Entra ID**, along with the client ID of the Azure identity it wants to become and your tenant ID.
4. **Entra ID checks the token against a federated credential.** A **federated credential** is a rule you attach to an Azure identity in advance, saying: trust tokens whose issuer, subject and audience match these exact strings. The conventional audience value for this scenario is `api://AzureADTokenExchange`. Issuer, subject, audience: all three must match.
5. **Entra ID returns a short-lived Azure access token**, valid for roughly an hour, carrying whatever RBAC roles the identity holds. The job uses it for OpenTofu's calls to Azure Resource Manager, and it evaporates when the job ends.

## Why this is materially safer

Count what exists and where:

- **In GitHub secrets:** the client ID, tenant ID and subscription ID. These are identifiers, not credentials. Alone, they authenticate nothing.
- **On the runner:** two short-lived tokens that expire within the hour, minted fresh for this one job.
- **Stored anywhere, long-lived:** nothing.

An attacker who exfiltrates your GitHub secrets gets identifiers they cannot use, because Entra ID will only complete the exchange for a JWT that GitHub will only sign for a job actually running in your repository under your matching branch, environment or pull request. The trust is between systems and is verified per-job, per-hour.

## The strictness that will bite you (once)

Federated credential matching is **exact, silent and unforgiving**, and the official docs say so: no wildcards anywhere, and a subject that does not match character-for-character simply fails to authenticate. There is no "almost matched" diagnostic on the Azure side. If your credential says `environment:prod` and the job runs without an environment, or the repository was renamed, or the environment is spelled `Prod`, the exchange fails.

Practical consequences the next two pages build in:

- You will create **one federated credential per trigger context**: one for the `prod` environment (the apply), one for pull requests (the plan). An identity can hold up to 20.
- The failure mode to expect while learning is an Entra error stating no matching federated identity record was found. When you see it, diff your credential's subject against the workflow's actual context, character by character.

:::tip[Subject strings are a security boundary]

Read the three subject formats again with an attacker's eyes. `repo:ORG/REPO:environment:prod` means: only jobs that passed the `prod` environment's protection rules (a human approval, in our setup) can become the identity holding write power. The pull request credential, by contrast, will be handed out to any PR job in the repo, which is precisely why the plan-time identity's power must be modest and why plans never apply. The subject format is not plumbing; it is policy.

:::

Next: creating the Azure identity and its federated credentials.
