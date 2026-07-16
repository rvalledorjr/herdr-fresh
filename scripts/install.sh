#!/bin/sh
# [[build]] step (unix): verify `fresh` is available, auto-installing via the official Fresh
# installer if it's missing (PLAN.md M5). Fails loudly with a clear pointer only if both the
# check and the install attempt come up empty.
set -eu

if command -v fresh >/dev/null 2>&1; then
  echo "herdr-fresh: found fresh ($(fresh --help 2>&1 | head -1 || true)); build check passed."
else
  echo "herdr-fresh: 'fresh' was not found on PATH. Attempting install via the official installer..."
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://raw.githubusercontent.com/sinelaw/fresh/refs/heads/master/scripts/install.sh | sh || \
      echo "herdr-fresh: automatic install failed; see error output above." >&2
  else
    echo "herdr-fresh: 'curl' not found; can't run the automatic installer." >&2
  fi

  if ! command -v fresh >/dev/null 2>&1; then
    echo "herdr-fresh: 'fresh' still not found on PATH." >&2
    echo "Install Fresh from https://getfresh.dev and re-run 'herdr plugin install'." >&2
    exit 1
  fi
  echo "herdr-fresh: installed fresh ($(fresh --help 2>&1 | head -1 || true)); build check passed."
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "herdr-fresh: 'jq' was not found on PATH (required by the launcher scripts)." >&2
  exit 1
fi
