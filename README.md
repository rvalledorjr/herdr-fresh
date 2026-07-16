# herdr-fresh

**A [herdr](https://github.com/smarzban/herdr-file-viewer) plugin that runs
[Fresh](https://getfresh.dev), the terminal IDE, as a file viewer and editor inside a herdr
pane.**

Open Fresh in a split beside your work (or in its own tab), keep a persistent editing session
per workspace, and push `path:line` straight into the live editor pane from anywhere.

> **Status: early / planning.** See **[PLAN.md](PLAN.md)** for the full design and roadmap.
> The plugin is not yet installable; this repo currently holds the plan and scaffolding.

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

## Planned quick start

```bash
# Install the plugin (installs Fresh if needed):
herdr plugin install rvalledorjr/herdr-fresh
```

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

## Documentation

Full design, integration seams, gotchas, milestones and risks live in **[PLAN.md](PLAN.md)**.

## License

[MIT](LICENSE). Not affiliated with Fresh or herdr; an independent integration.
