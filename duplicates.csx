#!/usr/bin/env dotnet-script

#r "nuget: Spectre.Console, *"
#r "nuget: Spectre.Console.Cli, *"

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using Spectre.Console;
using Spectre.Console.Cli;

var args = Environment.GetCommandLineArgs().Skip(2).ToArray();
var app = new CommandApp<FindDuplicatesCommand>();
app.Run(args);

public class FindDuplicatesCommand : Command<FindDuplicatesCommand.Settings>
{
    public class Settings : CommandSettings
    {
        [CommandOption("-d|--dir")]
        public string Directory { get; set; } = string.Empty;
    }

    public override int Execute(CommandContext context, Settings settings)
    {
        AnsiConsole.Clear();
        AnsiConsole.Markup("[bold yellow]Doppelte Dateien Finder[/]\n");

        if (!System.IO.Directory.Exists(settings.Directory))
        {
            AnsiConsole.Markup("[red]Das Verzeichnis existiert nicht.[/]\n");
            return 1;
        }

        var duplicateFiles = FindDuplicateFiles(settings.Directory);
        ProcessDuplicates(duplicateFiles);
        return 0;
    }

    static Dictionary<string, List<string>> FindDuplicateFiles(string directory)
    {
        var fileHashes = new Dictionary<string, List<string>>();
        using var md5 = MD5.Create();

        var files = System.IO.Directory.GetFiles(directory, "*", SearchOption.AllDirectories);
        int totalFiles = files.Length;
        int processedFiles = 0;

        var progress = AnsiConsole.Progress()
            .AutoRefresh(true)
            .HideCompleted(false)
            .Columns(new ProgressColumn[]
            {
                new TaskDescriptionColumn(),
                new ProgressBarColumn(),
                new PercentageColumn(),
                new RemainingTimeColumn(),
                new SpinnerColumn()
            });

        progress.Start(ctx =>
        {
            var task = ctx.AddTask("[green]Untersuche Dateien...[/]", maxValue: totalFiles);

            foreach (var file in files)
            {
                AnsiConsole.Markup($"[cyan]Aktuelle Datei: {file}[/]\n");

                try
                {
                    string hash = GetFileHash(md5, file);
                    if (!fileHashes.ContainsKey(hash))
                        fileHashes[hash] = new List<string>();

                    fileHashes[hash].Add(file);
                    processedFiles++;
                    task.Value = processedFiles;
                }
                catch (Exception ex)
                {
                    AnsiConsole.Markup($"[red]Fehler beim Hashen von {file}: {ex.Message}[/]\n");
                }
            }
        });

        return fileHashes.Where(kvp => kvp.Value.Count > 1).ToDictionary(kvp => kvp.Key, kvp => kvp.Value);
    }

    static string GetFileHash(MD5 md5, string filePath)
    {
        using var stream = File.OpenRead(filePath);
        var hashBytes = md5.ComputeHash(stream);
        return BitConverter.ToString(hashBytes).Replace("-", "").ToLower();
    }

    static void ProcessDuplicates(Dictionary<string, List<string>> duplicates)
    {
        foreach (var duplicateGroup in duplicates)
        {
            AnsiConsole.Markup("\n[bold red]Doppelte Dateien gefunden:[/]\n");
            var files = duplicateGroup.Value;

            var selection = new SelectionPrompt<string>()
                .Title("[yellow]Wähle welche Datei behalten wird:[/]")
                .PageSize(10)
                .AddChoices(files);

            var fileToKeep = AnsiConsole.Prompt(selection);

            try
            {
                foreach(var file in files)
                {
                    if (file == fileToKeep)
                        continue;

                    File.Delete(file);

                    AnsiConsole.Markup($"[green]Gelöscht: {file}[/]\n");
                }
            }
            catch (Exception ex)
            {
                AnsiConsole.Markup($"[red]Fehler beim Löschen: {ex.Message}[/]\n");
            }
        }
    }
}
