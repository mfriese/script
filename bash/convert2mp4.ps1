#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Konvertiert eine Videodatei per FFmpeg in eine MP4-Datei.

.DESCRIPTION
    Führt eine Zwei-Pass-H.264-Konvertierung aus. Nach einem erfolgreichen
    zweiten Durchlauf werden die FFmpeg-Pass-Logs und die Quelldatei entfernt.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [Alias('Path')]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$InputFile,

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
    throw 'FFmpeg wurde nicht gefunden. Installiere FFmpeg oder füge es zum PATH hinzu.'
}

# caffeinate verhindert auf macOS, dass der Rechner während der Konvertierung einschläft.
$caffeinate = Get-Command -Name caffeinate -CommandType Application -ErrorAction SilentlyContinue
$inputPath = (Resolve-Path -LiteralPath $InputFile).Path
$passLogBase = [System.IO.Path]::ChangeExtension($inputPath, $null)
$outputPath = [System.IO.Path]::ChangeExtension($inputPath, '.mp4')
$nullDevice = if ($IsWindows) { 'NUL' } else { '/dev/null' }

function Invoke-Ffmpeg {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [Parameter(Mandatory)]
        [string]$Description
    )

    if ($null -ne $caffeinate) {
        & $caffeinate.Source -i -s $ffmpeg.Source @Arguments
    }
    else {
        & $ffmpeg.Source @Arguments
    }

    if ($LASTEXITCODE -ne 0) {
        throw "$Description fehlgeschlagen (Exit-Code $LASTEXITCODE)."
    }
}

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

Write-Host "Starte 2-Pass-Konvertierung: '$inputPath'"

Invoke-Ffmpeg -Description 'Erster Durchlauf' -Arguments @(
    $commonArguments
    '-pass', '1',
    '-an',
    '-f', 'mp4', $nullDevice
)

Invoke-Ffmpeg -Description 'Zweiter Durchlauf' -Arguments @(
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
Write-Host "Fertig: $outputPath"
