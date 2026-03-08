#!/usr/bin/env pwsh
param(
    [switch] $SkipLibdave,
    [switch] $SkipLibsodium
)

$ErrorActionPreference = "Stop"
$toolsDir = $PSScriptRoot

if (-not $SkipLibdave) {
    Write-Host "--- libdave ---" -ForegroundColor Magenta
    & "$toolsDir\Update-Libdave.ps1"
    if ($LASTEXITCODE -ne 0) { 
        exit $LASTEXITCODE 
    }

    Write-Host ""
}

if (-not $SkipLibsodium) {
    Write-Host "--- libsodium ---" -ForegroundColor Magenta
    & "$toolsDir\Update-Libsodium.ps1"
    if ($LASTEXITCODE -ne 0) { 
        exit $LASTEXITCODE 
    }

    Write-Host ""
}

Write-Host "Done." -ForegroundColor Magenta
