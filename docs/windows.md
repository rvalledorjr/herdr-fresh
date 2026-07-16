# Windows (preview)

Windows support is a preview: it's been written and exercised against the same herdr
plugin-action contract as Linux/macOS, but hasn't had the benefit of `herdr plugin link`
verification on a real Windows host the way M1–M4 were verified on Linux (PLAN.md §3, §7).
File issues if something doesn't match your install.

## What's different from Linux/macOS

1. **No `[[panes]]` entry.** herdr can't spawn a *relative* pane command on Windows —
   `CreateProcessW` resolves it against herdr's own directory, not the plugin's, and herdr
   reports the plugin root as a `\\?\` verbatim path without appending `.exe` (PLAN.md §3.3
   gotcha #3). So there's no equivalent of the Unix `fresh` pane definition; instead, the split
   and tab actions do the split/tab **and** the pane-run themselves, resolving this plugin's
   absolute install root via `herdr plugin list --json` (see `scripts/common.ps1`'s
   `Resolve-PluginRoot`) before invoking `scripts/run-fresh-daemon.ps1` by full path.
2. **`-windows`-suffixed action ids.** herdr rejects duplicate action ids across platforms even
   when each is platform-gated, so the Windows actions are separate ids:
   - `open-fresh-windows` (split) — Unix: `open-fresh`
   - `open-fresh-tab-windows` (tab) — Unix: `open-fresh-tab`
   - `open-file-in-fresh-windows` (open at line) — Unix: `open-file-in-fresh`
3. **PowerShell instead of bash**, with no `jq`/Python-JSON dependency for the JSON parsing that
   the Unix scripts need `jq` for — PowerShell's `ConvertFrom-Json` is built in. Config-file
   TOML parsing still needs `python`/`python3` on `PATH` (same as Unix, via stdlib `tomllib`);
   without it, config is silently absent and every key falls back to its default.
4. **`[[build]]` install step** tries `winget install fresh-editor` when `fresh` isn't found on
   `PATH`, mirroring the Unix build step's install-via-official-installer fallback. If `winget`
   isn't available or the install fails, it fails loudly with a pointer to
   [getfresh.dev](https://getfresh.dev).

## Keybindings

Same shape as Linux/macOS, just with the `-windows` action ids:

```toml
[[keys.command]]
key = "prefix+e"
type = "shell"
command = "herdr plugin action invoke open-fresh-windows --plugin herdr-fresh"

[[keys.command]]
key = "prefix+shift+e"
type = "shell"
command = "herdr plugin action invoke open-fresh-tab-windows --plugin herdr-fresh"
```

## Known limitations / untested paths

- Daemon-creation-needs-a-TTY (gotcha #1) is assumed to hold the same way on Windows consoles
  as on Unix PTYs, but hasn't been independently reconfirmed there.
- `scripts/suggest-editor-integration.sh` (the opt-in `core.editor` helper) has no `.ps1`
  counterpart yet — on Windows, set it by hand:
  ```powershell
  git config --global core.editor "fresh --wait"
  ```
- CI (`.github/workflows/ci.yml`) runs a PowerShell script-analyzer/lint pass on the `.ps1`
  files, but the install/action smoke tests only run on Linux (matching M5's actual
  verification depth) — a Windows-hosted smoke test job is tracked for a follow-up.
