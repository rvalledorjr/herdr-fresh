#!/usr/bin/env bash
# Shared helpers for the herdr-fresh launcher scripts.
#
# herdr injects two things into an action's process: `$HERDR_BIN_PATH` (path to the herdr
# binary — fall back to `herdr` on PATH) and `$HERDR_PLUGIN_CONTEXT_JSON` (cwd/workspace info).
# The context JSON shape mirrors what herdr-file-viewer already parses in production
# (`focused_pane_cwd`, `workspace_cwd`, `cwd`, `workspace_id` — every field optional).
set -uo pipefail

herdr_bin="${HERDR_BIN_PATH:-herdr}"

# --- Optional config.toml (PLAN.md M4) --------------------------------------------------------
#
# Same file-location and trust conventions as herdr-file-viewer's config:
#   $HERDR_PLUGIN_CONFIG_DIR/config.toml (herdr-provided, wins outright), else
#   $XDG_CONFIG_HOME/herdr-fresh/config.toml, else $HOME/.config/herdr-fresh/config.toml.
# A relative fallback (no HERDR_PLUGIN_CONFIG_DIR/XDG_CONFIG_HOME/HOME resolvable) is never read —
# that would source a "trusted" config from a possibly-untrusted repo's cwd. Missing or
# unparseable config is silently equivalent to "no config": every key just uses its default.
# Parsing needs `python3` (for stdlib `tomllib`); if it's unavailable, config is treated as absent.

_config_dir() {
  if [ -n "${HERDR_PLUGIN_CONFIG_DIR:-}" ]; then
    printf '%s' "$HERDR_PLUGIN_CONFIG_DIR"
    return
  fi
  local base
  if [ -n "${XDG_CONFIG_HOME:-}" ]; then
    base="$XDG_CONFIG_HOME"
  elif [ -n "${HOME:-}" ]; then
    base="$HOME/.config"
  else
    base=".config"
  fi
  printf '%s/herdr-fresh' "$base"
}

_config_path() {
  printf '%s/config.toml' "$(_config_dir)"
}

_config_json_raw=""
_config_json_loaded=0

# Lazily parse config.toml to JSON (via python3's tomllib) and cache the result for this process.
# Always yields valid JSON: "{}" for a missing file, a non-absolute path (untrusted-cwd guard),
# missing python3, or a malformed/unreadable file.
_config_json() {
  if [ "$_config_json_loaded" -eq 1 ]; then
    printf '%s' "$_config_json_raw"
    return
  fi
  _config_json_loaded=1
  _config_json_raw='{}'
  local path
  path="$(_config_path)"
  case "$path" in
    /*) : ;;
    *) printf '%s' "$_config_json_raw"; return ;;
  esac
  if [ ! -f "$path" ] || ! command -v python3 >/dev/null 2>&1; then
    printf '%s' "$_config_json_raw"
    return
  fi
  local parsed
  parsed="$(python3 - "$path" <<'PY' 2>/dev/null
import json
import sys
try:
    import tomllib
except ImportError:
    print("{}")
    sys.exit(0)
try:
    with open(sys.argv[1], "rb") as f:
        data = tomllib.load(f)
except Exception:
    print("{}")
    sys.exit(0)
print(json.dumps(data))
PY
)"
  if [ -n "$parsed" ]; then
    _config_json_raw="$parsed"
  fi
  printf '%s' "$_config_json_raw"
}

# config_get <jq-expr> <default> — read a key (jq filter applied to the parsed config JSON),
# falling back to <default> when the key is absent, null, empty, or jq itself errors.
config_get() {
  local expr="$1" default="$2" val
  val="$(printf '%s' "$(_config_json)" | jq -r "$expr" 2>/dev/null || true)"
  if [ -z "$val" ] || [ "$val" = "null" ]; then
    printf '%s' "$default"
  else
    printf '%s' "$val"
  fi
}

# fresh_bin: which `fresh` binary to run (config `fresh_bin`, default "fresh" off PATH).
fresh_bin() {
  config_get '.fresh_bin // empty' "fresh"
}

# fresh_args: extra CLI args to append when launching `fresh -a <daemon>` inside the pane
# (config `fresh_args`, an array of strings — e.g. ["--safe"]). Space-joined, default empty.
fresh_args() {
  config_get '(.fresh_args // []) | join(" ")' ""
}

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

# Resolve the pane id the action was invoked from (the pane to split beside), from the
# injected context JSON, falling back to `pane current` (works for local/interactive testing).
# Actions run as a detached herdr CLI subprocess, so `pane current` alone reflects whatever pane
# is *globally* focused across all workspaces — not necessarily the workspace the keybinding was
# pressed in. Preferring the context's `focused_pane_id` is what keeps split placement targeted
# at the invoking workspace instead of wherever herdr's CLI process happens to be attached.
resolve_focused_pane_id() {
  local pid=""
  if [ -n "${HERDR_PLUGIN_CONTEXT_JSON:-}" ]; then
    pid="$(printf '%s' "$HERDR_PLUGIN_CONTEXT_JSON" | jq -r '.focused_pane_id // empty' 2>/dev/null || true)"
  fi
  if [ -z "$pid" ]; then
    pid="$("$herdr_bin" pane current 2>/dev/null | jq -r '.result.pane.pane_id // empty' 2>/dev/null || true)"
  fi
  printf '%s' "$pid"
}

# Resolve the tab id the action was invoked from, same rationale/fallback as
# resolve_focused_pane_id() above.
resolve_tab_id() {
  local tid=""
  if [ -n "${HERDR_PLUGIN_CONTEXT_JSON:-}" ]; then
    tid="$(printf '%s' "$HERDR_PLUGIN_CONTEXT_JSON" | jq -r '.tab_id // empty' 2>/dev/null || true)"
  fi
  if [ -z "$tid" ]; then
    tid="$("$herdr_bin" pane current 2>/dev/null | jq -r '.result.pane.tab_id // empty' 2>/dev/null || true)"
  fi
  printf '%s' "$tid"
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

# The fresh daemon name for this context (PLAN.md §4.2), configurable via config.toml:
#   daemon_name_prefix (string, default "fresh")
#   daemon_name        ("per-workspace" (default) | "per-repo")
# "per-workspace" ties the daemon to the herdr workspace id (one editor per workspace, the
# default). "per-repo" instead hashes the resolved cwd, so the same repo path always gets the
# same daemon regardless of which herdr workspace it's opened from.
daemon_name() {
  local prefix mode
  prefix="$(config_get '.daemon_name_prefix // empty' "fresh")"
  mode="$(config_get '.daemon_name // empty' "per-workspace")"
  if [ "$mode" = "per-repo" ]; then
    printf '%s-%s' "$prefix" "$(resolve_cwd | cksum | cut -d' ' -f1)"
  else
    printf '%s-%s' "$prefix" "$(resolve_workspace_id)"
  fi
}
