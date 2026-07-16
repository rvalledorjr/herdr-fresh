# Shared helpers for the herdr-fresh Windows launcher scripts (PowerShell port of common.sh).
#
# herdr injects the same two things into an action's process on Windows as on Unix:
# `$env:HERDR_BIN_PATH` (path to the herdr binary — fall back to `herdr` on PATH) and
# `$env:HERDR_PLUGIN_CONTEXT_JSON` (cwd/workspace info). PowerShell has native JSON support
# (ConvertFrom-Json), so unlike the bash scripts, none of this needs `jq`.
#
# Windows gotcha #3 (PLAN.md §3.3): herdr can't spawn a *relative* pane/action command on
# Windows (CreateProcessW resolves it against herdr's own directory, not the plugin's). So
# every Windows action's `command` in herdr-plugin.toml is a small inline bootstrap that first
# resolves this plugin's absolute root via `herdr plugin list --json`, then dot-sources this
# file and invokes the real launcher by absolute path. Resolve-PluginRoot below is that lookup,
# reused by every windows script that needs to find a *sibling* script by absolute path (e.g.
# open-fresh.ps1 invoking run-fresh-daemon.ps1 inside a freshly split pane).

$ErrorActionPreference = 'Stop'

$script:HerdrBin = if ($env:HERDR_BIN_PATH) { $env:HERDR_BIN_PATH } else { 'herdr' }

function Invoke-Herdr {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    $out = & $script:HerdrBin @Args 2>$null
    return $out
}

function Get-HerdrJson {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    $raw = Invoke-Herdr @Args
    if (-not $raw) { return $null }
    try { return ($raw | ConvertFrom-Json -ErrorAction Stop) } catch { return $null }
}

# Resolve this plugin's absolute install root via `herdr plugin list --json` (gotcha #3 — never
# trust a relative $PSScriptRoot-derived path when herdr itself launched us with one).
function Resolve-PluginRoot {
    $json = Get-HerdrJson plugin list --json
    if (-not $json) { return $null }
    $plugin = $json.result.plugins | Where-Object { $_.plugin_id -eq 'herdr-fresh' } | Select-Object -First 1
    if ($plugin) { return $plugin.plugin_root }
    return $null
}

# --- Optional config.toml (PLAN.md M4) --------------------------------------------------------
#
# Same file-location and trust conventions as the Unix side: $HERDR_PLUGIN_CONFIG_DIR
# (herdr-provided, wins outright), else $XDG_CONFIG_HOME\herdr-fresh\config.toml, else
# $HOME\.config\herdr-fresh\config.toml. A relative fallback is never read — that would source a
# "trusted" config from a possibly-untrusted repo's cwd. Missing/unparseable config is silently
# equivalent to "no config": every key uses its default. Parsing needs `python` or `python3` (for
# stdlib `tomllib`, Python 3.11+); if neither is available, config is treated as absent.

function Get-ConfigDir {
    if ($env:HERDR_PLUGIN_CONFIG_DIR) { return $env:HERDR_PLUGIN_CONFIG_DIR }
    if ($env:XDG_CONFIG_HOME) { return Join-Path $env:XDG_CONFIG_HOME 'herdr-fresh' }
    if ($HOME) { return Join-Path (Join-Path $HOME '.config') 'herdr-fresh' }
    return $null
}

function Get-ConfigPath {
    $dir = Get-ConfigDir
    if (-not $dir) { return $null }
    return Join-Path $dir 'config.toml'
}

$script:ConfigObj = $null
$script:ConfigLoaded = $false

