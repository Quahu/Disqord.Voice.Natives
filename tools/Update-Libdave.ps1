#!/usr/bin/env pwsh
param(
    [string] $Tag
)

$ErrorActionPreference = "Stop"

$Repo = "discord/libdave"
$RepoRoot = Split-Path $PSScriptRoot
$BuildDir = Join-Path $RepoRoot ".build"
$LibDir = Join-Path $RepoRoot "lib"
$LicensesDir = Join-Path $LibDir "licenses"

$AssetMap = @(
    @{ Asset = "libdave-Windows-X64-boringssl"; Rid = "win-x64"; LibName = "libdave.dll" }
    @{ Asset = "libdave-Linux-X64-boringssl"; Rid = "linux-x64"; LibName = "libdave.so" }
    @{ Asset = "libdave-Linux-ARM64-boringssl"; Rid = "linux-arm64"; LibName = "libdave.so" }
    @{ Asset = "libdave-macOS-X64-boringssl"; Rid = "osx-x64"; LibName = "libdave.dylib" }
    @{ Asset = "libdave-macOS-ARM64-boringssl"; Rid = "osx-arm64"; LibName = "libdave.dylib" }
)

$gh = Get-Command gh -ErrorAction SilentlyContinue
if (-not $gh) {
    throw "'gh' (GitHub CLI) not available"
}

if (-not $Tag) {
    Write-Host "Finding latest release..."
    $Tag = & gh release list --repo $Repo --limit 1 --json tagName --jq ".[0].tagName"
    if ($LASTEXITCODE -ne 0 -or -not $Tag) {
        throw "Failed to find latest release."
    }
}

Write-Host "Using release: $Tag"

$downloadDir = Join-Path $BuildDir "libdave-release"
if (Test-Path $downloadDir) {
    Remove-Item $downloadDir -Recurse -Force 
}

New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null

$patterns = ($AssetMap | ForEach-Object { "--pattern"; "$($_.Asset).zip" })
Write-Host "Downloading assets..."
& gh release download $Tag --repo $Repo --dir $downloadDir @patterns
if ($LASTEXITCODE -ne 0) {
    throw "gh release download failed."
}

$succeeded = @()
$failed = @()
$licensesUpdated = $false

foreach ($entry in $AssetMap) {
    $rid = $entry.Rid
    $libName = $entry.LibName
    $zipPath = Join-Path $downloadDir "$($entry.Asset).zip"
    $extractDir = Join-Path $downloadDir $entry.Asset

    if (-not (Test-Path $zipPath)) {
        Write-Host "[$rid] FAILED: $($entry.Asset).zip not found" -ForegroundColor Red
        $failed += $rid
        continue
    }

    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
    Remove-Item $zipPath

    $srcLib = Join-Path $extractDir "bin" $libName
    if (-not (Test-Path $srcLib)) {
        $found = Get-ChildItem -Path $extractDir -Recurse -Filter $libName -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $srcLib = $found.FullName }
        else {
            Write-Host "[$rid] FAILED: $libName not found in archive" -ForegroundColor Red
            $failed += $rid
            continue
        }
    }

    $destDir = Join-Path $LibDir $rid
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    Copy-Item $srcLib (Join-Path $destDir $libName) -Force

    $sizeKB = [Math]::Round((Get-Item (Join-Path $destDir $libName)).Length / 1KB)
    Write-Host "[$rid] OK -> lib/$rid/$libName ($sizeKB KB)" -ForegroundColor Green
    $succeeded += $rid

    if (-not $licensesUpdated) {
        $srcLicenses = Join-Path $extractDir "licenses"
        if (Test-Path $srcLicenses) {
            New-Item -ItemType Directory -Path $LicensesDir -Force | Out-Null
            Get-ChildItem $srcLicenses | Copy-Item -Destination $LicensesDir -Force
            Write-Host "  Updated lib/licenses/"
            $licensesUpdated = $true
        }
    }
}

Remove-Item $downloadDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`n--- Results ---"
if ($succeeded.Count -gt 0) {
    Write-Host "  Succeeded: $($succeeded -join ', ')" -ForegroundColor Green
}
if ($failed.Count -gt 0) {
    Write-Host "  Failed:    $($failed -join ', ')" -ForegroundColor Red
    exit 1
}

Write-Host "`nDone. Libraries are in lib/{rid}/."
