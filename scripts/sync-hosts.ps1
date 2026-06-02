<#
.SYNOPSIS
    Add a local domain for every folder in www/ (plus phpMyAdmin and Mailpit)
    to the Windows hosts file. Self-elevates via UAC — no need to manually open
    an Administrator shell.

.DESCRIPTION
    For each folder inside www/ it builds "<folder><DOMAIN_SUFFIX>" and ensures
    the hosts file points it at 127.0.0.1. Also adds PHPMYADMIN_DOMAIN and
    MAILPIT_DOMAIN. Values are read from .env (falling back to .env.example).
    Existing entries are left untouched (no duplicates).

.EXAMPLE
    ./scripts/sync-hosts.ps1
    powershell -ExecutionPolicy Bypass -File scripts/sync-hosts.ps1
#>

$ErrorActionPreference = 'Stop'

$Self      = $MyInvocation.MyCommand.Path
$ScriptDir = Split-Path -Parent $Self
$Root      = Split-Path -Parent $ScriptDir
$HostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
$LogFile   = Join-Path $env:TEMP "local-web-stack-sync-hosts.log"

# --- Self-elevate if not Administrator ---------------------------------------
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Requesting administrator privileges (accept the UAC prompt)..." -ForegroundColor Yellow
    if (Test-Path $LogFile) { Remove-Item $LogFile -Force -ErrorAction SilentlyContinue }
    try {
        $proc = Start-Process powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList @(
            "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$Self`"")
    } catch {
        Write-Host "Elevation was cancelled. The hosts file was not changed." -ForegroundColor Red
        exit 1
    }
    # Relay the elevated run's output into this (original) window.
    if (Test-Path $LogFile) { Get-Content $LogFile | ForEach-Object { Write-Host $_ } }
    exit $proc.ExitCode
}

# --- (Elevated) do the work --------------------------------------------------
Set-Content -Path $LogFile -Value "" -Encoding Ascii   # reset log
function Log([string]$msg) {
    Write-Host $msg
    Add-Content -Path $LogFile -Value $msg -Encoding Ascii
}

$envFile = Join-Path $Root ".env"
if (-not (Test-Path $envFile)) { $envFile = Join-Path $Root ".env.example" }

function Get-EnvVal([string]$key, [string]$default) {
    $m = Select-String -Path $envFile -Pattern "^\s*$([regex]::Escape($key))=" -ErrorAction SilentlyContinue |
         Select-Object -Last 1
    if (-not $m) { return $default }
    $v = ($m.Line -split '=', 2)[1].Trim().Trim('"').Trim("'")
    if ([string]::IsNullOrWhiteSpace($v)) { return $default } else { return $v }
}

$suffix = Get-EnvVal "DOMAIN_SUFFIX" ".local"
$pma    = Get-EnvVal "PHPMYADMIN_DOMAIN" "pma.local"
$mail   = Get-EnvVal "MAILPIT_DOMAIN" "mail.local"

Log "Project root : $Root"
Log "Env file     : $envFile"
Log "Hosts file   : $HostsFile"
Log "Domain suffix: $suffix"
Log ""

# --- Collect domains ---------------------------------------------------------
$domains = New-Object System.Collections.Generic.List[string]
$wwwDir  = Join-Path $Root "www"

Log "Found projects in www/:"
if (Test-Path $wwwDir) {
    foreach ($d in Get-ChildItem -Path $wwwDir -Directory) {
        $dom = "$($d.Name)$suffix"
        $domains.Add($dom)
        Log "  - $($d.Name) => $dom"
    }
} else {
    Log "  (www/ not found)"
}
$domains.Add($pma)
$domains.Add($mail)
Log "  - phpMyAdmin => $pma"
Log "  - Mailpit    => $mail"
Log ""

# --- Apply entries -----------------------------------------------------------
# Ensure the hosts file ends with a newline so an append never glues onto the
# last existing entry.
$bytes = [System.IO.File]::ReadAllBytes($HostsFile)
if ($bytes.Length -gt 0 -and $bytes[-1] -ne 10) { Add-Content -Path $HostsFile -Value "" }

$existing = Get-Content -Path $HostsFile -ErrorAction SilentlyContinue

Log "Syncing hosts entries:"
try {
    foreach ($dom in $domains) {
        if ([string]::IsNullOrWhiteSpace($dom)) { continue }
        $pattern = "\b$([regex]::Escape($dom))\b"
        $present = $existing | Where-Object { $_ -notmatch '^\s*#' -and $_ -match $pattern }
        if ($present) {
            Log "  exists : $dom"
        } else {
            Add-Content -Path $HostsFile -Value "127.0.0.1`t$dom"
            $existing = @($existing) + "127.0.0.1`t$dom"
            Log "  added  : $dom"
        }
    }
} catch {
    Log ("ERROR: " + $_.Exception.Message)
    Log ("AT: " + $_.ScriptStackTrace)
    exit 1
}
Log ""

ipconfig /flushdns | Out-Null
Log "Hosts file is up to date."
