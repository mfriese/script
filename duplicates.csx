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

var app = new CommandApp<FindDuplicatesCommand>();
app.Run(Args);

public class FindDuplicatesCommand : Command<FindDuplicatesCommand.Settings>
{
    public class Settings : CommandSettings
    {
        [CommandOption("-d|--dir")]
        public string Directory { get; set; } = string.Empty;

        [CommandOption("-a|--auto")]
        public bool Auto { get; set; } = false;
    }

    public override int Execute(CommandContext context, Settings settings)
    {
        // AnsiConsole.Clear();
        AnsiConsole.Markup("[bold yellow]Doppelte Dateien Finder[/]\n");

        if (!System.IO.Directory.Exists(settings.Directory))
        {
            AnsiConsole.Markup($"[red]Das Verzeichnis '{settings.Directory}' existiert nicht.[/]\n");
            return 1;
        }

        var duplicateFiles = FindDuplicateFiles(settings);

        if (duplicateFiles.Count == 0)
        {
            AnsiConsole.Markup($"[yellow]Keine Duplikate gefunden.[/]\n");
            return 0;
        }

        if (!ShowDuplicatesAndContinue(duplicateFiles, settings))
        {
            AnsiConsole.Markup($"[red]Abbruch gewünscht.[/]\n");
            return 0;
        }
        
        ProcessDuplicates(duplicateFiles, settings);
        return 0;
    }

    static Dictionary<string, List<string>> FindDuplicateFiles(Settings settings)
    {
        var fileHashes = new Dictionary<string, List<string>>();
        using var md5 = MD5.Create();

        var files = System.IO.Directory.GetFiles(
            settings.Directory,
            "*",
            SearchOption.AllDirectories);

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

    static bool ShowDuplicatesAndContinue(Dictionary<string, List<string>> duplicates, Settings settings)
    {
        var tree = new Tree("[yellow]Dateien[/]");

        foreach (var kvp in duplicates)
        {
            var hashCode = tree.AddNode($"[bold]{kvp.Key}[/]");

            var sortedList = kvp.Value.OrderBy(s => s.Length).ToList();

            var fileToKeep = sortedList.First();

            foreach (var fileName in kvp.Value)
            {
                if (fileToKeep == fileName)
                    hashCode.AddNode($"[green]{fileName}[/]");
                else
                    hashCode.AddNode($"[blue]{fileName}[/]");
            }
        }

        AnsiConsole.Write(tree);

        char answer = AnsiConsole.Prompt(
            new TextPrompt<char>("Möchtest du fortfahren? [green](a)uto[/] / [yellow](m)anual[/] / [red](c)ancel[/]")
                .AllowEmpty()
                .ValidationErrorMessage("[red]Bitte gib nur a, m oder c ein![/]")
                .Validate(input =>
                    input == 'a' || input == 'm' || input == 'c'
                        ? ValidationResult.Success()
                        : ValidationResult.Error("[red]Ungültige Eingabe, nur a, m oder c erlaubt![/]")
                )
        );

        if (answer == 'a')
            settings.Auto = true;
        if (answer == 'm')
            settings.Auto = false;

        return answer != 'c';
    }

    static void ProcessDuplicates(Dictionary<string, List<string>> duplicates, Settings settings)
    {
        foreach (var duplicateGroup in duplicates)
        {
            AnsiConsole.Markup("\n[bold red]Doppelte Dateien gefunden:[/]\n");
            var files = duplicateGroup.Value;

            string fileToKeep = string.Empty;

            if (settings.Auto)
            {
                var sortedList = files.OrderBy(s => s.Length).ToList();

                fileToKeep = sortedList.First();
            }
            else
            {
                var selection = new SelectionPrompt<string>()
                    .Title("[yellow]Wähle welche Datei behalten wird:[/]")
                    .PageSize(10)
                    .AddChoices(files);

                fileToKeep = AnsiConsole.Prompt(selection);
            }

            try
            {
                foreach(var file in files)
                {
                    if (file == fileToKeep)
                    {
                        AnsiConsole.Markup($"[yellow]Behalten: {file}[/]\n");

                        continue;
                    }

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
