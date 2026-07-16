#!/usr/bin/env bash
# Shared helpers for the herdr-fresh launcher scripts.
#
# herdr injects two things into an action's process: `$HERDR_BIN_PATH` (path to the herdr
# binary — fall back to `herdr` on PATH) and `$HERDR_PLUGIN_CONTEXT_JSON` (cwd/workspace info).
# The context JSON shape mirrors what herdr-file-viewer already parses in production
# (`focused_pane_cwd`, `workspace_cwd`, `cwd`, `workspace_id` — every field optional).
set -uo pipefail

herdr_bin="${HERDR_BIN_PATH:-herdr}"

# Resolve the herdr workspace id from the injected context JSON, falling back to `pane current`
# (works when a script runs interactively rather than via an action) and finally to a hash of
# the cwd so the daemon name is still stable and unique per directory with no workspace id at all.
resolve_workspace_id() {
  local wid=""
  if [ -n "${HERDR_PLUGIN_CONTEXT_JSON:-}" ]; then
    wid="$(printf '%s' "$HERDR_PLUGIN_CONTEXT_JSON" | jq -r '.workspace_id // empty' 2>/dev/null || true)"
  fi
  if [ -z "$wid" ]; then
    wid="$("$herdr_bin" pane current 2>/dev/null | jq -r '.result.pane.workspace_id // empty' 2>/dev/null || true)"
  fi
  if [ -z "$wid" ]; then
    wid="$(pwd | cksum | cut -d' ' -f1)"
  fi
  printf '%s' "$wid"
}

# The fresh daemon name for this workspace: one persistent editor per workspace (PLAN.md §4.2).
daemon_name() {
  printf 'fresh-%s' "$(resolve_workspace_id)"
}

# Resolve the directory to open Fresh in: prefer the context's cwd fields, else process cwd.
resolve_cwd() {
  local dir=""
  if [ -n "${HERDR_PLUGIN_CONTEXT_JSON:-}" ]; then
    dir="$(printf '%s' "$HERDR_PLUGIN_CONTEXT_JSON" | jq -r '.focused_pane_cwd // .workspace_cwd // .cwd // empty' 2>/dev/null || true)"
  fi
  if [ -z "$dir" ]; then
    dir="$(pwd)"
  fi
  printf '%s' "$dir"
}
