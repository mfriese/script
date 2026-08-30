#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Recursively converts all VIDEO_TS directories to MKV files with MakeMKV.

.DESCRIPTION
    Finds every VIDEO_TS directory below the given root directory and runs
    MakeMKV for each one. Only the corresponding VIDEO_TS directory is
    removed after a successful conversion.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$Root = (Get-Location).Path,

    [Parameter()]
    [string]$MakeMkv = '/Applications/MakeMKV.app/Contents/MacOS/makemkvcon'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $MakeMkv -PathType Leaf)) {
    throw "MakeMKV executable not found: $MakeMkv"
}

$rootPath = (Resolve-Path -LiteralPath $Root).Path
$videoTsDirectories = @(Get-ChildItem -LiteralPath $rootPath -Directory -Recurse |
    Where-Object { $_.Name -ieq 'VIDEO_TS' })

if ($videoTsDirectories.Count -eq 0) {
    Write-Warning "No VIDEO_TS directories found under '$rootPath'."
    return
}

foreach ($videoTs in $videoTsDirectories) {
    $destinationDirectory = $videoTs.Parent.FullName
    Write-Host "==> Processing: $destinationDirectory"

    & $MakeMkv mkv "file:$($videoTs.FullName)" all $destinationDirectory *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "MakeMKV failed for '$($videoTs.FullName)' (exit code $LASTEXITCODE)."
    }

    Write-Host "==> MakeMKV succeeded, deleting: $($videoTs.FullName)"
    Remove-Item -LiteralPath $videoTs.FullName -Recurse -Force
}
