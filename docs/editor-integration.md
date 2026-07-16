# Editor integration: Fresh as `$EDITOR` / `core.editor`

Fresh supports a blocking mode — `fresh --wait` — that returns only once the opened buffer is
closed. That's the same contract `$EDITOR` / `git config core.editor` expect, so you can point
herdr's agent panes (or any shell) at Fresh for `git commit`, `git rebase -i`, `crontab -e`, etc.

herdr-fresh does **not** set this for you automatically — it's opt-in, and only ever applied
when you explicitly ask.

## Quick setup

Use the bundled helper, which asks for confirmation before writing anything:

```bash
# From the plugin's linked/installed root:
scripts/suggest-editor-integration.sh --global   # git config --global core.editor "fresh --wait"
scripts/suggest-editor-integration.sh --local    # ...--local, for just the current repo
```

Add `--yes` to skip the confirmation prompt (e.g. from a non-interactive setup script). The
helper respects a configured `fresh_bin` override (see [configuration.md](configuration.md)),
so `"fresh --wait"` becomes `"<your fresh_bin> --wait"` if you've set one.

It refuses to run silently: it always prints the exact `git config` command it's about to run,
shows the current value if one is already set, and only proceeds after you confirm (or pass
`--yes`).

## Doing it by hand

Equivalent manual commands, if you'd rather not use the helper:

```bash
git config --global core.editor "fresh --wait"   # every repo
# or
git config --local core.editor "fresh --wait"    # just the current repo

export EDITOR="fresh --wait"                     # shell-wide $EDITOR, e.g. in your shell rc
```

## Caveats

- **Only takes effect in a pane with a real TTY.** Same constraint as daemon creation
  (PLAN.md §3.3 gotcha #1): `fresh --wait` needs to attach to a terminal, so this only works
  from an interactive herdr agent pane (or any real terminal), not from a headless script.
- **This does not reuse your persistent daemon.** `fresh --wait <file>` opens a fresh,
  blocking, standalone instance — it's a separate invocation from the `open-fresh`/
  `open-fresh-tab` daemon-attached session. That's intentional: `core.editor` needs a process
  that exits when the buffer closes, which a long-lived daemon attach does not do.
- **Reverting:** `git config --global --unset core.editor` (or `--local`), or re-run the helper
  pointed at your previous editor value.
