# Configuration

An optional `config.toml` lets you override which `fresh` binary/flags herdr-fresh launches and
how it names the per-context Fresh daemon. **Read-only input** — no launcher script ever writes
this file. A missing file is the normal case; every key just falls back to its default.

## File location

Under herdr, run `herdr plugin config-dir herdr-fresh` to print the exact directory herdr keeps
it in (herdr also exports this path to every launcher script as `$HERDR_PLUGIN_CONFIG_DIR`). On
Linux that's:

```
~/.config/herdr/plugins/config/herdr-fresh/config.toml
```

Run standalone (outside herdr), it falls back to `$XDG_CONFIG_HOME/herdr-fresh/config.toml`,
defaulting to `~/.config/herdr-fresh/config.toml` when `XDG_CONFIG_HOME` isn't set.

Copy the shipped example into place in one line:

```bash
cp "$(herdr plugin list --json | jq -r '.result.plugins[]|select(.plugin_id=="herdr-fresh").plugin_root')/config.example.toml" \
   "$(herdr plugin config-dir herdr-fresh)/config.toml"
```

Then uncomment the lines you want. Copying it as-is changes nothing (every line is commented
out). Whatever you copy it as, **rename the copy to `config.toml`** — `config.example.toml` is
never read.

## Precedence

A config key always wins over its built-in default. There is no environment-variable fallback
tier for these keys. Parsing requires `python3` on `PATH` (used for its stdlib `tomllib`
parser); without it, or with a missing/malformed file, every key falls back to its default —
same whole-file-fallback behavior as herdr-file-viewer's config, no partial-apply.

**Security note:** herdr-fresh only ever reads `config.toml` from the herdr-provided
`$HERDR_PLUGIN_CONFIG_DIR` (or the `$XDG_CONFIG_HOME`/`$HOME` fallback) — never from the
repository's own working directory. A browsed/untrusted repo can't smuggle in its own
`fresh_bin`/`fresh_args` override.

## Keys

```toml
# ~/.config/herdr-fresh/config.toml (or the herdr-provided path above)

fresh_bin = "fresh"          # which `fresh` executable to launch (absolute path, or PATH lookup)
fresh_args = ["--safe"]      # extra CLI flags appended to every `fresh -a <daemon>` launch

daemon_name_prefix = "fresh" # prefix for the derived daemon name (`<prefix>-<id>`)
daemon_name = "per-workspace" # "per-workspace" (default) or "per-repo"
```

- **`fresh_bin`** — override which `fresh` binary is invoked, everywhere herdr-fresh calls it
  (pane launch, `daemon list`, `daemon open-file`). Useful for a pinned/preview build kept
  outside `PATH`. Default: `"fresh"`.
- **`fresh_args`** — an array of extra flags appended when launching `fresh -a <daemon>` *inside
  the pane* (the only place Fresh is ever started — see PLAN.md §3.3 gotcha #1). Space-joined
  and passed through as-is: no shell quoting/escaping is applied, so avoid values containing
  spaces. Default: `[]`.
- **`daemon_name_prefix`** — the `<prefix>` half of the derived daemon name
  `<prefix>-<id>`. Default: `"fresh"`.
- **`daemon_name`** — how the `<id>` half is derived:
  - `"per-workspace"` (default) — the herdr workspace id, so one persistent Fresh daemon
    survives per workspace (PLAN.md §4.2's original design).
  - `"per-repo"` — a hash of the resolved working directory instead, so the same repo checkout
    always reattaches to the same Fresh session regardless of which herdr workspace opens it.

## Applying a change

Launcher scripts read `config.toml` fresh on every invocation, but a **running** Fresh daemon
was already started with whatever `fresh_bin`/`fresh_args`/naming was in effect at launch time.
To pick up a change: edit `config.toml`, then kill the existing daemon
(`fresh --cmd daemon kill <name>`) before next invoking `open-fresh` / `open-fresh-tab`, or just
start using a workspace/repo that hasn't opened Fresh yet.