function Get-ConfigObj {
    if ($script:ConfigLoaded) { return $script:ConfigObj }
    $script:ConfigLoaded = $true
    $script:ConfigObj = @{}

    $path = Get-ConfigPath
    if (-not $path -or -not ([System.IO.Path]::IsPathRooted($path)) -or -not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return $script:ConfigObj
    }

    $py = Get-Command python3 -ErrorAction SilentlyContinue
    if (-not $py) { $py = Get-Command python -ErrorAction SilentlyContinue }
    if (-not $py) { return $script:ConfigObj }

    $pyScript = @'
import json
import sys
try:
    import tomllib
except ImportError:
    print("{}")
    sys.exit(0)
try:
    with open(sys.argv[1], "rb") as f:
        data = tomllib.load(f)
except Exception:
    print("{}")
    sys.exit(0)
print(json.dumps(data))
'@
    try {
        $json = & $py.Source -c $pyScript $path 2>$null
        if ($json) { $script:ConfigObj = $json | ConvertFrom-Json -AsHashtable -ErrorAction Stop }
    } catch {
        $script:ConfigObj = @{}
    }
    return $script:ConfigObj
}

function Get-ConfigValue {
    param([string]$Key, $Default)
    $cfg = Get-ConfigObj
    if ($cfg.ContainsKey($Key) -and $null -ne $cfg[$Key] -and $cfg[$Key] -ne '') {
        return $cfg[$Key]
    }
    return $Default
}

# FreshBin: which `fresh` binary to run (config `fresh_bin`, default "fresh" off PATH).
function Get-FreshBin {
    return (Get-ConfigValue -Key 'fresh_bin' -Default 'fresh')
}

# FreshArgs: extra CLI args to append when launching `fresh -a <daemon>` inside the pane
# (config `fresh_args`, an array of strings). Returns an array (possibly empty).
function Get-FreshArgs {
    $val = Get-ConfigValue -Key 'fresh_args' -Default @()
    if ($val -is [array]) { return $val }
    return @()
}

# Resolve the herdr workspace id from the injected context JSON, falling back to `pane current`
# and finally to a hash of the cwd so the daemon name is stable even with no workspace id at all.
function Resolve-WorkspaceId {
    $wid = $null
    if ($env:HERDR_PLUGIN_CONTEXT_JSON) {
        try {
            $ctx = $env:HERDR_PLUGIN_CONTEXT_JSON | ConvertFrom-Json -ErrorAction Stop
            if ($ctx.workspace_id) { $wid = $ctx.workspace_id }
        } catch {}
    }
    if (-not $wid) {
        $cur = Get-HerdrJson pane current
        if ($cur -and $cur.result.pane.workspace_id) { $wid = $cur.result.pane.workspace_id }
    }
    if (-not $wid) {
        $hash = [System.BitConverter]::ToString(
            [System.Security.Cryptography.MD5]::Create().ComputeHash(
                [System.Text.Encoding]::UTF8.GetBytes((Get-Location).Path)
            )
        ) -replace '-', ''
        $wid = $hash.Substring(0, 8).ToLowerInvariant()
    }
    return $wid
}

# Resolve the directory to open Fresh in: prefer the context's cwd fields, else process cwd.
function Resolve-Cwd {
    $dir = $null
    if ($env:HERDR_PLUGIN_CONTEXT_JSON) {
        try {
            $ctx = $env:HERDR_PLUGIN_CONTEXT_JSON | ConvertFrom-Json -ErrorAction Stop
            $dir = $ctx.focused_pane_cwd
            if (-not $dir) { $dir = $ctx.workspace_cwd }
            if (-not $dir) { $dir = $ctx.cwd }
        } catch {}
    }
    if (-not $dir) { $dir = (Get-Location).Path }
    return $dir
}

# The fresh daemon name for this context (PLAN.md §4.2), configurable via config.toml:
#   daemon_name_prefix (string, default "fresh")
#   daemon_name        ("per-workspace" (default) | "per-repo")
function Get-DaemonName {
    $prefix = Get-ConfigValue -Key 'daemon_name_prefix' -Default 'fresh'
    $mode = Get-ConfigValue -Key 'daemon_name' -Default 'per-workspace'
    if ($mode -eq 'per-repo') {
        $hash = [System.BitConverter]::ToString(
            [System.Security.Cryptography.MD5]::Create().ComputeHash(
                [System.Text.Encoding]::UTF8.GetBytes((Resolve-Cwd))
            )
        ) -replace '-', ''
        return "$prefix-$($hash.Substring(0, 8).ToLowerInvariant())"
    }
    return "$prefix-$(Resolve-WorkspaceId)"
}
