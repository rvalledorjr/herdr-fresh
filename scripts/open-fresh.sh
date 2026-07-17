#!/usr/bin/env bash
# Idempotent launcher for the `open-fresh` action: open Fresh in a split beside the current
# pane, or focus it if a Fresh pane for this workspace is already open in the current tab.
#
# The Fresh pane self-labels with the daemon name (see run-fresh-daemon.sh), so we find it by
# matching `label == fresh-<workspace-id>` in `herdr pane list` rather than guessing at a
# command/title field (herdr panes carry no such field).
set -uo pipefail

herdr_bin="${HERDR_BIN_PATH:-herdr}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=./common.sh
. "$script_dir/common.sh"

daemon="$(daemon_name)"

open_pane() {
  # `plugin pane open` spawns the [[panes]] entry's relative command (`bash
  # scripts/run-fresh-daemon.sh`) with its cwd resolved against whatever `--cwd` we pass here —
  # NOT against the plugin's own root. Passing the target repo's cwd here (as this script used
  # to) makes bash look for `scripts/run-fresh-daemon.sh` inside that repo instead of inside the
  # plugin, so the pane spawns and immediately exits (code 127) with no visible error: the split
  # flashes and closes. Omitting --cwd lets herdr default it to the plugin root instead, so the
  # relative command resolves; run-fresh-daemon.sh's own `cd "$(resolve_cwd)"` (common.sh) is
  # what actually moves Fresh into the right directory afterward.
  #
  # `plugin pane open --placement split` targets an existing pane, not "whatever herdr's CLI
  # process is currently attached to" — pass the invoking pane explicitly (from the action's
  # context JSON) or split placement silently lands in the wrong workspace when the action is
  # invoked from a workspace other than the one the herdr CLI subprocess is focused on.
  exec "$herdr_bin" plugin pane open \
    --plugin herdr-fresh \
    --entrypoint fresh \
    --placement split \
    --direction right \
    --target-pane "$current_pane_id" \
    --focus
}

panes_json="$("$herdr_bin" pane list 2>/dev/null || true)"
current_pane_id="$(resolve_focused_pane_id)"
current_tab_id="$(resolve_tab_id)"

fresh_pane_id=""
if [ -n "$panes_json" ] && [ -n "$current_tab_id" ]; then
  fresh_pane_id="$(printf '%s' "$panes_json" | jq -r --arg tab "$current_tab_id" --arg d "$daemon" '
    (.result.panes // [])
    | map(select(.tab_id == $tab and .label == $d))
    | (.[0].pane_id // empty)
  ' 2>/dev/null || true)"
fi

if [ -z "$fresh_pane_id" ]; then
  open_pane
elif [ "$fresh_pane_id" = "$current_pane_id" ]; then
  # Already focused on the Fresh pane: nothing to do.
  exit 0
else
  "$herdr_bin" pane zoom "$fresh_pane_id" --on >/dev/null 2>&1 || true
  exec "$herdr_bin" pane zoom "$fresh_pane_id" --off
fi
