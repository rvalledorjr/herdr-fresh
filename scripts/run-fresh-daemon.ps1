# The Windows equivalent of run-fresh-daemon.sh — runs INSIDE the freshly split/tab'd pane
# (invoked there by open-fresh.ps1 / open-fresh-tab.ps1 via `herdr pane run <pane_id> <cmd>`,
# since Windows has no [[panes]] entry — see herdr-plugin.toml / PLAN.md §3.3 gotcha #3).
#
# `fresh -a <name>` both creates the named daemon (first run) and reattaches to it (subsequent
# runs) — same "one persistent editing session per workspace" contract as the Unix side
# (PLAN.md §4.2). Requires a real console/PTY to create the daemon (gotcha #1), which is why
# this only ever runs inside a pane herdr already gave a terminal to, never headless.
param()

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir 'common.ps1')

$daemon = Get-DaemonName

try {
    Set-Location (Resolve-Cwd) -ErrorAction Stop
} catch {}

# Label our own pane so other launcher scripts can find it later. Best-effort: if `pane current`
# can't resolve (e.g. run outside herdr for local testing), Fresh still starts normally.
try {
    $cur = Get-HerdrJson pane current
    $selfPaneId = $cur.result.pane.pane_id
    if ($selfPaneId) {
        Invoke-Herdr pane rename $selfPaneId $daemon | Out-Null
    }
} catch {}

$freshBin = Get-FreshBin
$freshArgs = @('-a', $daemon) + (Get-FreshArgs)
& $freshBin @freshArgs
exit $LASTEXITCODE
