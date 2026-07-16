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

## Making changes

1. Fork and branch from `main`.
2. Keep changes scoped to the launcher/glue layer (herdr-fresh doesn't reimplement editor
   features — see PLAN.md §2.2 non-goals).
3. Match the existing script conventions (see AGENTS.md) — `common.sh`/`common.ps1` helpers
   instead of re-deriving config/context parsing, `-windows`-suffixed action ids for any new
   Windows action, docs updated alongside behavior changes.
4. Run the local checks in AGENTS.md's "Verifying changes locally" section before opening a PR.
   If you have real `herdr`+`fresh` installed, a `herdr plugin link` smoke test of the affected
   action is the most convincing verification — mention what you tested in the PR description.
5. Use [Conventional Commits](https://www.conventionalcommits.org/) for commit messages
   (`feat:`, `fix:`, `docs:`, etc.) — this repo uses semantic-release-style versioning off of
   them.

## Pull requests

Fill out `.github/PULL_REQUEST_TEMPLATE.md`. CI (`.github/workflows/ci.yml`) runs shellcheck,
manifest validation, a headless install smoke test, and PSScriptAnalyzer — all four need to pass.

## Code of conduct

Be respectful and constructive. This is a small project maintained in spare time; please be
patient with response times.
