# Architecture

herdr-fresh is glue, not an editor: a herdr plugin manifest plus a handful of launcher scripts
that open [Fresh](https://getfresh.dev) in the right place and keep one daemon alive per
workspace. This page is the short version; the full research trail (verification notes,
gotchas, risks) lives in [PLAN.md](../PLAN.md).

## Components

```
herdr-plugin.toml   manifest: [[build]] (install check), [[panes]] (the Fresh pane),
                     [[actions]] (open-fresh, open-fresh-tab, open-file-in-fresh, + -windows
                     variants)
scripts/common.sh    shared helpers: config.toml loading, workspace-id/cwd resolution,
                     daemon-name derivation
scripts/run-fresh-daemon.sh
                     the [[panes]] entry's actual process — runs `fresh -a <daemon>` INSIDE
                     the pane's own PTY, then labels the pane with the daemon name
scripts/open-fresh.sh / open-fresh-tab.sh
                     idempotent split/tab launchers — find the labeled pane via `pane list`
                     and focus it, or open a new one if it doesn't exist yet
scripts/open-file-in-fresh.sh
                     ensures the daemon exists (invoking open-fresh.sh if not), then
                     `fresh --cmd daemon open-file <daemon> <target>`
scripts/install.sh   [[build]] step: verify/auto-install `fresh` + `jq`
scripts/*.ps1        PowerShell mirrors of the above for Windows (see windows.md)
```

## Split-pane open flow

```
herdr → invokes action (keybinding)
          │
          ▼
   scripts/open-fresh.sh
          │  reads HERDR_PLUGIN_CONTEXT_JSON (cwd, workspace/pane/tab id) + HERDR_BIN_PATH
          │  derives a stable daemon name: fresh-<workspace-id>
          │  checks `herdr pane list` for a pane labeled fresh-<workspace-id> in this tab
          │  (matching is scoped to the invoking pane/tab from the context JSON, not to
          │  whatever pane herdr's own CLI subprocess is globally focused on — required for
          │  correct behavior when the action is invoked from a non-focused workspace)
          ▼
   found? → zoom/focus it, done.
   not found? → `herdr plugin pane open --entrypoint fresh --placement split --focus`
          │  (deliberately omits --cwd: it would resolve the [[panes]] entry's *relative*
          │  command against the target repo instead of the plugin root, causing a silent
          │  spawn-then-exit(127) — see "Why the pane runs Fresh directly" below)
          │
          ▼
   herdr-plugin.toml's [[panes]] entry runs scripts/run-fresh-daemon.sh INSIDE the new
   pane's PTY
          │
          ▼
   `fresh -a fresh-<workspace-id>` boots, creating (first run) or reattaching to (later
   runs) the named daemon. The script labels its own pane right after start so later
   invocations can find it.
```

`open-fresh-tab.sh` is the same shape with `--placement tab` and tab-focus instead of
pane-zoom.

## Open-file-at-line flow

```
scripts/open-file-in-fresh.sh <path:line:col>
   │  daemon = fresh-<workspace-id>
   │  daemon already in `fresh --cmd daemon list`?
   │     no  → run open-fresh.sh (opens/creates the pane), poll `daemon list` until it
   │           appears (~10s timeout)
   │     yes → skip straight to the push
   ▼
   fresh --cmd daemon open-file <daemon> <target>
   ▼
   herdr pane zoom <pane> --on / --off   (bring the pane forward)
```

## Why the pane runs Fresh directly (not the launcher)

`fresh --cmd daemon new <name>` fails with `os error 6` (ENXIO) when it isn't attached to a
TTY. herdr's `[[panes]]` command is the only place in this plugin that gets a real PTY from
herdr, so it's the only place a daemon can ever be *created*. Every other script only ever
attaches to an existing daemon (`daemon open-file`) or opens/focuses the pane that will create
one — none of them try to create a daemon headlessly. See PLAN.md §3.3 gotcha #1 for the full
verification notes.

## Why open-fresh.sh/open-fresh-tab.sh never pass `--cwd` to `plugin pane open`

`herdr plugin pane open --cwd <dir>` resolves the `[[panes]]` entry's *relative* command
(`bash scripts/run-fresh-daemon.sh`) against that `--cwd`, not the plugin's own root. Passing
the target repo's directory there (an earlier version of this plugin did) makes bash look for
`scripts/run-fresh-daemon.sh` inside the *target repo* instead of the plugin — the pane spawns
and immediately exits (confirmed: exit code 127) with no visible error, since the split just
flashes and closes. Omitting `--cwd` lets herdr default the pane's cwd to the plugin root
instead, so the relative command resolves; `run-fresh-daemon.sh`'s own
`cd "$(resolve_cwd)"` (in `common.sh`) is what actually moves Fresh into the intended directory
afterward. See PLAN.md M7 for the verification notes (this also affects the sibling
`herdr-file-viewer` plugin, which has the same `[[panes]]` shape).

## Windows differences

Windows has no `[[panes]]` entry at all — see [windows.md](windows.md) for why and how the
`.ps1` actions compensate by doing the split/pane-run themselves via an absolute-path launcher.

## Configuration surface

`scripts/common.sh` (`common.ps1` on Windows) is the only place `config.toml` is read — see
[configuration.md](configuration.md) for the keys and the trust model (only ever read from the
herdr-provided config directory, never from the repo's own cwd).
