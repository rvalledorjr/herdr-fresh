# herdr-fresh — Project Plan

**A herdr plugin that runs [Fresh](https://getfresh.dev), the terminal IDE, as a file viewer
*and* editor inside a herdr pane.**

The plugin ships only the thin integration layer around Fresh — a manifest, a few launcher
scripts, and config — and lets Fresh provide the editor itself: viewing, editing, LSP, Git
review, search/replace, and remote editing, with almost no code of our own to maintain.

---

## 1. Motivation

This is a personal itch-solution. I wanted a real editor living inside a herdr pane — one that
can actually edit, not just view — with the features I already rely on: LSP, Git review,
multi-cursor, project-wide search/replace, and remote editing over SSH. [Fresh](https://getfresh.dev)
is exactly that editor and it runs in a terminal.

So instead of writing an editor, this project writes a **launcher**: a herdr plugin whose entire
job is to open Fresh in the right place, wire it into herdr's workspace/keybinding model, and
expose the one capability I most want — *"open this file at this line in my editor pane, now."*

What Fresh already provides (so we don't have to):

- Instant startup, multi-GB files, small memory footprint.
- Git review & diff (staged/unstaged/untracked, per-hunk stage/discard, line comments, side-by-side).
- LSP (multiple servers per language, feature routing, merged completions).
- File explorer, command palette, project-wide search & replace, code folding, multi-cursor.
- **Detachable named daemons** that survive terminal disconnects (`fresh -a <name>`).
- **Remote editing over SSH** with background reconnect and patch-only saves.
- Themes, i18n, TypeScript plugins (sandboxed QuickJS).

---

## 2. Goals & Non-Goals

### 2.1 Goals (v1)

1. **`herdr plugin install rvalledorjr/herdr-fresh`** works end-to-end.
2. One keypress opens Fresh in a **split** beside the current pane.
3. One keypress opens Fresh in its own **tab** (idempotent: focus if already open).
4. A **"open file at line"** action so herdr / other tools can push `path:line:col` into the
   *already-running* Fresh pane.
5. **Persistent editing sessions**: one Fresh daemon per herdr workspace, surviving pane
   close/reattach.
6. Optional: register Fresh as `$EDITOR` / `$GIT_EDITOR` for herdr's agent panes (`fresh --wait`).
7. Honor Fresh's Workspace Trust model when opening untrusted repos.
8. Cross-platform: Linux + macOS first-class; Windows preview.

### 2.2 Non-Goals (v1)

- We do **not** reimplement any editor feature. If Fresh can't do it, it's out of scope.
- We do **not** fork or patch Fresh. We integrate via its documented CLI/daemon surface only.
- We do **not** ship Fresh's binary in-repo. The build step installs/locates it.
- No custom rendering, no bespoke TUI. Fresh is the UI.

---

## 3. Background: the two integration surfaces (verified locally)

Verified against **herdr 0.7.0** and **fresh 0.4.1** installed on the dev machine.

### 3.1 herdr plugin model

- A plugin is a repo with a **`herdr-plugin.toml`** manifest declaring:
  - `id`, `name`, `version`, `description`, `min_herdr_version`, `platforms`.
  - `[[build]]` — command herdr runs at install time (per-platform, gated by `platforms`).
  - `[[panes]]` — a pane definition with `id`, `title`, `placement` (`split`), and `command`.
  - `[[actions]]` — invocable commands (each a UNIQUE id even across platforms; herdr rejects
    duplicate action ids at load time). Bound to keys in `~/.config/herdr/config.toml`.
- Actions run a shell `command`; they receive a launch context via the
  **`HERDR_PLUGIN_CONTEXT_JSON`** env var (cwd, workspace, etc.) and **`HERDR_BIN_PATH`** points
  at the herdr binary for socket-API calls.
- Relevant CLI seams for the launcher scripts:
  - `herdr pane split [--direction right|down] [--ratio F] [--cwd PATH] [--env K=V] [--focus]`
  - `herdr pane run <pane_id> <command>`
  - `herdr pane list` / `pane current` / `pane focus` / `pane zoom`
  - `herdr tab <subcommand>` for the tab variant
  - `herdr plugin list --json` (locate our own plugin root; needed on Windows)
  - `herdr plugin action invoke <id> --plugin <plugin_id>`
- Config keybinding pattern:
  ```toml
  [[keys.command]]
  key = "prefix+e"
  type = "shell"
  command = "herdr plugin action invoke open-fresh --plugin herdr-fresh"
  ```

### 3.2 Fresh CLI / daemon model

From `fresh --help` and `fresh --cmd daemon`:

- `fresh [FILES]...` — opens files; supports **`file:line:col`**, ranges, and `@"message"`.
- `fresh -a [NAME]` — **attach to a daemon**; `-a` alone = current dir, `-a NAME` = named daemon.
- `fresh --cmd daemon (list|attach|new|kill|info|open-file)` — daemon control.
  - `fresh --cmd daemon list` — lists running daemons.
  - `fresh --cmd daemon open-file <daemon> <file:line:col>` — **push a file into a live daemon.**
  - `fresh --cmd daemon info <daemon>` — daemon status.
- `fresh --wait` — blocks until the buffer closes → usable as `core.editor` / `$GIT_EDITOR`.
- `fresh --config <PATH>`, `--no-plugins`, `--safe`, `--locale`, `--no-restore`.

### 3.3 Gotchas discovered during research

1. **`fresh --cmd daemon new <name>` fails with `os error 6` (ENXIO) when run without a TTY.**
   Daemons expect to spawn attached to a pseudo-terminal. **Consequence:** the launcher must
   start Fresh *inside* the herdr pane (which owns a PTY) via `fresh -a <name>`, and must NOT
   pre-create daemons from a headless action script. The first `fresh -a <name>` inside the pane
   creates the daemon; subsequent `open-file` calls target it by name.
2. **`daemon open-file` needs the daemon to already exist.** So "open file at line" must
   (a) ensure the workspace's Fresh pane is open (invoke `open-fresh` if the daemon isn't in
   `daemon list`), then (b) `daemon open-file`.
3. **Windows relative-command spawn is broken in herdr** (documented in the herdr plugin
   ecosystem): `CreateProcessW` resolves relative program against herdr's own dir; herdr reports
   plugin root as a `\\?\` verbatim path and doesn't append `.exe`. So Windows actions locate the
   launcher by absolute path via `herdr plugin list --json`, and there is no Windows `[[panes]]`
   entry.
4. **Duplicate action ids are rejected at load regardless of platform** — so Windows actions get
   `-windows`-suffixed ids.

---

## 4. Architecture

```
herdr → invokes action (keybinding)
          │
          ▼
   scripts/open-fresh.sh                     (POSIX sh / bash; PowerShell on Windows)
          │  reads HERDR_PLUGIN_CONTEXT_JSON (cwd, workspace id) + HERDR_BIN_PATH
          │  derives a stable daemon name:  fresh-<workspace-id>
          ▼
   herdr pane split --direction right --cwd <repo-root> --focus
          │  → new pane id
          ▼
   herdr pane run <pane_id>  "fresh -a fresh-<workspace-id>"
          │
          ▼
   Fresh boots INSIDE the pane's PTY, attaching/creating the named daemon.
   Persists across pane close via Fresh Hot Exit + daemon; reattach re-runs the same command.
```

For **open-file-at-line**:

```
scripts/open-file-in-fresh.sh  <path:line:col>
   │  daemon="fresh-<workspace-id>"
   │  if daemon not in `fresh --cmd daemon list`:
   │        invoke open-fresh (create the pane), wait for readiness
   │  fresh --cmd daemon open-file "$daemon" "<path:line:col>"
   │  herdr pane focus  → bring the Fresh pane forward
   ▼
   File appears at the requested line in the live editor.
```

### 4.1 Repository layout

```
herdr-fresh/
├── PLAN.md                       ← this document
├── README.md                     ← front door (install, keybindings, quick start)
├── LICENSE                       ← MIT
├── herdr-plugin.toml             ← the manifest
├── config.example.toml           ← optional plugin config (daemon naming, fresh_bin/fresh_args)
├── scripts/
│   ├── install.sh                ← [[build]] unix: ensure `fresh` present (installer or check)
│   ├── install.ps1               ← [[build]] windows
│   ├── open-fresh.sh             ← action: split-pane launch
│   ├── open-fresh-tab.sh         ← action: tab launch (idempotent focus-if-open)
│   ├── open-file-in-fresh.sh     ← action: push file:line into live daemon
│   ├── suggest-editor-integration.sh ← optional: git core.editor "fresh --wait" helper
│   ├── open-fresh.ps1            ← windows variants …
│   ├── open-fresh-tab.ps1
│   └── open-file-in-fresh.ps1
├── docs/
│   ├── install.md
│   ├── usage.md                  ← split vs tab, open-at-line, daemon lifecycle
│   ├── configuration.md          ← config.toml reference + fresh_bin/daemon_name
│   ├── editor-integration.md     ← Fresh as $EDITOR / core.editor in herdr agent panes
│   ├── windows.md                ← preview specifics
│   └── architecture.md
├── .github/
│   ├── workflows/ci.yml          ← shellcheck + manifest lint + install smoke test
│   ├── ISSUE_TEMPLATE/
│   └── PULL_REQUEST_TEMPLATE.md
├── AGENTS.md                     ← contributor/agent guidance
├── CONTRIBUTING.md
└── SECURITY.md                   ← trust model: untrusted repos + Fresh Workspace Trust
```

### 4.2 Daemon naming strategy

- Name pattern: `fresh-<herdr-workspace-id>` (fall back to a hash of the repo root if no
  workspace id in context).
- Guarantees: one persistent editor per workspace; reopening the pane reattaches rather than
  spawning a second editor; `open-file` always has a deterministic target.
- Configurable via `config.example.toml` (`daemon_name_prefix`, or `daemon_name = "per-repo"`).

---

## 5. The manifest (`herdr-plugin.toml`) — draft shape

```toml
id = "herdr-fresh"
name = "herdr-fresh"
version = "0.1.0"
description = "Run Fresh, the terminal IDE, as a file viewer and editor inside a herdr pane."
min_herdr_version = "0.7.0"
platforms = ["linux", "macos", "windows"]

[[build]]
platforms = ["linux", "macos"]
command = ["/bin/sh", "scripts/install.sh"]

[[build]]
platforms = ["windows"]
command = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts/install.ps1"]

[[panes]]
id = "fresh"
title = "Fresh"
placement = "split"
command = ["bash", "scripts/open-fresh.sh", "--in-pane"]   # runs `fresh -a <daemon>` in the PTY

[[actions]]
id = "open-fresh"
platforms = ["linux", "macos"]
title = "Open Fresh (split)"
description = "Open the Fresh editor in a split pane beside the current work."
command = ["bash", "scripts/open-fresh.sh"]

[[actions]]
id = "open-fresh-tab"
platforms = ["linux", "macos"]
title = "Open Fresh (tab)"
description = "Open Fresh in its own tab (focus it if already open)."
command = ["bash", "scripts/open-fresh-tab.sh"]

[[actions]]
id = "open-file-in-fresh"
platforms = ["linux", "macos"]
title = "Open file in Fresh"
description = "Push path:line:col into the running Fresh daemon for this workspace."
command = ["bash", "scripts/open-file-in-fresh.sh"]

# … -windows-suffixed variants use an absolute-path launcher located via `plugin list --json`.
```

> Exact keys (`placement`, pane-command semantics, action-arg passing) will be confirmed against
> herdr 0.7.0 behavior during Milestone 1 by `herdr plugin link`-ing a local checkout and
> inspecting `herdr plugin log list`.

---

## 6. Milestones

### M0 — Repo bootstrap  ✅ (done)
- Create repo, MIT license, this PLAN.md, README, `.gitignore`.

### M1 — Proof of concept: Fresh in a split  ✅ (done)
- `herdr-plugin.toml` with `open-fresh` action + `scripts/open-fresh.sh` (+ `scripts/common.sh`,
  `scripts/run-fresh-daemon.sh`, `scripts/install.sh`).
- `herdr plugin link` verified locally against real herdr 0.7.0 + fresh 0.4.1: `open-fresh`
  action opens a split pane, `fresh -a fresh-<workspace-id>` boots inside its PTY and registers
  the named daemon (confirmed via `fresh --cmd daemon list`), and the pane self-labels so later
  invocations find it (`herdr pane list` carries no title/command field, only an optional
  `label` set via `pane rename`).
- Gotcha #1 (daemon creation needs a TTY) confirmed and resolved: `fresh --cmd daemon new` fails
  with `os error 6` headless; running `fresh -a <name>` inside the pane's own PTY works.
- Re-invoking `open-fresh` while the pane is already open focuses it instead of opening a
  duplicate (verified: pane count unchanged, second invocation exits with empty log output).
- **Exit criteria met:** one action invocation → Fresh editing pane beside current work,
  attached to a per-workspace daemon; re-invoking reattaches/focuses rather than duplicating.

### M2 — Tab variant + idempotent focus  ✅ (done)
- `open-fresh-tab` with focus-if-already-open (via `herdr tab`/`pane list`), matching the Fresh
  pane by its self-assigned `label`. Verified locally: no duplicate tab created on repeat
  invocation.

### M3 — Open-file-at-line  ✅ (done, core flow)
- `open-file-in-fresh.sh`: ensure-daemon (invokes `open-fresh.sh` + polls `daemon list` if
  missing) → `fresh --cmd daemon open-file <daemon> <target>` → focus pane via `pane zoom`.
- Verified locally: `fresh --cmd daemon open-file fresh-wQ README.md:5` opens the file at line 5
  in the live daemon.
- Remaining: a standalone `herdr-fresh open <path:line>` helper for other plugins/agents to call
  without going through `herdr plugin action invoke` (tracked for M4/M5).

### M4 — Config + editor integration  ✅ (done)
- `config.example.toml` + `docs/configuration.md`: `fresh_bin`/`fresh_args` (custom Fresh path/
  flags) and `daemon_name`/`daemon_name_prefix` (`per-workspace` (default) or `per-repo` naming).
  Parsed via `python3`'s stdlib `tomllib` (no new binary dependency); missing/malformed/
  no-python3 all degrade to defaults, matching herdr-file-viewer's config-loading conventions.
  Only ever read from the herdr-provided `$HERDR_PLUGIN_CONFIG_DIR` (or `$XDG_CONFIG_HOME`/
  `$HOME` fallback) — never from a repo's own cwd, so an untrusted repo can't override
  `fresh_bin`/`fresh_args`.
- `scripts/suggest-editor-integration.sh` + `docs/editor-integration.md`: opt-in helper that
  prints the exact `git config (--global|--local) core.editor "fresh --wait"` command, shows any
  existing value, and asks for confirmation (`--yes` to skip) before writing — never runs
  automatically.
- Verified locally: `daemon_name = "per-repo"`/`daemon_name_prefix`/`fresh_args` all round-trip
  through `scripts/common.sh`'s `daemon_name`/`fresh_bin`/`fresh_args` helpers; a malformed
  config file degrades to all-defaults; `suggest-editor-integration.sh --local --yes` correctly
  sets and reports `core.editor` in a scratch repo.

### M5 — Cross-platform + CI
- Windows `.ps1` launchers + `-windows` action ids.
- `install.sh`/`install.ps1` build step: detect Fresh, else run the official installer, else
  clear error.
- CI: shellcheck, PowerShell lint, manifest TOML validation, headless install smoke test.

### M6 — Docs + v0.1.0 release
- Fill `docs/`, finalize README, tag `v0.1.0` (no binary needed — we install Fresh).

### Post-v1 backlog
- SSH remote-edit action (`fresh deploy@host:/path`) surfaced as a herdr action.
- Git-review launch action (open Fresh directly in its review/diff mode for the current repo).
- Devcontainer awareness.
- A small Fresh TypeScript plugin that reports editor state back to herdr
  (`herdr pane report-metadata`) so the pane shows the open file / dirty state.
- Optional integration with herdr's agent status (show which workspace the editor is bound to).

---

## 7. Risks & mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| herdr pane-command / action-arg semantics differ from expectations | Med | M1 validates against real herdr 0.7.0 via `plugin link` before writing more scripts |
| Daemon creation needs a TTY (gotcha #1) | Confirmed | Launch Fresh inside the pane PTY, never headless; `open-file` only targets existing daemons |
| Two panes racing to create the same named daemon | Low | Check `daemon list` first; Fresh daemon names are idempotent attach targets |
| Windows spawn quirks (gotcha #3) | Med | Absolute-path launcher + no Windows `[[panes]]` |
| Fresh not installed at action time | Med | `[[build]]` install step + runtime `command -v fresh` guard with a friendly herdr notification |
| Fresh CLI surface changes across versions | Low | Pin tested `fresh` version range in README; feature-detect `--cmd daemon` subcommands |
| Untrusted-repo safety | Med | Lean on Fresh Workspace Trust; SECURITY.md states the model plainly |

---

## 8. License

- **MIT.**
- Conventional Commits; `CHANGELOG.md` from tags.
- Not affiliated with Fresh or herdr; an independent integration. Trademarks belong to their owners.

---

*Verified tooling at time of writing: herdr 0.7.0, fresh 0.4.1 (both installed on the dev host).*
