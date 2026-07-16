#!/usr/bin/env bash
# Optional helper (PLAN.md M4): suggest / apply `git config core.editor "fresh --wait"` so
# herdr agent panes that shell out to `$EDITOR`/`core.editor` (e.g. `git commit`, `git rebase -i`)
# open in Fresh. Never runs automatically — invoked explicitly by the user (see
# docs/editor-integration.md), and always asks before writing repo or global git config.
#
# Usage:
#   scripts/suggest-editor-integration.sh [--global|--local] [--yes]
#
#   --global   Write to `git config --global core.editor` (default if neither is given: asks).
#   --local    Write to the current repo's `git config --local core.editor` instead.
#   --yes      Skip the confirmation prompt (for non-interactive use).
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=./common.sh
. "$script_dir/common.sh"

scope=""
assume_yes=0
for arg in "$@"; do
  case "$arg" in
    --global) scope="--global" ;;
    --local) scope="--local" ;;
    --yes) assume_yes=1 ;;
    *) echo "usage: $0 [--global|--local] [--yes]" >&2; exit 1 ;;
  esac
done

fresh_cmd="$(fresh_bin)"
target="$fresh_cmd --wait"

if [ -z "$scope" ]; then
  scope="--global"
fi

current="$(git config "$scope" --get core.editor 2>/dev/null || true)"
if [ "$current" = "$target" ]; then
  echo "core.editor ($scope) is already \"$target\"."
  exit 0
fi

echo "This will set: git config $scope core.editor \"$target\""
if [ -n "$current" ]; then
  echo "Current value ($scope): \"$current\" — it will be overwritten."
fi

if [ "$assume_yes" -ne 1 ]; then
  read -r -p "Proceed? [y/N] " reply
  case "$reply" in
    y|Y|yes|YES) ;;
    *) echo "Aborted; no changes made." >&2; exit 1 ;;
  esac
fi

git config "$scope" core.editor "$target"
echo "Set core.editor ($scope) to \"$target\"."
