# Usage

Three actions, all invoked the same way once bound to a key (see [install.md](install.md)):

```
herdr plugin action invoke <action-id> --plugin herdr-fresh
```

## Split vs. tab

| Action | Effect on first invocation | Effect if the workspace's Fresh pane is already open |
|---|---|---|
| `open-fresh` | Splits a pane beside the current one, boots Fresh inside it. | Zooms/focuses the existing pane in place — never opens a second one. |
| `open-fresh-tab` | Opens a new tab, boots Fresh inside it. | Switches to the existing tab — never opens a second one. |

Both are idempotent per **herdr workspace** (or per-repo if you've set
`daemon_name = "per-repo"` — see [configuration.md](configuration.md)): re-invoking either
action from the same workspace always lands you back on the one Fresh pane for that workspace,
it doesn't spawn duplicates. Matching is done by the pane's self-assigned `label`
(`fresh-<id>`), set by `scripts/run-fresh-daemon.sh` right after Fresh starts.

## Open a file at a line

```bash
herdr plugin action invoke open-file-in-fresh --plugin herdr-fresh -- path/to/file.rs:42:8
```

(`:col` is optional; `path/to/file.rs:42` or a bare path also work — anything Fresh's own CLI
argument parsing accepts.)

What happens:

1. If the workspace's Fresh daemon isn't running yet, it invokes `open-fresh` first (opening the
   split pane) and polls `fresh --cmd daemon list` for up to ~10s for it to register.
2. Runs `fresh --cmd daemon open-file <daemon> <target>` to push the file into the *already
   running* editor — no new window, no new daemon.
3. Brings the Fresh pane forward (`pane zoom` on/off) so you land on the opened file.

Useful wired up to other tools/agents that want to say "show me this file at this line" without
caring whether Fresh is already open.

## Persistent editing sessions (daemons)

Every workspace gets one named Fresh daemon (`fresh-<workspace-id>` by default), created the
first time you open the pane and reattached to on every subsequent open — including after
closing the pane or reattaching to the herdr session later. This is what gives you Hot-Exit-like
persistence: unsaved buffers, open files, and Fresh's own state all survive a pane close.

Useful daemon commands (run from any shell, not just inside herdr):

```bash
fresh --cmd daemon list                 # see every running daemon
fresh --cmd daemon info fresh-<id>      # status of one
fresh --cmd daemon kill fresh-<id>      # tear one down (e.g. before a config change takes effect)
```

## Remote / SSH editing, Git review, LSP, etc.

Everything Fresh itself supports beyond the three actions above — Git review mode, LSP,
project-wide search/replace, remote editing over SSH — is available inside the pane exactly as
it is when running Fresh directly, since herdr-fresh doesn't wrap or restrict Fresh's own
features. See <https://getfresh.dev> for Fresh's own docs. (A dedicated herdr action for
launching straight into Fresh's Git-review mode or an SSH target is tracked as post-v1 backlog
in [PLAN.md](../PLAN.md).)
