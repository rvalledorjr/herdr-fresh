# herdr-fresh — Project Plan

**A herdr plugin that runs [Fresh](https://getfresh.dev), the terminal IDE, as a first-class
file viewer *and* editor inside a herdr pane.**

Inspired by [`smarzban/herdr-file-viewer`](https://github.com/smarzban/herdr-file-viewer),
but where that project *builds* a read-only viewer from scratch (~11k lines of Rust), this
project *delegates* to Fresh — an existing, full-featured terminal editor — and ships only the
thin herdr integration layer around it. Viewer **plus** editor, LSP, Git review, search/replace,
and remote editing, with almost no code of our own to maintain.

---

## 1. Motivation

### 1.1 The reference project

`herdr-file-viewer` is a git-aware, **read-only** TUI that herdr opens in a split pane: a
directory tree on the left, and per-file the "right view" on the right (diff / rendered markdown /
syntax-highlighted code). It is a single in-process ratatui application (~11k lines of Rust) that
owns both columns and delegates rendering to `glow` / `delta` / `bat`. It never mutates files.

Its strengths: safe on untrusted repos, keyboard-first, git woven throughout, opens beside your
work in one keypress.

Its limits — **by design**:

- **Read-only.** You cannot edit. Hand-off to `$EDITOR` is a one-way exit.
- **A bespoke TUI** that must reimplement tree, finder, search, help, layout, mouse hit-testing,
  and rendering delegation — all of which a real editor already has.
- **No LSP, no multi-cursor, no in-place refactors, no persistent editing session.**

### 1.2 The opportunity

[Fresh](https://getfresh.dev) is a mature terminal IDE that *already* provides everything the
file-viewer painstakingly rebuilt, and much more:

- Instant startup, multi-GB files, small memory footprint.
- Git review & diff (staged/unstaged/untracked, per-hunk stage/discard, line comments, side-by-side).
- LSP (multiple servers per language, feature routing, merged completions).
- File explorer, command palette, project-wide search & replace, code folding, multi-cursor.
- **Detachable named daemons** that survive terminal disconnects (`fresh -a <name>`).
- **Remote editing over SSH** with background reconnect and patch-only saves.
- Themes, i18n, TypeScript plugins (sandboxed QuickJS).

So instead of writing a viewer, we write a **launcher**: a herdr plugin whose entire job is to
open Fresh in the right place, wire it into herdr's workspace/keybinding model, and expose the
one capability herdr users most want — *"open this file at this line in my editor pane, now."*

### 1.3 One-line thesis

> `herdr-file-viewer` re-implements a viewer inside a herdr pane. **herdr-fresh** puts a real
> editor inside a herdr pane, and ships only the glue.

---

## 2. Goals & Non-Goals

### 2.1 Goals (v1)

1. **`herdr plugin install rvalledorjr/herdr-fresh`** works end-to-end.
2. One keypress opens Fresh in a **split** beside the current pane.
3. One keypress opens Fresh in its own **tab** (idempotent: focus if already open).
4. A **"open file at line"** action so herdr / other tools can push `path:line:col` into the
   *already-running* Fresh pane (the differentiator vs. the read-only viewer).
5. **Persistent editing sessions**: one Fresh daemon per herdr workspace, surviving pane
   close/reattach.
6. Optional: register Fresh as `$EDITOR` / `$GIT_EDITOR` for herdr's agent panes (`fresh --wait`).
7. Read-only-safe defaults respected: opening an untrusted repo should honor Fresh's Workspace
   Trust model.
8. Cross-platform: Linux + macOS first-class; Windows preview (mirroring the reference project's
   approach).

### 2.2 Non-Goals (v1)

- We do **not** reimplement any editor feature. If Fresh can't do it, it's out of scope.
- We do **not** fork or patch Fresh. We integrate via its documented CLI/daemon surface only.
- We do **not** ship Fresh's binary in-repo. The build step installs/locates it.
- No custom rendering, no ratatui, no bespoke TUI. (That's the whole point.)

---

## 3. Background: the two integration surfaces (verified locally)

Verified against **herdr 0.7.0** and **fresh 0.4.1** installed on the dev machine.

### 3.1 herdr plugin model

From the reference `herdr-plugin.toml` and `herdr plugin --help`:

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
- Config keybinding pattern (from the reference README):
  ```toml
  [[keys.command]]
  key = "prefix+f"
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
3. **Windows relative-command spawn is broken in herdr** (documented in the reference manifest:
   `CreateProcessW` resolves relative program against herdr's own dir; herdr reports plugin root
   as a `\\?\` verbatim path and doesn't append `.exe`). Mirror the reference project: Windows
   actions locate the launcher by absolute path via `herdr plugin list --json`, and there is no
   Windows `[[panes]]` entry.
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
├── LICENSE                       ← MIT (matches reference project; OSS-friendly)
├── herdr-plugin.toml             ← the manifest
├── config.example.toml           ← optional plugin config (daemon naming, editor cmd, keys)
├── scripts/
│   ├── install.sh                ← [[build]] unix: ensure `fresh` present (installer or check)
│   ├── install.ps1               ← [[build]] windows
│   ├── open-fresh.sh             ← action: split-pane launch
│   ├── open-fresh-tab.sh         ← action: tab launch (idempotent focus-if-open)
│   ├── open-file-in-fresh.sh     ← action: push file:line into live daemon
│   ├── open-fresh.ps1            ← windows variants …
│   ├── open-fresh-tab.ps1
│   └── open-file-in-fresh.ps1
├── docs/
│   ├── install.md
│   ├── usage.md                  ← split vs tab, open-at-line, daemon lifecycle
│   ├── configuration.md          ← config.toml reference + [keys] remap
│   ├── editor-integration.md     ← Fresh as $EDITOR / core.editor in herdr agent panes
│   ├── windows.md                ← preview specifics (mirrors reference)
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

# … -windows-suffixed variants mirror the reference project (absolute-path launcher via plugin list --json).
```

> Exact keys (`placement`, pane-command semantics, action-arg passing) will be confirmed against
> herdr 0.7.0 behavior during Milestone 1 by `herdr plugin link`-ing a local checkout and
> inspecting `herdr plugin log list`.

---

## 6. Milestones

### M0 — Repo bootstrap  ✅ (this commit)
- Create public GitHub repo, MIT license, this PLAN.md, README stub, `.gitignore`.

### M1 — Proof of concept: Fresh in a split
- `herdr-plugin.toml` with `open-fresh` action + `scripts/open-fresh.sh`.
- `herdr plugin link ~/herdr-fresh` locally; bind `prefix+e`; verify Fresh opens in a split
  attached to a per-workspace daemon.
- Resolve the PTY/daemon-creation flow (gotcha #1) on real herdr.
- **Exit criteria:** one keypress → Fresh editing pane beside my work; close & reopen reattaches.

### M2 — Tab variant + idempotent focus
- `open-fresh-tab` with focus-if-already-open (mirror reference tab idempotency via
  `herdr tab`/`pane list`).

### M3 — Open-file-at-line (the differentiator)
- `open-file-in-fresh.sh`: ensure-daemon → `daemon open-file` → focus pane.
- Ship a helper (`herdr-fresh open <path:line>`) so agents/scripts/other plugins can call it.
- **Exit criteria:** from any pane, "open src/main.rs:42 in Fresh" lands on line 42 live.

### M4 — Config + editor integration
- `config.example.toml`: daemon naming, custom `fresh` path/flags, keybinding hints.
- Document + optionally auto-suggest `git config core.editor "fresh --wait"` for herdr agent panes.

### M5 — Cross-platform + CI
- Windows `.ps1` launchers + `-windows` action ids (mirror reference constraints).
- `install.sh`/`install.ps1` build step: detect Fresh, else run the official installer, else
  clear error.
- CI: shellcheck, PowerShell lint, manifest TOML validation, headless install smoke test.

### M6 — Docs + v0.1.0 release
- Fill `docs/`, finalize README, tag `v0.1.0`, produce prebuilt-free release (no binary needed —
  we install Fresh).
- Submit/announce (herdr plugin ecosystem, Fresh Discord).

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
| herdr pane-command / action-arg semantics differ from the reference | Med | M1 validates against real herdr 0.7.0 via `plugin link` before writing more scripts |
| Daemon creation needs a TTY (gotcha #1) | Confirmed | Launch Fresh inside the pane PTY, never headless; `open-file` only targets existing daemons |
| Two panes racing to create the same named daemon | Low | Check `daemon list` first; Fresh daemon names are idempotent attach targets |
| Windows spawn quirks (gotcha #3) | Med | Mirror the reference project's absolute-path launcher + no Windows `[[panes]]` |
| Fresh not installed at action time | Med | `[[build]]` install step + runtime `command -v fresh` guard with a friendly herdr notification |
| Fresh CLI surface changes across versions | Low | Pin tested `fresh` version range in README; feature-detect `--cmd daemon` subcommands |
| Untrusted-repo safety expectations (reference is hardened) | Med | Lean on Fresh Workspace Trust; document that Fresh is an *editor* (can write), unlike the read-only viewer; SECURITY.md states the model plainly |

## 8. Comparison table (for README)

| | herdr-file-viewer | **herdr-fresh** |
|---|---|---|
| Role | Read-only viewer | Viewer **+ editor** |
| Code size | ~11k lines Rust | Thin scripts + manifest |
| Rendering | Custom ratatui + glow/delta/bat | Fresh (full IDE) |
| Edit files | No (hand-off only) | Yes |
| LSP | No | Yes |
| Git | Status tree + diff view | Full review/stage/diff |
| Persistent session | No | Yes (Fresh daemon) |
| Remote (SSH) | No | Yes (Fresh SSH) |
| Open-at-line into live pane | No | **Yes** |
| Untrusted-repo hardening | First-class | Via Fresh Workspace Trust |

## 9. License & OSS

- **MIT** (matches the reference project and the herdr plugin ecosystem norm).
- Public repo → free GitHub Actions CI, Issues/PR templates, Dependabot, community health files.
- Conventional Commits; `CHANGELOG.md` from tags.
- Not affiliated with Fresh or herdr; an independent integration. Trademarks belong to their owners.

---

*Verified tooling at time of writing: herdr 0.7.0, fresh 0.4.1 (both installed on the dev host).*
