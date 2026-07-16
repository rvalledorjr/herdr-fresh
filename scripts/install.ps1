# [[build]] step (windows): verify `fresh` is available before the plugin is considered
# installed. Mirrors install.sh's M5 auto-install fallback: try the official winget package,
# else fail loudly with a clear pointer.
param()

$ErrorActionPreference = 'Stop'

function Test-CommandExists {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

if (Test-CommandExists 'fresh') {
    $ver = (& fresh --help 2>&1 | Select-Object -First 1)
    Write-Host "herdr-fresh: found fresh ($ver); build check passed."
    exit 0
}

Write-Host "herdr-fresh: 'fresh' was not found on PATH. Attempting install via winget..."

if (Test-CommandExists 'winget') {
    try {
        winget install --id fresh-editor -e --accept-source-agreements --accept-package-agreements
    } catch {
        Write-Warning "herdr-fresh: winget install failed: $_"
    }
}

if (Test-CommandExists 'fresh') {
    $ver = (& fresh --help 2>&1 | Select-Object -First 1)
    Write-Host "herdr-fresh: installed fresh via winget ($ver); build check passed."
    exit 0
}

Write-Error "herdr-fresh: 'fresh' still not found on PATH. Install Fresh from https://getfresh.dev (e.g. 'winget install fresh-editor') and re-run 'herdr plugin install'."
exit 1
