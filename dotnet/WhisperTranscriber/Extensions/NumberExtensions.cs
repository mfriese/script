namespace WhisperTranscriber.Extensions;

public static class NumberExtensions
{
    public static string FormatAsBytes(this long bytes)
    {
        string[] sizes = ["B", "KB", "MB", "GB"];

        double size = bytes;
        var order = 0;

        while (size >= 1024 && order < sizes.Length - 1)
        {
            order++;
            size /= 1024;
        }

        return $"{size:0.00} {sizes[order]}";
    }
}