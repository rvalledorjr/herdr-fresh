#!/usr/bin/env bash
# The [[panes]] entry's actual process — runs INSIDE the pane's own PTY. This is load-bearing:
# `fresh --cmd daemon new <name>` fails with `os error 6` (ENXIO) when it has no TTY, so the
# daemon must be created by `fresh -a <name>` running attached to a real pane, never from a
# headless action script (see herdr-plugin.toml header + PLAN.md §3.3 gotcha #1).
#
# `fresh -a <name>` both creates the named daemon (first run) and reattaches to it (subsequent
# runs) — that's what gives us "one persistent editing session per workspace" (PLAN.md §4.2).
#
# herdr's `pane list` has no title/command field to identify this pane by later, only an
# optional `label` (set via `pane rename`, otherwise empty) — so this script labels itself
# with the daemon name right after starting, letting open-fresh.sh / open-fresh-tab.sh /
# open-file-in-fresh.sh find "the Fresh pane for this workspace" by `label == fresh-<wid>`.
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=./common.sh
. "$script_dir/common.sh"

herdr_bin="${HERDR_BIN_PATH:-herdr}"
daemon="$(daemon_name)"

cd "$(resolve_cwd)" 2>/dev/null || true

# Label our own pane so other launcher scripts can find it later. Best-effort: if `pane current`
# can't resolve (e.g. run outside herdr for local testing), Fresh still starts normally.
self_pane_id="$("$herdr_bin" pane current 2>/dev/null | jq -r '.result.pane.pane_id // empty' 2>/dev/null || true)"
if [ -n "$self_pane_id" ]; then
  "$herdr_bin" pane rename "$self_pane_id" "$daemon" >/dev/null 2>&1 || true
fi

exec fresh -a "$daemon"
