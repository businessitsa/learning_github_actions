# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

A Docusaurus 3 learning website, "From Commit to Cloud": a seven-module course taking a beginner from zero knowledge of GitHub Actions, OpenTofu and Microsoft Azure to a working OIDC-authenticated deployment pipeline. Content was verified against official documentation on the dates in `SOURCES.md`.

## Structure

- `docs/` — all course content (markdown/MDX), one folder per module; sidebar order is explicit in `sidebars.ts`.
- `static/img/diagrams/` — hand-authored SVG diagrams sharing one visual system (palette documented in a comment at the top of each file). No mermaid, no external images.
- `capstone/` — the complete worked repository learners copy for Module 7 (OpenTofu code, four workflows, a setup script). It is course material, not executed from here.
- `docusaurus.config.ts` — docs-only mode (`routeBasePath: '/'`), `onBrokenLinks: 'throw'`.
- `.github/workflows/deploy-pages.yml` — deploys the site to GitHub Pages; SHA-pinned actions, split build/deploy jobs.
- `.github/workflows/github-actions-demo.yml` — the original sandbox demo workflow; harmless, runs on every push.
- `SOURCES.md` — official documentation pages each module relied on, with retrieval dates.

## Commands

- `npm run start` — dev server with live reload.
- `npm run build` — production build; **run this after any content change**, it fails on broken links/anchors and MDX errors.

## Content conventions (enforced across the course)

- Plain, direct prose; jargon explained on first use; **no em dashes**.
- All code samples complete and runnable; YAML/HCL blocks start with a file-path comment.
- OpenTofu naming throughout (`tofu`, never `terraform` as a command).
- Security stance: OIDC only, no long-lived credentials anywhere, least-privilege everywhere; actions in Module 6+ and the capstone are pinned to commit SHAs (resolve new pins via the GitHub git-refs API, keep the `# vX.Y.Z` comment).
- MDX 3: escape `{` and `<` in prose (or use inline code); fenced code blocks are safe for `${{ }}`.
- Every module ends with a lab, a checklist, and common failure modes with fixes; anything costing money carries a `:::warning[Money]` admonition.
- Unverifiable claims are flagged inline as needing learner verification, never presented as fact.
