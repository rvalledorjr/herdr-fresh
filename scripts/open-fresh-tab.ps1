# Idempotent launcher for `open-fresh-tab-windows`: open Fresh in its own tab, or switch to it
# if already open anywhere in this workspace. Windows port of open-fresh-tab.sh; sibling of
# open-fresh.ps1 (see that file's header for the no-[[panes]]-on-Windows rationale).
param()

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir 'common.ps1')

$daemon = Get-DaemonName

function Open-Tab {
    $root = Resolve-PluginRoot
    if (-not $root) {
        Write-Error "herdr-fresh: could not resolve plugin root via 'herdr plugin list --json'."
        exit 1
    }
    $daemonScript = Join-Path $root 'scripts\run-fresh-daemon.ps1'
    $cwd = Resolve-Cwd

    $tabJson = Get-HerdrJson pane tab --cwd $cwd --focus
    $paneId = $tabJson.result.pane_id
    if (-not $paneId) { $paneId = $tabJson.result.pane.pane_id }
    if (-not $paneId) {
        Write-Error "herdr-fresh: 'herdr pane tab' did not return a pane id."
        exit 1
    }

    $cmd = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$daemonScript`""
    Invoke-Herdr pane run $paneId $cmd | Out-Null
    exit 0
}

$panesJson = Get-HerdrJson pane list
$currentJson = Get-HerdrJson pane current
$currentPaneId = $currentJson.result.pane.pane_id
$currentWorkspaceId = $currentJson.result.pane.workspace_id

$match = $null
if ($panesJson) {
    $match = $panesJson.result.panes | Where-Object { $_.workspace_id -eq $currentWorkspaceId -and $_.label -eq $daemon } | Select-Object -First 1
}

if (-not $match) {
    Open-Tab
}

$freshPaneId = $match.pane_id
$freshTabId = $match.tab_id

if ($freshPaneId -eq $currentPaneId) {
    # Already focused on the Fresh pane: nothing to do.
    exit 0
} elseif ($freshTabId) {
    try { Invoke-Herdr tab focus $freshTabId | Out-Null } catch { Open-Tab }
    exit 0
} else {
    Open-Tab
}
