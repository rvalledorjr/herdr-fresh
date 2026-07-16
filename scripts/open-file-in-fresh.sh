#!/usr/bin/env bash
# Push `path:line:col` into the running Fresh daemon for this workspace, ensuring the pane
# exists first (PLAN.md M3). Takes the target as the first CLI argument.
#
# `fresh --cmd daemon open-file <name> <path:line:col>` only works once that daemon already
# exists (confirmed locally) — so this ensures the Fresh pane is open, waits for the daemon to
# register, then pushes the file. Finds the pane by its self-assigned `label`
# (see run-fresh-daemon.sh) to bring it forward afterward.
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=./common.sh
. "$script_dir/common.sh"

target="${1:-}"
if [ -z "$target" ]; then
  echo "usage: open-file-in-fresh.sh <path[:line[:col]]>" >&2
  exit 1
fi

daemon="$(daemon_name)"

daemon_exists() {
  fresh --cmd daemon list 2>/dev/null | grep -qx "  $daemon"
}

if ! daemon_exists; then
  "$script_dir/open-fresh.sh"
  # Wait for the daemon to register (it appears once Fresh finishes booting inside the pane).
  for _ in $(seq 1 50); do
    daemon_exists && break
    sleep 0.2
  done
fi

fresh --cmd daemon open-file "$daemon" "$target"

herdr_bin="${HERDR_BIN_PATH:-herdr}"
panes_json="$("$herdr_bin" pane list 2>/dev/null || true)"
fresh_pane_id="$(printf '%s' "$panes_json" | jq -r --arg d "$daemon" '
  (.result.panes // [])
  | map(select(.label == $d))
  | (.[0].pane_id // empty)
' 2>/dev/null || true)"

if [ -n "$fresh_pane_id" ]; then
  "$herdr_bin" pane zoom "$fresh_pane_id" --on >/dev/null 2>&1 || true
  "$herdr_bin" pane zoom "$fresh_pane_id" --off >/dev/null 2>&1 || true
fi
