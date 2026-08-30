#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Recursively converts all files with a given extension to MP4.

.DESCRIPTION
    Converts one file at a time using a two-pass H.264 FFmpeg conversion.
    After each successful conversion, the FFmpeg pass logs and source file
    are removed before the next file is processed.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$Extension,

    [Parameter()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$Path = (Get-Location).Path,

    [Parameter()]
    [ValidatePattern('^\d+[kKmM]?$')]
    [string]$VideoBitrate = '720k',

    [Parameter()]
    [ValidatePattern('^\d+[kKmM]?$')]
    [string]$AudioBitrate = '128k'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    $ffmpeg = Get-Command -Name ffmpeg -CommandType Application -ErrorAction Stop
}
catch {
    throw 'FFmpeg was not found. Install FFmpeg or add it to PATH.'
}

# caffeinate prevents macOS from sleeping while the conversion is running.
$caffeinate = Get-Command -Name caffeinate -CommandType Application -ErrorAction SilentlyContinue
$normalizedExtension = $Extension.Trim().TrimStart('.')
if ([string]::IsNullOrWhiteSpace($normalizedExtension)) {
    throw 'The extension cannot be empty, for example "mkv" or ".mkv".'
}
if ($normalizedExtension -ieq 'mp4') {
    throw 'The input extension cannot be "mp4", because it would overwrite the source file.'
}

$rootPath = (Resolve-Path -LiteralPath $Path).Path
$files = @(Get-ChildItem -LiteralPath $rootPath -Recurse -File |
    Where-Object { $_.Extension -ieq ".$normalizedExtension" })

if ($files.Count -eq 0) {
    Write-Warning "No *.$normalizedExtension files found under '$rootPath'."
    return
}

function Invoke-Ffmpeg {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [Parameter(Mandatory)]
        [string]$Description
    )

    if ($null -ne $caffeinate) {
        & $caffeinate.Source -i -s $ffmpeg.Source @Arguments *> $null
    }
    else {
        & $ffmpeg.Source @Arguments *> $null
    }

    if ($LASTEXITCODE -ne 0) {
        throw "$Description failed (exit code $LASTEXITCODE)."
    }
}

function Convert-ToMp4 {
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$InputFile
    )

    $inputPath = $InputFile.FullName
    $passLogBase = [System.IO.Path]::ChangeExtension($inputPath, $null)
    $outputPath = [System.IO.Path]::ChangeExtension($inputPath, '.mp4')
    $nullDevice = if ($IsWindows) { 'NUL' } else { '/dev/null' }
    $commonArguments = @(
        '-y', '-i', $inputPath,
        '-map', '0:v:0',
        '-c:v', 'libx264',
        '-b:v', $VideoBitrate,
        '-preset', 'slow',
        '-profile:v', 'high',
        '-pix_fmt', 'yuv420p',
        '-passlogfile', $passLogBase
    )

    Write-Host "==> Converting: '$inputPath'"

    Invoke-Ffmpeg -Description 'First pass' -Arguments @(
        $commonArguments
        '-pass', '1',
        '-an',
        '-f', 'mp4', $nullDevice
    )

    Invoke-Ffmpeg -Description 'Second pass' -Arguments @(
        $commonArguments
        '-pass', '2',
        '-map', '0:a?',
        '-c:a', 'aac',
        '-b:a', $AudioBitrate,
        '-ac', '2',
        '-movflags', '+faststart',
        $outputPath
    )

    foreach ($passLog in @("$passLogBase-0.log", "$passLogBase-0.log.mbtree")) {
        Remove-Item -LiteralPath $passLog -Force -ErrorAction SilentlyContinue
    }

    Remove-Item -LiteralPath $inputPath -Force
    Write-Host "==> Done: '$outputPath'"
}

Write-Host "Found $($files.Count) file(s). Processing one file at a time."
foreach ($file in $files) {
    Convert-ToMp4 -InputFile $file
}

Write-Host 'All conversions completed successfully.'
