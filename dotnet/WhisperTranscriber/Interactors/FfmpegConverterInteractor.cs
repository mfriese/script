using System.Diagnostics;

namespace WhisperTranscriber.Interactors;

public class FfmpegConverterInteractor
{
    public async Task Convert(string inputFile, string outputFile)
    {
        using var process = Process.Start(new ProcessStartInfo("ffmpeg")
        {
            ArgumentList =
            {
                "-nostdin", "-hide_banner", "-loglevel", "error", "-y", "-i", inputFile, "-ar", "16000", "-ac", "1",
                "-c:a", "pcm_s16le", outputFile
            },
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        }) ?? throw new InvalidOperationException("ffmpeg failed to launch.");

        var error = await process.StandardError.ReadToEndAsync();
        await process.WaitForExitAsync();
        if (process.ExitCode != 0)
            throw new InvalidOperationException($"ffmpeg could not convert the file: {error.Trim()}");
    }
}