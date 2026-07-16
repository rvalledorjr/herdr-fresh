# herdr-fresh

**A [herdr](https://github.com/smarzban/herdr-file-viewer) plugin that runs
[Fresh](https://getfresh.dev), the terminal IDE, as a file viewer and editor inside a herdr
pane.**

Open Fresh in a split beside your work (or in its own tab), keep a persistent editing session
per workspace, and push `path:line` straight into the live editor pane from anywhere.

> **Status: v0.1.0, cross-platform preview.** Split, tab, and open-file-at-line all verified
> locally against real herdr 0.7.0 + fresh 0.4.1 via `herdr plugin link` on Linux. Windows
> `.ps1` launchers exist and are CI-linted (see [docs/windows.md](docs/windows.md)) but haven't
> had an equivalent real-herdr verification pass yet. See **[PLAN.md](PLAN.md)** for the full
> design, verification notes, and milestone history.

---

## Why this exists

This is a personal itch-solution: I wanted a real editor — not just a viewer — living in a herdr
pane, with LSP, Git review, multi-cursor, search/replace, and remote editing, without leaving my
terminal workspace. Fresh already is that editor. So rather than build an editor, herdr-fresh
ships the thin glue that wires Fresh into herdr's pane, tab, and keybinding model. Sharing it in
case it's useful to anyone else.

## What it does

- Open Fresh in a **split** beside the current pane with one keypress.
- Open Fresh in its own **tab** (focus it if it's already open).
- Push **`path:line:col`** into the running Fresh session for the workspace — from any pane,
  agent, or script.
- Keep a **persistent editing session per workspace** (a named Fresh daemon) that survives pane
  close and reattach.
- Optionally use Fresh as your `$EDITOR` / `core.editor` inside herdr agent panes.

## Quick start

```bash
# Install the plugin (installs Fresh if needed):
herdr plugin install rvalledorjr/herdr-fresh
```

See [docs/install.md](docs/install.md) for the full walkthrough (verification steps, uninstall,
optional config/editor-integration).

Bind keys in `~/.config/herdr/config.toml`:

```toml
[[keys.command]]                 # Fresh in a split beside your work
key = "prefix+e"
type = "shell"
command = "herdr plugin action invoke open-fresh --plugin herdr-fresh"

[[keys.command]]                 # Fresh in its own tab
key = "prefix+shift+e"
type = "shell"
command = "herdr plugin action invoke open-fresh-tab --plugin herdr-fresh"
```

Then `herdr server reload-config` and press your key.

Windows uses the same actions under `-windows`-suffixed ids (`open-fresh-windows`,
`open-fresh-tab-windows`) — see [docs/windows.md](docs/windows.md) for the full rundown and
current preview caveats.

## Documentation

- [docs/install.md](docs/install.md) — install, verify, uninstall
- [docs/usage.md](docs/usage.md) — split vs. tab, open-file-at-line, daemon lifecycle
- [docs/configuration.md](docs/configuration.md) — `config.toml` reference
- [docs/editor-integration.md](docs/editor-integration.md) — Fresh as `$EDITOR`/`core.editor`
- [docs/windows.md](docs/windows.md) — Windows preview specifics
- [docs/architecture.md](docs/architecture.md) — how the pieces fit together
- [PLAN.md](PLAN.md) — full design, integration seams, gotchas, milestones and risks
- [AGENTS.md](AGENTS.md) / [CONTRIBUTING.md](CONTRIBUTING.md) — contributor guidance
- [SECURITY.md](SECURITY.md) — trust model, reporting a vulnerability

## License

[MIT](LICENSE). Not affiliated with Fresh or herdr; an independent integration.
