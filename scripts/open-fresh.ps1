# Idempotent launcher for the `open-fresh-windows` action: open Fresh in a split beside the
# current pane, or focus it if a Fresh pane for this workspace is already open in the current
# tab. Windows port of open-fresh.sh.
#
# Windows has no [[panes]] entry (PLAN.md §3.3 gotcha #3 — herdr can't spawn a relative pane
# command via CreateProcessW), so this script does the split *and* the pane-run itself: it
# splits a plain pane, then runs run-fresh-daemon.ps1 inside it by absolute path (resolved via
# `herdr plugin list --json`, the same lookup gotcha #3 requires for every Windows launcher).
param()

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir 'common.ps1')

$daemon = Get-DaemonName

function Open-Pane {
    $root = Resolve-PluginRoot
    if (-not $root) {
        Write-Error "herdr-fresh: could not resolve plugin root via 'herdr plugin list --json'."
        exit 1
    }
    $daemonScript = Join-Path $root 'scripts\run-fresh-daemon.ps1'
    $cwd = Resolve-Cwd

    $splitJson = Get-HerdrJson pane split --direction right --cwd $cwd --focus
    $paneId = $splitJson.result.pane_id
    if (-not $paneId) { $paneId = $splitJson.result.pane.pane_id }
    if (-not $paneId) {
        Write-Error "herdr-fresh: 'herdr pane split' did not return a pane id."
        exit 1
    }

    $cmd = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$daemonScript`""
    Invoke-Herdr pane run $paneId $cmd | Out-Null
    exit 0
}

$panesJson = Get-HerdrJson pane list
$currentJson = Get-HerdrJson pane current
$currentPaneId = $currentJson.result.pane.pane_id
$currentTabId = $currentJson.result.pane.tab_id

$freshPaneId = $null
if ($panesJson -and $currentTabId) {
    $match = $panesJson.result.panes | Where-Object { $_.tab_id -eq $currentTabId -and $_.label -eq $daemon } | Select-Object -First 1
    if ($match) { $freshPaneId = $match.pane_id }
}

if (-not $freshPaneId) {
    Open-Pane
} elseif ($freshPaneId -eq $currentPaneId) {
    # Already focused on the Fresh pane: nothing to do.
    exit 0
} else {
    Invoke-Herdr pane zoom $freshPaneId --on | Out-Null
    Invoke-Herdr pane zoom $freshPaneId --off | Out-Null
    exit 0
}
