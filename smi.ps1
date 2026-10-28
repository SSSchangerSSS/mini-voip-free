# smi.ps1 — Windows entry point for the delivery-command contract (PROJECT_SPEC section 13).
# Runs what Windows can support natively; delegates Linux-only operations to WSL with an explicit message.
# Exit codes: 0 ok | 1 error | 2 invalid input/prereq | 3 blocked
param(
  [Parameter(Position = 0)][string]$Command,
  [Parameter(Position = 1, ValueFromRemainingArguments = $true)][string[]]$Rest
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

function Blocked([string]$Msg) {
  Write-Host "BLOCKED: $Msg" -ForegroundColor Yellow
  exit 3
}
function NotImpl([string]$Msg) {
  Write-Host "NOT_IMPLEMENTED: $Msg" -ForegroundColor Yellow
  exit 2
}

switch ($Command) {
  "doctor" {
    $wsl = Get-Command wsl -ErrorAction SilentlyContinue
    if ($wsl) {
      Write-Host "Delegating doctor to WSL (Linux-only checks: ports, clock, DNS, systemd)..."
      wsl bash -lc "cd /mnt/$($Root.Substring(0,1).ToLower())$($Root.Substring(2).Replace('\','/')) && ./smi doctor $($Rest -join ' ')"
      exit $LASTEXITCODE
    }
    Write-Host "Partial Windows checks:" -ForegroundColor Cyan
    $dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
    if ($dotnet) { Write-Host "  PASS dotnet $(dotnet --version)" } else { Write-Host "  FAIL dotnet not found" }
    $flutter = Get-Command flutter -ErrorAction SilentlyContinue
    if ($flutter) { Write-Host "  PASS flutter" } else { Write-Host "  BLOCKED flutter not found (needed for mobile builds)" }
    Write-Host "  BLOCKED docker/ports/secret checks need WSL or a Linux host."
    exit 0
  }
  "test" {
    $sub = if ($Rest.Count -gt 0) { $Rest[0] } else { "" }
    switch ($sub) {
      "unit" {
        Push-Location "$Root/services/control"
        try { dotnet test --nologo } finally { Pop-Location }
        exit $LASTEXITCODE
      }
      "integration" { Blocked "integration suite requires a live PBX + real devices (P2)." }
      default { exit 2 }
    }
  }
  "build" {
    $target = if ($Rest.Count -gt 0) { $Rest[0] } else { "" }
    switch ($target) {
      "android" {
        $flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
        if (-not $flutterCmd) { Blocked "flutter not installed." }
        Push-Location "$Root/apps/mobile"
        try { flutter build apk --release --split-per-abi } finally { Pop-Location }
        exit $LASTEXITCODE
      }
      "ios" { Blocked "iOS build requires macOS/Xcode (PROJECT_SPEC section 16.3). Use a macOS runner or machine." }
      default { exit 2 }
    }
  }
  "server" { Blocked "server lifecycle commands are Linux-only (host-networking Compose). Run ./smi server ... on the server (or via WSL/SSH with an explicit target)." }
  "extension" { Blocked "extension provisioning touches PBX config and AMI; run on the server host." }
  "device"   { Blocked "device reset touches PBX config and AMI; run on the server host." }
  "backup"   { Blocked "backup must run on the server host against the live SQLite volume." }
  "restore"  { Blocked "restore must run on the server host." }
  "upgrade"  { Blocked "upgrade/rollback must run on the server host." }
  "rollback" { Blocked "upgrade/rollback must run on the server host." }
  "verify-release" {
    $mf = $null
    for ($i = 0; $i -lt $Rest.Count; $i++) { if ($Rest[$i] -eq "--manifest" -and $i + 1 -lt $Rest.Count) { $mf = $Rest[$i + 1] } }
    if (-not $mf) { NotImpl "verify-release needs --manifest <file>." }
    & python "$Root/scripts/release/verify_manifest.py" --manifest $mf
    exit $LASTEXITCODE
  }
  default {
    Write-Host "Usage: ./smi.ps1 <doctor|test|build|verify-release> [args]"
    Write-Host "Linux-only commands (server/extension/device/backup/restore/upgrade/rollback) are blocked on Windows by design."
    if ($null -eq $Command -or $Command -eq "") { exit 0 } else { exit 2 }
  }
}
