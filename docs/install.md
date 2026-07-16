# Install

## Quick start

```bash
herdr plugin install rvalledorjr/herdr-fresh
```

That's it for the plugin itself. During install herdr runs `scripts/install.sh`
(`scripts/install.ps1` on Windows), which:

1. Checks whether `fresh` is already on `PATH`.
2. If not, tries to install it automatically — the official `getfresh.dev` installer script on
   Linux/macOS, `winget install fresh-editor` on Windows.
3. Fails the build with a link to <https://getfresh.dev> only if both the check and the
   automatic install come up empty.
4. On Unix, also verifies `jq` is present (required by every bash launcher for parsing herdr's
   JSON output). Windows doesn't need it — the `.ps1` scripts use `ConvertFrom-Json`.

No herdr-fresh binary is shipped or built — the plugin is just the launcher scripts plus the
manifest; Fresh itself is the only thing that gets installed.

## Bind keys

Add to `~/.config/herdr/config.toml`:

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

Windows uses `-windows`-suffixed action ids instead (`open-fresh-windows`,
`open-fresh-tab-windows`) — see [windows.md](windows.md).

Then reload herdr's config and press your key:

```bash
herdr server reload-config
```

## Verify it worked

- `herdr plugin list --json` should list `herdr-fresh` with the version from
  `herdr-plugin.toml`.
- Pressing the `open-fresh` keybinding should split a pane and boot Fresh inside it.
- `fresh --cmd daemon list` (run from any shell) should show a `fresh-<id>` daemon once the
  pane has started.

## Optional: `config.toml`

Only needed if you want to override the `fresh` binary/flags or the daemon naming scheme — see
[configuration.md](configuration.md) for the file location and every key. There is nothing to
configure for a default install; the plugin works with zero config files present.

## Optional: Fresh as `$EDITOR` / `core.editor`

Not set up automatically. See [editor-integration.md](editor-integration.md) if you want
`git commit` / `git rebase -i` (etc.) to open in Fresh from herdr's agent panes.

## Uninstall

```bash
herdr plugin remove herdr-fresh
```

This does not uninstall `fresh` itself (it was installed independently by
`scripts/install.sh`/`install.ps1`, not owned by herdr-fresh) and does not kill any running
Fresh daemons — do that separately with `fresh --cmd daemon kill <name>` if you want to fully
tear down a session.
