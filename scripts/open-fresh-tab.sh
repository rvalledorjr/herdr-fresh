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
  # See open-fresh.sh's open_pane() for why --cwd must NOT be passed here: it would resolve
  # the [[panes]] entry's relative command (`bash scripts/run-fresh-daemon.sh`) against the
  # target repo's cwd instead of the plugin root, causing an invisible spawn-then-exit(127).
  # `plugin pane open --placement tab` opens in whichever workspace herdr's CLI process is
  # currently attached to unless told otherwise — pass the invoking workspace explicitly (from
  # the action's context JSON), or the tab silently opens in the wrong workspace when invoked
  # from somewhere other than wherever the herdr CLI subprocess happens to be focused.
  exec "$herdr_bin" plugin pane open \
    --plugin herdr-fresh \
    --entrypoint fresh \
    --placement tab \
    --workspace "$current_workspace_id" \
    --focus
}

panes_json="$("$herdr_bin" pane list 2>/dev/null || true)"
current_pane_id="$(resolve_focused_pane_id)"
current_workspace_id="$(resolve_workspace_id)"

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
