# From Commit to Cloud

A hands-on course that takes an experienced IT professional from zero
knowledge of GitHub Actions, OpenTofu and Microsoft Azure to a working,
production-shaped deployment pipeline: commit OpenTofu code, a GitHub Actions
runner authenticates to Azure over OIDC (no stored cloud credentials,
anywhere), and the infrastructure is planned, reviewed, approved and built.

The course is a [Docusaurus 3](https://docusaurus.io/) site. All content is
markdown under [`docs/`](docs/), the hand-drawn SVG diagrams live in
[`static/img/diagrams/`](static/img/diagrams/), and the complete capstone
repository the course builds is in [`capstone/`](capstone/).

## Run the site locally

Requirements: Node.js 20 or newer.

```bash
npm ci
npm run start        # dev server with live reload at http://localhost:3000
```

Production build (also validates every internal link and anchor; the build
fails on broken ones):

```bash
npm run build
npm run serve        # serve the built site locally
```

## Deploy to GitHub Pages

The repository deploys itself from
[`.github/workflows/deploy-pages.yml`](.github/workflows/deploy-pages.yml),
which intentionally models what the course teaches: actions pinned to commit
SHAs, a least-privilege `GITHUB_TOKEN`, a build job separated from a deploy
job, and an OIDC-authenticated Pages deployment.

One-time setup: in the repository settings, under **Pages**, set the source
to **GitHub Actions**. Every push to `main` then builds and publishes the
site to `https://businessitsa.github.io/learning_github_actions/`.

Forking this for your own audience? Update `url`, `baseUrl`,
`organizationName` and `projectName` in
[`docusaurus.config.ts`](docusaurus.config.ts).

## Content maintenance

- Every factual claim was verified against official documentation on the
  dates recorded in [SOURCES.md](SOURCES.md). When versions move, re-verify
  against those pages; the course flags the places where documentation lag
  was already observed.
- Action SHA pins appear in Module 6, the capstone workflows, and the deploy
  workflow. Bump them deliberately (tag, then resolved SHA, then the comment).
- Diagrams are hand-edited SVG with a shared palette documented in a comment
  at the top of each file.

## Course map

1. **Foundations** - IaC, declarative thinking, how the tools fit
2. **GitHub Actions basics** - workflows, triggers, contexts, no cloud needed
3. **Azure for IaC** - identity, hierarchy, RBAC, least privilege
4. **OpenTofu fundamentals** - HCL, lifecycle, remote state with locking
5. **Wiring it together** - OIDC federation, gated environments, plan/apply
6. **Security deep dive** - pinning, tokens, scanning, protection, drift
7. **Capstone** - the complete pipeline, built and torn down by the learner
