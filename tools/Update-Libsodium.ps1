#!/usr/bin/env pwsh
param(
    [string] $Tag,
    [string] $ZigVersion = "0.15.2",
    [switch] $Clean
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$Repo = "jedisct1/libsodium"
$RepoRoot = Split-Path $PSScriptRoot
$BuildDir = Join-Path $RepoRoot ".build"
$LibDir = Join-Path $RepoRoot "lib"

$Targets = @(
    @{ Rid = "win-x64"; ZigTarget = "x86_64-windows-gnu"; LibName = "libsodium.dll" }
    @{ Rid = "linux-x64"; ZigTarget = "x86_64-linux-gnu"; LibName = "libsodium.so" }
    @{ Rid = "linux-arm64"; ZigTarget = "aarch64-linux-gnu"; LibName = "libsodium.so" }
    @{ Rid = "osx-x64"; ZigTarget = "x86_64-macos"; LibName = "libsodium.dylib" }
    @{ Rid = "osx-arm64"; ZigTarget = "aarch64-macos"; LibName = "libsodium.dylib" }
)

$gh = Get-Command gh -ErrorAction SilentlyContinue
if (-not $gh) {
    throw "'gh' (GitHub CLI) not available"
}

function Resolve-ZigExe {
    $existing = Get-Command zig -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "Using Zig from PATH: $($existing.Source)"
        return $existing.Source
    }

    $zigDir = Join-Path $BuildDir "zig"
    $zigExe = Join-Path $zigDir "zig.exe"
    if (Test-Path $zigExe) {
        Write-Host "Using cached Zig: $zigExe"
        return $zigExe
    }

    Write-Host "Downloading Zig $ZigVersion..."
    New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null

    $arch = if ([Environment]::Is64BitOperatingSystem) { "x86_64" } else { "x86" }
    $zipUrl = "https://ziglang.org/download/$ZigVersion/zig-$arch-windows-$ZigVersion.zip"
    $zipPath = Join-Path $BuildDir "zig.zip"

    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath
    Expand-Archive -Path $zipPath -DestinationPath $BuildDir -Force
    Remove-Item $zipPath

    $extracted = Join-Path $BuildDir "zig-$arch-windows-$ZigVersion"
    if (Test-Path $extracted) {
        if (Test-Path $zigDir) { Remove-Item $zigDir -Recurse -Force }
        Rename-Item $extracted $zigDir
    }

    if (-not (Test-Path $zigExe)) {
        throw "Zig extraction failed — $zigExe not found."
    }

    return $zigExe
}

function Resolve-SodiumSource {
    if (-not $Tag) {
        Write-Host "Finding latest release..."
        $Tag = & gh release list --repo $Repo --limit 1 --json tagName --jq ".[0].tagName"
        if ($LASTEXITCODE -ne 0 -or -not $Tag) {
            throw "Failed to find latest libsodium release."
        }
    }

    Write-Host "Using release: $Tag"

    $sodiumDir = Join-Path $BuildDir "libsodium-$Tag"
    if (Test-Path (Join-Path $sodiumDir "build.zig")) {
        Write-Host "Using cached source: $sodiumDir"
        return $sodiumDir
    }

    Write-Host "Downloading source..."
    New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null

    $tarPath = Join-Path $BuildDir "libsodium.tar.gz"
    & gh release download $Tag --repo $Repo --archive tar.gz --output $tarPath
    if ($LASTEXITCODE -ne 0) {
        throw "gh release download failed."
    }

    if (Test-Path $sodiumDir) { Remove-Item $sodiumDir -Recurse -Force }
    tar -xzf $tarPath -C $BuildDir
    Remove-Item $tarPath

    # GitHub archives extract to {repo}-{hash}/ — rename to our expected dir
    $extracted = Get-ChildItem -Path $BuildDir -Directory -Filter "libsodium-*" |
        Where-Object { $_.Name -ne "libsodium-$Tag" } |
        Select-Object -First 1
    if ($extracted) {
        Rename-Item $extracted.FullName $sodiumDir
    }

    if (-not (Test-Path (Join-Path $sodiumDir "build.zig"))) {
        throw "libsodium extraction failed — build.zig not found in $sodiumDir"
    }

    return $sodiumDir
}

if ($Clean -and (Test-Path $BuildDir)) {
    Write-Host "Cleaning .build directory..."
    Remove-Item $BuildDir -Recurse -Force
}

$zigExe = Resolve-ZigExe
$sodiumDir = Resolve-SodiumSource

$succeeded = @()
$failed = @()

foreach ($t in $Targets) {
    $rid = $t.Rid
    $zigTarget = $t.ZigTarget
    $libName = $t.LibName
    $prefix = "zig-out/$rid"
    $prefixFull = Join-Path $sodiumDir "zig-out" $rid

    Write-Host "`n[$rid] Building for $zigTarget..."

    if (Test-Path $prefixFull) { 
        Remove-Item $prefixFull -Recurse -Force 
    }

    Push-Location $sodiumDir
    try {
        & $zigExe build `
            -Doptimize=ReleaseFast `
            -Dshared=true `
            -Dstatic=false `
            -Dtest=false `
            "-Dtarget=$zigTarget" `
            "--prefix" $prefix

        if ($LASTEXITCODE -ne 0) {
            throw "zig build exited with code $LASTEXITCODE"
        }
    }
    catch {
        Write-Host "[$rid] FAILED: $_" -ForegroundColor Red
        $failed += $rid
        Pop-Location
        continue
    }

    Pop-Location

    $outputLib = Join-Path $prefixFull "lib" $libName
    if (-not (Test-Path $outputLib)) {
        $found = Get-ChildItem -Path $prefixFull -Recurse -Filter $libName -ErrorAction SilentlyContinue | Select-Object -First 1
        $outputLib = if ($found) { $found.FullName } else { $null }
    }

    if (-not $outputLib) {
        Write-Host "[$rid] FAILED: $libName not found in build output" -ForegroundColor Red
        $failed += $rid
        continue
    }

    $destDir = Join-Path $LibDir $rid
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    Copy-Item $outputLib (Join-Path $destDir $libName) -Force

    $sizeKB = [Math]::Round((Get-Item (Join-Path $destDir $libName)).Length / 1KB)
    Write-Host "[$rid] OK -> lib/$rid/$libName ($sizeKB KB)" -ForegroundColor Green
    $succeeded += $rid
}

Write-Host "`n--- Results ---"
if ($succeeded.Count -gt 0) {
    Write-Host "  Succeeded: $($succeeded -join ', ')" -ForegroundColor Green
}

if ($failed.Count -gt 0) {
    Write-Host "  Failed:    $($failed -join ', ')" -ForegroundColor Red
    exit 1
}

Write-Host "`nDone. Libraries are in lib/{rid}/."
