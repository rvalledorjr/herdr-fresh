#!/usr/bin/env bash
# Idempotent launcher for `open-fresh-tab`: open Fresh in its own tab, or switch to it if
# already open anywhere in this workspace. Sibling of open-fresh.sh (the split-pane variant).
# Matches the Fresh pane by its self-assigned `label` (see run-fresh-daemon.sh).
set -uo pipefail

herdr_bin="${HERDR_BIN_PATH:-herdr}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=./common.sh
. "$script_dir/common.sh"

daemon="$(daemon_name)"

open_tab() {
  exec "$herdr_bin" plugin pane open \
    --plugin herdr-fresh \
    --entrypoint fresh \
    --placement tab \
    --cwd "$(resolve_cwd)" \
    --focus
}

panes_json="$("$herdr_bin" pane list 2>/dev/null || true)"
current_json="$("$herdr_bin" pane current 2>/dev/null || true)"
current_pane_id="$(printf '%s' "$current_json" | jq -r '.result.pane.pane_id // empty' 2>/dev/null || true)"
current_workspace_id="$(printf '%s' "$current_json" | jq -r '.result.pane.workspace_id // empty' 2>/dev/null || true)"

match="$(printf '%s' "$panes_json" | jq -r --arg ws "$current_workspace_id" --arg d "$daemon" '
  (.result.panes // [])
  | map(select(.workspace_id == $ws and .label == $d))
  | (.[0] // empty)
' 2>/dev/null || true)"

if [ -z "$match" ] || [ "$match" = "null" ]; then
  open_tab
fi

fresh_pane_id="$(printf '%s' "$match" | jq -r '.pane_id // empty')"
fresh_tab_id="$(printf '%s' "$match" | jq -r '.tab_id // empty')"

if [ "$fresh_pane_id" = "$current_pane_id" ]; then
  # Already focused on the Fresh pane: nothing to do.
  exit 0
elif [ -n "$fresh_tab_id" ]; then
  "$herdr_bin" tab focus "$fresh_tab_id" || open_tab
else
  open_tab
fi
