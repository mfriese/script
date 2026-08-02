using System.ComponentModel;
using System.Diagnostics;
using Spectre.Console;
using Spectre.Console.Cli;
using Whisper.net;
using Whisper.net.Ggml;

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
        if (!await HasFfmpegAsync())
        {
            AnsiConsole.MarkupLine("[red]ffmpeg wurde nicht gefunden.[/] Bitte installieren und im PATH bereitstellen.");
            return 2;
        }

        var searchOption = settings.Recursive ? SearchOption.AllDirectories : SearchOption.TopDirectoryOnly;
        var mp3Files = System.IO.Directory.EnumerateFiles(settings.Directory, "*", searchOption)
            .Where(path => string.Equals(Path.GetExtension(path), ".mp3", StringComparison.OrdinalIgnoreCase))
            .OrderBy(path => path, StringComparer.OrdinalIgnoreCase)
            .ToList();

        if (mp3Files.Count == 0)
        {
            AnsiConsole.MarkupLine("[yellow]Keine MP3-Dateien gefunden.[/]");
            return 0;
        }

        var modelPath = await GetModel();
        
        using var factory = WhisperFactory.FromPath(modelPath);
        var completed = 0;
        var skipped = 0;
        var failed = 0;
        var count = 0;

        await AnsiConsole.Status()
            .StartAsync("Lade Whisper-Modell...", async ctx =>
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

    private static async Task<string> GetModel()
    {
        return await AnsiConsole.Status()
            .StartAsync("Lade Whisper-Modell...", async ctx =>
            {
                var downloader = new WhisperGgmlDownloader(new HttpClient());

                await using var stream = await downloader.GetGgmlModelAsync(
                    GgmlType.LargeV3Turbo,
                    QuantizationType.NoQuantization,
                    CancellationToken.None);

                var filePath = Path.Combine(Path.GetFullPath("."), "ggml-large-v3-turbo.bin");
                
                if (File.Exists(filePath))
                    return filePath;
                
                await using var file = File.Create(filePath);
                
                var buffer = new byte[1024 * 1024];
                long totalBytes = 0;

                while (true)
                {
                    var read = await stream.ReadAsync(buffer);

                    if (read == 0)
                        break;

                    await file.WriteAsync(buffer.AsMemory(0, read));

                    totalBytes += read;

                    ctx.Status($"Loading Whisper-Model ... {FormatBytes(totalBytes)}");
                }

                ctx.Status($"Done: {FormatBytes(totalBytes)}");
                
                return filePath;
            });
    }
    
    static string FormatBytes(long bytes)
    {
        string[] sizes = ["B", "KB", "MB", "GB"];

        double size = bytes;
        int order = 0;

        while (size >= 1024 && order < sizes.Length - 1)
        {
            order++;
            size /= 1024;
        }

        return $"{size:0.00} {sizes[order]}";
    }
    
    private static async Task TranscribeAsync(WhisperFactory factory, string mp3File, string outputFile, string language, Action task)
    {
        var tempWav = Path.Combine(Path.GetTempPath(), $"whisper-{Guid.NewGuid():N}.wav");
        try
        {
            await ConvertToWaveAsync(mp3File, tempWav);
            using var processor = factory.CreateBuilder().WithLanguage(language).Build();
            await using var wavStream = File.OpenRead(tempWav);
            await using var writer = new StreamWriter(outputFile, append: false);

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

    private static async Task<bool> HasFfmpegAsync()
    {
        try
        {
            using var process = Process.Start(new ProcessStartInfo("ffmpeg", "-version")
            {
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            });
            if (process is null) return false;
            await process.WaitForExitAsync();
            return process.ExitCode == 0;
        }
        catch (System.ComponentModel.Win32Exception)
        {
            return false;
        }
    }

    private static async Task ConvertToWaveAsync(string inputFile, string outputFile)
    {
        using var process = Process.Start(new ProcessStartInfo("ffmpeg")
        {
            ArgumentList = { "-nostdin", "-hide_banner", "-loglevel", "error", "-y", "-i", inputFile, "-ar", "16000", "-ac", "1", "-c:a", "pcm_s16le", outputFile },
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        }) ?? throw new InvalidOperationException("ffmpeg konnte nicht gestartet werden.");

        var error = await process.StandardError.ReadToEndAsync();
        await process.WaitForExitAsync();
        if (process.ExitCode != 0)
            throw new InvalidOperationException($"ffmpeg konnte die MP3 nicht konvertieren: {error.Trim()}");
    }
}
