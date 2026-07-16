#!/bin/sh
# [[build]] step (unix): verify `fresh` is available before the plugin is considered installed.
# M5 backlog: auto-install via the official Fresh installer when missing. For now, fail loudly
# with a clear pointer rather than silently installing a plugin that can't launch an editor.
set -eu

if ! command -v fresh >/dev/null 2>&1; then
  echo "herdr-fresh: 'fresh' was not found on PATH." >&2
  echo "Install Fresh from https://getfresh.dev and re-run 'herdr plugin install'." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "herdr-fresh: 'jq' was not found on PATH (required by the launcher scripts)." >&2
  exit 1
fi

echo "herdr-fresh: found fresh ($(fresh --help 2>&1 | head -1 || true)); build check passed."
