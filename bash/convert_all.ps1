#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Konvertiert alle Dateien einer Erweiterung rekursiv nach MP4.

.DESCRIPTION
    Startet convert2mp4.ps1 in parallelen Batches. Die Anzahl gleichzeitig
    laufender Konvertierungen wird mit ThrottleLimit begrenzt.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$Extension,

    [Parameter()]
    [ValidateRange(1, [int]::MaxValue)]
    [int]$ThrottleLimit = 2,

    [Parameter()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$Path = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$normalizedExtension = $Extension.Trim().TrimStart('.')
if ([string]::IsNullOrWhiteSpace($normalizedExtension)) {
    throw 'Die Erweiterung darf nicht leer sein, z. B. "mkv" oder ".mkv".'
}

$rootPath = (Resolve-Path -LiteralPath $Path).Path
$workerScript = Join-Path -Path $PSScriptRoot -ChildPath 'convert2mp4.ps1'

if (-not (Test-Path -LiteralPath $workerScript -PathType Leaf)) {
    throw "Konvertierungsskript nicht gefunden: $workerScript"
}

$files = @(Get-ChildItem -LiteralPath $rootPath -Recurse -File |
    Where-Object { $_.Name -ilike "*.$normalizedExtension" })

if ($files.Count -eq 0) {
    Write-Warning "Keine *.$normalizedExtension-Dateien unter '$rootPath' gefunden."
    return
}

Write-Host "$($files.Count) Datei(en) gefunden. Maximal $ThrottleLimit parallele Konvertierung(en)."

$failures = [System.Collections.Generic.List[string]]::new()
$jobs = [System.Collections.Generic.List[System.Management.Automation.Job]]::new()

function Complete-ConversionBatch {
    param(
        [Parameter(Mandatory)]
        [System.Collections.Generic.List[System.Management.Automation.Job]]$Batch
    )

    if ($Batch.Count -eq 0) {
        return
    }

    Write-Host "$($Batch.Count) Prozess(e) gestartet – warte ..."
    $Batch | Wait-Job | Out-Null

    foreach ($job in $Batch) {
        Receive-Job -Job $job -ErrorAction Continue

        if ($job.State -ne 'Completed') {
            $failures.Add($job.Name)
        }

        Remove-Job -Job $job -Force
    }

    $Batch.Clear()
}

foreach ($file in $files) {
    $jobs.Add((Start-Job -Name $file.FullName -ScriptBlock {
        param($WorkerPath, $InputFile)

        & $WorkerPath -InputFile $InputFile
    } -ArgumentList $workerScript, $file.FullName))

    if ($jobs.Count -ge $ThrottleLimit) {
        Complete-ConversionBatch -Batch $jobs
    }
}

Complete-ConversionBatch -Batch $jobs

if ($failures.Count -gt 0) {
    throw "$($failures.Count) Konvertierung(en) fehlgeschlagen:`n$($failures -join "`n")"
}

Write-Host 'Alle Konvertierungen erfolgreich abgeschlossen.'
