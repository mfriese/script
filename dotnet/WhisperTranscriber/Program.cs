using System.ComponentModel;
using System.Diagnostics;
using System.Text.RegularExpressions;
using Spectre.Console;
using Spectre.Console.Cli;
using Whisper.net;
using Whisper.net.Ggml;
using WhisperTranscriber.Extensions;
using WhisperTranscriber.Interactors;

var app = new CommandApp<TranscribeCommand>();
app.Configure(config =>
{
    config.SetApplicationName("whisper-transcribe");
    config.SetApplicationVersion("1.0.0");
    config.ValidateExamples();
    config.AddExample("/Volumes/Audio");
    config.AddExample("./aufnahmen", "--recursive", "--overwrite");
});

return await app.RunAsync(args);

sealed class TranscribeSettings : CommandSettings
{
    [CommandArgument(0, "<directory>")]
    [Description("Verzeichnis mit MP3-Dateien.")]
    public string Directory { get; init; } = string.Empty;

    [CommandOption("-l|--language <LANGUAGE>")]
    [DefaultValue("de")]
    [Description("Sprache als ISO-639-1-Code oder 'auto'.")]
    public string Language { get; init; } = "de";

    [CommandOption("-r|--recursive")]
    [Description("Durchsucht Unterverzeichnisse ebenfalls.")]
    public bool Recursive { get; init; }

    [CommandOption("-o|--overwrite")]
    [Description("Überschreibt bereits vorhandene TXT-Dateien.")]
    public bool Overwrite { get; init; }

    public override ValidationResult Validate()
    {
        if (string.IsNullOrWhiteSpace(Directory) || !System.IO.Directory.Exists(Directory))
            return ValidationResult.Error($"Das Verzeichnis '{Directory}' existiert nicht.");

        return ValidationResult.Success();
    }
}

sealed class TranscribeCommand : AsyncCommand<TranscribeSettings>
{
    protected override async Task<int> ExecuteAsync(CommandContext context, TranscribeSettings settings, CancellationToken cancellationToken)
    {
        AnsiConsole.Write(new FigletText("Whisper Trans").LeftJustified().Color(Color.Yellow));
        AnsiConsole.Write(new Rule("[bold]Now setting up [/]").Justify(Justify.Left));
        
        AnsiConsole.Markup("[yellow]Check ffmpeg[/] ... ");
        FfmpegExistsInteractor ffmpegExists = new();
        if (!await ffmpegExists.Invoke())
        {
            AnsiConsole.MarkupLine("[red]failed![/] Please install ffmpeg to proceed.");
            return 2;
        }
        AnsiConsole.MarkupLine("[green]success![/]");

        AnsiConsole.Markup("[yellow]Finding input[/] ... ");
        var searchOption = settings.Recursive ? SearchOption.AllDirectories : SearchOption.TopDirectoryOnly;
        var mp3Files = System.IO.Directory.EnumerateFiles(settings.Directory, "*", searchOption)
            .Where(path => Regex.IsMatch(Path.GetExtension(path), @"\.mp[34]"))
            .OrderBy(path => path, StringComparer.OrdinalIgnoreCase)
            .ToList();

        if (mp3Files.Count == 0)
        {
            AnsiConsole.MarkupLine("[red]failed![/] No files to process.");
            return 0;
        }
        AnsiConsole.MarkupLine($"[green]success![/] {mp3Files.Count} files found.");

        ModelDownloaderInteractor modelDownloader = new();
        var modelPath = await modelDownloader.Invoke();
        
        AnsiConsole.MarkupLine($"Using {Markup.Escape(modelPath)}");
        using var factory = WhisperFactory.FromPath(modelPath);
        var completed = 0;
        var skipped = 0;
        var failed = 0;
        var count = 0;

        await AnsiConsole.Status()
            .StartAsync("Transcribing ...", async ctx =>
            {
                foreach (var mp3File in mp3Files)
                {
                    var lines = 0;
                    count++;
                    var outputFile = Path.ChangeExtension(mp3File, ".txt");
                    Action task = () => ctx.Status($"[green]Progress[/]: File {count} of {mp3Files.Count}: [yellow]{Markup.Escape(Path.GetFileName(mp3File))}[/] found {++lines} lines ..."); 

                    if (File.Exists(outputFile) && !settings.Overwrite)
                    {
                        skipped++;
                        continue;
                    }

                    try
                    {
                        await TranscribeAsync(factory, mp3File, outputFile, settings.Language, task);
                        completed++;
                    }
                    catch (Exception exception)
                    {
                        failed++;
                        AnsiConsole.MarkupLine($"[red]Fehler bei {Markup.Escape(mp3File)}:[/] {Markup.Escape(exception.Message)}");
                    }
                }
            });

        AnsiConsole.MarkupLine($"[green]Fertig:[/] {completed} transkribiert, {skipped} übersprungen, {failed} fehlgeschlagen.");
        return failed == 0 ? 0 : 1;
    }
  
    private static async Task TranscribeAsync(WhisperFactory factory, string mp3File, string outputFile, string language, Action task)
    {
        var tempWav = Path.Combine(Path.GetTempPath(), $"whisper-{Guid.NewGuid():N}.wav");
        try
        {
            FfmpegConverterInteractor ffmpegConverterInteractor = new();
            await ffmpegConverterInteractor.Convert(mp3File, tempWav);
            await using var processor = factory.CreateBuilder().WithLanguage(language).Build();
            await using var wavStream = File.OpenRead(tempWav);
            await using var writer = new StreamWriter(outputFile, append: false);

            var creationTime = File.GetCreationTime(mp3File).ToString("yyyy-MM-dd HH:mm:ss");
            await writer.WriteAsync($"File created on {creationTime}\r\n\r\n");
            
            await foreach (var segment in processor.ProcessAsync(wavStream))
            {
                await writer.WriteAsync(segment.Text);
                task.Invoke();
            }
        }
        finally
        {
            if (File.Exists(tempWav))
                File.Delete(tempWav);
        }
    }
}
