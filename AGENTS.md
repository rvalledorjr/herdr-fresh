# AGENTS.md — contributor/agent guidance for herdr-fresh

This repo is a thin **herdr plugin** wrapping [Fresh](https://getfresh.dev). It ships no editor
code — only launcher scripts and a manifest. Keep changes in that spirit: if something Fresh
already does is missing, the fix is almost never "implement it here."

## Before changing anything

- Read [PLAN.md](PLAN.md) — it's the source of truth for the architecture, the two integration
  surfaces (herdr plugin model, Fresh CLI/daemon model), the gotchas that shape every script, and
  the milestone history. Design decisions are justified there, not re-derived from scratch.
- The three load-bearing facts, if you only remember three things:
  1. `fresh --cmd daemon new <name>` needs a TTY. Daemons are only ever created by
     `fresh -a <name>` running as a `[[panes]]` command (which herdr gives a real PTY) — never
     from a headless action script.
  2. `fresh --cmd daemon open-file` requires the target daemon to already exist. "Open file at
     line" scripts must ensure the pane is open first.
  3. Windows can't spawn a relative pane command (`CreateProcessW` resolves it against herdr's
     own dir, not the plugin's) — so there is **no Windows `[[panes]]` entry**, and Windows
     actions resolve this plugin's absolute root via `herdr plugin list --json` instead.

## Conventions

- **Bash**: `set -uo pipefail` at the top of every script (already the pattern in
  `scripts/*.sh`). Source `scripts/common.sh` for config/context/daemon-name helpers rather than
  re-deriving them. Keep scripts POSIX-ish where easy but `#!/usr/bin/env bash` + bashisms are
  fine (bash is the documented interpreter in `herdr-plugin.toml`).
- **PowerShell**: mirror the bash script's behavior 1:1 in the matching `.ps1` file (see
  `scripts/common.ps1`'s `Resolve-PluginRoot` and the naming symmetry with `common.sh`). Every
  `.sh` launcher should have a `.ps1` counterpart with equivalent behavior, or the gap noted in
  `docs/windows.md`'s "known limitations" section.
- **Action ids**: unique across platforms even when platform-gated (herdr rejects duplicates at
  load). Windows variants get a `-windows` suffix, matching the existing
  `open-fresh`/`open-fresh-windows` pattern.
- **Config trust model**: `config.toml` is only ever read from `$HERDR_PLUGIN_CONFIG_DIR` (or the
  `$XDG_CONFIG_HOME`/`$HOME` fallback for standalone use) — never from a repo's own working
  directory. Don't introduce a code path that reads config relative to `pwd`; see
  `docs/configuration.md`'s security note and `common.sh`'s `_config_path` guard.
- **Docs stay in sync with code.** If you change a script's behavior, flags, or an action id,
  update the matching section in `docs/` (and `PLAN.md`'s milestone notes if it changes verified
  behavior) in the same change.

## Verifying changes locally

There's no unit test suite — verification is done against real `herdr`/`fresh` binaries via
`herdr plugin link`, or with the same checks CI runs:

```bash
# Syntax-check every bash launcher (no execution)
for f in scripts/*.sh; do bash -n "$f"; done

# Manifest sanity (mirrors .github/workflows/ci.yml's manifest-lint job)
python3 -c "
import tomllib
with open('herdr-plugin.toml', 'rb') as f:
    data = tomllib.load(f)
ids = [a['id'] for a in data.get('actions', [])]
assert len(ids) == len(set(ids)), 'duplicate action ids'
print('ok:', ids)
"

# shellcheck scripts/*.sh   # if you have shellcheck installed locally
```

If you have Windows/PowerShell access, `Invoke-ScriptAnalyzer -Path ./scripts -Recurse` mirrors
the `powershell-lint` CI job.

## Scope

- No forking or patching Fresh itself — integrate only via its documented CLI/daemon surface.
- No bundled Fresh binary — the `[[build]]` install steps install/locate it at plugin-install
  time.
- Keep new features scoped to the launcher/glue layer described in PLAN.md §4; anything that
  looks like "build an editor feature" belongs upstream in Fresh instead.
