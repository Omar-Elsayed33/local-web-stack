<#
.SYNOPSIS
    Adds local development domains to the Windows hosts file.

.DESCRIPTION
    Ensures each domain in $Domains points to 127.0.0.1 in the hosts file.
    Existing entries are left untouched (no duplicates are created).
    Must be run from an elevated (Administrator) PowerShell session.

.EXAMPLE
    # In an Administrator PowerShell:
    ./scripts/add-host.ps1
#>

# Add or remove domains here as your projects grow.
$Domains = @(
    "demo.test",
    "pma.test",
    "mail.test"
)

$HostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"

# --- Require Administrator ---------------------------------------------------
$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$isAdmin   = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator." -ForegroundColor Red
    Write-Host "Right-click PowerShell and choose 'Run as administrator', then re-run this script." -ForegroundColor Yellow
    exit 1
}

# --- Add missing entries -----------------------------------------------------
$existing = Get-Content -Path $HostsPath -ErrorAction SilentlyContinue

foreach ($domain in $Domains) {
    # Match the domain as a whole word anywhere on a non-comment line.
    $alreadyPresent = $existing | Where-Object {
        $_ -notmatch '^\s*#' -and $_ -match "\b$([regex]::Escape($domain))\b"
    }

    if ($alreadyPresent) {
        Write-Host "SKIP : $domain already present." -ForegroundColor DarkGray
        continue
    }

    $entry = "127.0.0.1`t$domain"
    Add-Content -Path $HostsPath -Value $entry
    Write-Host "ADDED: $entry" -ForegroundColor Green
}

Write-Host ""
Write-Host "Done. You may need to flush DNS: ipconfig /flushdns" -ForegroundColor Cyan
