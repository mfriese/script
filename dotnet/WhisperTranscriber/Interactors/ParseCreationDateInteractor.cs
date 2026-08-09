using System.Text.RegularExpressions;

namespace WhisperTranscriber.Interactors;

public class ParseCreationDateInteractor
{
    private const string Pattern = @"^(?:.*[\\/])?(?<date>\d{4}-\d{2}-\d{2})[-_](?<time>\d{2}-\d{2}-\d{2})\.(?:mp3|mp4|wav)$";

    public bool Invoke(string filePath, out DateTime output)
    {
        var m = Regex.Match(filePath, Pattern, RegexOptions.IgnoreCase);

        if (m.Success)
        {
            var datePart = m.Groups["date"].Value; // 2026-02-14
            var timePart = m.Groups["time"].Value; // 16-25-06

            var normalized = $"{datePart} {timePart.Replace('-', ':')}"; // 2026-02-14 16:25:06
            output = DateTime.ParseExact(normalized, "yyyy-MM-dd HH:mm:ss", null);

            return true;
        }

        output = default;
        return false;
    }
}