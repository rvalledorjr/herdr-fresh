# Windows port of open-file-in-fresh.sh: push `path:line:col` into the running Fresh daemon for
# this workspace, ensuring the pane exists first (PLAN.md M3/M5). Takes the target as the first
# CLI argument.
param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$Target
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir 'common.ps1')

if (-not $Target) {
    Write-Error "usage: open-file-in-fresh.ps1 <path[:line[:col]]>"
    exit 1
}

$daemon = Get-DaemonName
$freshBin = Get-FreshBin

function Test-DaemonExists {
    $list = & $freshBin --cmd daemon list 2>$null
    if (-not $list) { return $false }
    return ($list -split "`n" | Where-Object { $_.Trim() -eq $daemon }).Count -gt 0
}

if (-not (Test-DaemonExists)) {
    & (Join-Path $scriptDir 'open-fresh.ps1')
    # Wait for the daemon to register (it appears once Fresh finishes booting inside the pane).
    for ($i = 0; $i -lt 50; $i++) {
        if (Test-DaemonExists) { break }
        Start-Sleep -Milliseconds 200
    }
}

& $freshBin --cmd daemon open-file $daemon $Target

$panesJson = Get-HerdrJson pane list
$freshPaneId = $null
if ($panesJson) {
    $match = $panesJson.result.panes | Where-Object { $_.label -eq $daemon } | Select-Object -First 1
    if ($match) { $freshPaneId = $match.pane_id }
}

if ($freshPaneId) {
    try {
        Invoke-Herdr pane zoom $freshPaneId --on | Out-Null
        Invoke-Herdr pane zoom $freshPaneId --off | Out-Null
    } catch {}
}
