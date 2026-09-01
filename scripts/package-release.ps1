# Package Windows build output into a release archive (RioGram-style naming).
param(
    [Parameter(Mandatory = $true)][string]$Version,
    [Parameter(Mandatory = $true)][string]$OutputDir
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot
$AppDir = if ($env:APP_DIR) { $env:APP_DIR } else { "secure_vpn_client" }
$SourceDir = Join-Path $RootDir "$AppDir\build\windows\x64\runner\Release"
$Archive = Join-Path $OutputDir "RioNexTunnel-$Version-windows-x64.zip"

if (-not (Test-Path $SourceDir)) {
    throw "Build directory not found: $SourceDir"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
if (Test-Path $Archive) { Remove-Item $Archive }

Compress-Archive -Path (Join-Path $SourceDir "*") -DestinationPath $Archive -Force
Write-Host "Packaged windows -> $Archive"
