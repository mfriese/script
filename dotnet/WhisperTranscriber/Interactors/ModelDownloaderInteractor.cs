using Spectre.Console;
using Whisper.net.Ggml;
using WhisperTranscriber.Extensions;

namespace WhisperTranscriber.Interactors;

public class ModelDownloaderInteractor
{
    public async Task<string> Invoke()
        => await AnsiConsole.Status()
            .StartAsync("Loading Whisper AI model ...", async ctx =>
            {
                GetAppSettingsDirInteractor getAppSettingsDir = new();
                var appSettingsDir = getAppSettingsDir.Invoke();

                var filePath = Path.Combine(appSettingsDir, "ggml-large-v3-turbo.bin");

                if (File.Exists(filePath))
                    return filePath;

                using var httpClient = new HttpClient();
                var downloader = new WhisperGgmlDownloader(httpClient);

                await using var stream = await downloader.GetGgmlModelAsync(
                    GgmlType.LargeV3Turbo,
                    QuantizationType.NoQuantization,
                    CancellationToken.None);
                
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

                    ctx.Status($"Loading Whisper-Model ... {totalBytes.FormatAsBytes()}");
                }

                ctx.Status($"Done: {totalBytes.FormatAsBytes()}");

                return filePath;
            });
}