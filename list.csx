#!/usr/bin/env dotnet-script

#r "nuget: Spectre.Console, *"

using System;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using Spectre.Console;

var args = Environment.GetCommandLineArgs().Skip(2).ToArray();
if (args.Length == 0)
{
    AnsiConsole.Markup("[red]Fehler: Bitte ein Verzeichnis angeben![/]\n");
    return;
}

string directory = args[0];
if (!Directory.Exists(directory))
{
    AnsiConsole.Markup("[red]Fehler: Verzeichnis existiert nicht![/]\n");
    return;
}

var files = Directory.GetFiles(directory, "*", SearchOption.AllDirectories);
int totalFiles = files.Length;
int processedFiles = 0;

AnsiConsole.Clear();
AnsiConsole.Markup("[bold yellow]Datei-Scan Fortschritt[/]\n\n");

AnsiConsole.Progress()
    .AutoRefresh(true)
    .HideCompleted(false)
    .Columns(new ProgressColumn[]
    {
        new TaskDescriptionColumn(),
        new ProgressBarColumn(),
        new PercentageColumn(),
        new RemainingTimeColumn(),
        new SpinnerColumn()
    })
    .Start(progressCtx =>
    {
        var task = progressCtx.AddTask("[green]Untersuche Dateien...[/]", maxValue: totalFiles);

        foreach (var file in files)
        {
            AnsiConsole.Markup($"\r[cyan]Aktuelle Datei: {file}[/]   ");
            
            // Simuliere Verarbeitung
            System.Threading.Thread.Sleep(1000);
            
            processedFiles++;
            task.Value = processedFiles; // Fortschrittsbalken aktualisieren
        }
    });

AnsiConsole.Markup("\n[green]✅ Alle Dateien verarbeitet![/]\n");
