# Contributing to herdr-fresh

Thanks for taking a look! This is a small, personal-itch project, so the bar for contributing is
low, but a few things help keep it maintainable.

## Before you start

- Read [PLAN.md](PLAN.md) for the design/architecture and [AGENTS.md](AGENTS.md) for
  contributor conventions (script style, config trust model, action-id rules) — both apply to
  human contributors too, not just agents.
- Check the [milestones in PLAN.md §6](PLAN.md#6-milestones) and the
  [post-v1 backlog](PLAN.md#post-v1-backlog) to see what's already planned/tracked before opening
  a new issue for it.

## Filing issues

Use the templates under `.github/ISSUE_TEMPLATE/`. In particular, for anything Windows-related
please mention your herdr/PowerShell version — Windows support is a preview
(see [docs/windows.md](docs/windows.md)) and hasn't had the same `herdr plugin link` verification
pass Linux/macOS has.

## Branching & release model

This project uses a **trunk-based workflow**:

- **`main` is the trunk** — always releasable, protected (no direct pushes; PRs + green CI
  required). Every merged PR advances `main`; merging does **not** create a release.
- **Work happens on short-lived branches** off `main` — one per change, named for its scope
  (`feat/notify-helper`, `test/bats-harness`, `fix/daemon-detection`). Open a PR, let CI run,
  squash-merge, delete the branch.
- **Releases are tags, cut deliberately from `main`** — not on every merge. Land as many PRs as
  you like, then when `main` is where you want it, tag `vX.Y.Z` (semver). The release workflow
  handles the rest (see below). To see what's queued for the next release at any time:
  `git log <latest-tag>..main --oneline`, or read the `## [Unreleased]` section of
  [CHANGELOG.md](CHANGELOG.md).
- **Pre-releases** (`vX.Y.Z-rc.1`) are available when you want a staging signal for testers to
  `herdr plugin install` a candidate ref before the real release.

> **Why not a `develop` branch?** herdr installs this plugin from a git ref/tag, so a *tag* is
> already the production boundary — a long-lived `develop`/`main` split would add a second,
> redundant "production" marker plus a merge hop, without the payoff (this is a small, near-solo
> project with a linear release history and no parallel supported versions). If that changes —
> several regular contributors needing a shared integration buffer, or maintaining an old version
> alongside a new one — introduce `develop` at that point: branch it from `main`, target PRs at
> it, and promote `develop → main` per release. Until then, PR CI is the integration gate.

## Making changes

1. Branch from `main` (fork first if you don't have push access).
2. Keep changes scoped to the launcher/glue layer (herdr-fresh doesn't reimplement editor
   features — see PLAN.md §2.2 non-goals).
3. Match the existing script conventions (see AGENTS.md) — `common.sh`/`common.ps1` helpers
   instead of re-deriving config/context parsing, `-windows`-suffixed action ids for any new
   Windows action, docs updated alongside behavior changes.
4. Run the local checks in AGENTS.md's "Verifying changes locally" section before opening a PR.
   If you have real `herdr`+`fresh` installed, a `herdr plugin link` smoke test of the affected
   action is the most convincing verification — mention what you tested in the PR description.
5. Add a bullet under `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md) describing your change.
6. Use [Conventional Commits](https://www.conventionalcommits.org/) for commit messages
   (`feat:`, `fix:`, `docs:`, etc.) — this repo uses semantic-release-style versioning off of
   them.

## Pull requests

Fill out `.github/PULL_REQUEST_TEMPLATE.md`. CI (`.github/workflows/ci.yml`) runs shellcheck,
manifest validation, a headless install smoke test, and PSScriptAnalyzer — all must pass before a
PR can merge to `main`.

## Code of conduct

Be respectful and constructive. This is a small project maintained in spare time; please be
patient with response times.
