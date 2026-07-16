# herdr-fresh

**A [herdr](https://github.com/smarzban/herdr-file-viewer) plugin that runs
[Fresh](https://getfresh.dev), the terminal IDE, as a file viewer *and* editor inside a herdr
pane.**

Inspired by [`smarzban/herdr-file-viewer`](https://github.com/smarzban/herdr-file-viewer) — but
instead of building a read-only viewer from scratch, herdr-fresh delegates to Fresh, a complete
terminal editor, and ships only the thin herdr integration layer. You get a real editor (LSP,
Git review, multi-cursor, search/replace, remote editing) in a split beside your work, plus the
ability to push `path:line` into a live editor pane from anywhere.

> **Status: early / planning.** See **[PLAN.md](PLAN.md)** for the full design and roadmap.
> The plugin is not yet installable; this repo currently holds the plan and scaffolding.

---

## Why

`herdr-file-viewer` is a git-aware, **read-only** TUI (~11k lines of Rust) that reimplements a
tree + content viewer inside a herdr pane. It's excellent at what it does — but it can't edit,
has no LSP, and rebuilds features a real editor already has.

**herdr-fresh** takes the opposite approach: put a real editor in the pane and ship only the glue.

| | herdr-file-viewer | **herdr-fresh** |
|---|---|---|
| Role | Read-only viewer | Viewer **+ editor** |
| Code size | ~11k lines Rust | Thin scripts + manifest |
| Edit files | Hand-off only | Yes |
| LSP / multi-cursor | No | Yes |
| Git | Status tree + diff | Full review / stage / diff |
| Persistent session | No | Yes (Fresh daemon) |
| Remote (SSH) | No | Yes |
| Open file:line into live pane | No | **Yes** |

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
