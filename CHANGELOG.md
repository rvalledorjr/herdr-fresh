# Changelog

All notable changes to herdr-fresh are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Under the project's trunk-based workflow (see [CONTRIBUTING.md](CONTRIBUTING.md)), every PR adds a
bullet under `## [Unreleased]`. Cutting a release renames that section to the new version and
starts a fresh `Unreleased`.

## [Unreleased]

### Added
- `docs/plans/production-readiness.md`: an agent-handoff execution plan taking herdr-fresh from
  Linux-verified preview to a v1.0.0 production release (milestones M8–M12, self-contained task
  cards with statuses, dependencies, acceptance criteria, and verification commands).
- `CHANGELOG.md` (this file), backfilled from the M0–M7 milestone history.
- Trunk-based branching & release model documented in `CONTRIBUTING.md`.

### Changed
- `PLAN.md` now links to `docs/plans/` and identifies itself as the design-of-record.

## [0.1.1] - 2026-07-17

### Fixed
- **Silent split-pane failure:** dropped `--cwd` from the `herdr plugin pane open` calls in
  `open-fresh.sh`/`open-fresh-tab.sh`. herdr resolved the `[[panes]]` entry's relative command
  against `--cwd` (the target repo) rather than the plugin root, so the pane spawned and
  immediately exited (code 127) — the split just flashed and closed. herdr now defaults the
  pane cwd to the plugin root, and `run-fresh-daemon.sh`'s own `cd` moves Fresh into the target
  directory afterward.
- **Cross-workspace targeting:** split/tab placement now derives the invoking pane/tab/workspace
  from `HERDR_PLUGIN_CONTEXT_JSON` (`focused_pane_id`/`tab_id`/`workspace_id`) instead of
  `herdr pane current`, which reflected whatever pane the detached herdr CLI subprocess was
  globally focused on. Invoking an action from a non-focused workspace no longer targets the
  wrong workspace.

## [0.1.0] - 2026-07-17

### Added
- Initial public release: a herdr plugin that runs [Fresh](https://getfresh.dev) as an editor
  inside a herdr pane.
- `open-fresh` action — open Fresh in a split beside the current pane (idempotent focus if
  already open).
- `open-fresh-tab` action — open Fresh in its own tab (focus if already open).
- `open-file-in-fresh` action — push `path:line:col` into the running per-workspace Fresh daemon,
  opening the pane first if needed.
- Persistent per-workspace editing sessions via named Fresh daemons (`fresh -a <daemon>`),
  surviving pane close/reattach.
- Optional `config.toml` (`fresh_bin`/`fresh_args`, `daemon_name`/`daemon_name_prefix`) parsed via
  python3 `tomllib`, read only from the herdr-provided config dir (never a repo's cwd).
- Opt-in `suggest-editor-integration.sh` helper for registering Fresh as `core.editor`.
- Cross-platform Windows launchers (`.ps1`) with `-windows`-suffixed action ids (preview status).
- `[[build]]` steps that auto-install Fresh (official installer / winget) when missing.
- CI: shellcheck, manifest validation, headless install smoke test, PSScriptAnalyzer.
- Docs: install, usage, configuration, editor-integration, windows, architecture; plus
  `AGENTS.md`, `CONTRIBUTING.md`, `SECURITY.md`, and issue/PR templates.

[Unreleased]: https://github.com/rvalledorjr/herdr-fresh/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/rvalledorjr/herdr-fresh/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/rvalledorjr/herdr-fresh/releases/tag/v0.1.0
