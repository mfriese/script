using Spectre.Console;

namespace WhisperTranscriber.Interactors.Directories;

public class DriveSelectorInteractor
{
    private const string Cancel = "[red]Cancel[/]";

    public string Perform()
    {
        var drives = DriveInfo.GetDrives()
            .Where(d =>
            {
                try
                {
                    return d.IsReady &&
                        d.DriveType != DriveType.CDRom &&
                        Directory.Exists(d.RootDirectory.FullName);
                }
                catch
                {
                    return false;
                }
            })
            .Select(d => d.RootDirectory.FullName)
            .ToList();

        if (drives.Count == 0)
        {
            AnsiConsole.MarkupLine("[red]No drives were found![/]");

            return string.Empty;
        }

        drives.Add(Cancel);

        var selected = AnsiConsole.Prompt(
            new SelectionPrompt<string>()
                .Title($"Choose a drive or {Cancel}.")
                .PageSize(16)
                .MoreChoicesText($"[grey](Navigate with arrow keys. Pick {Cancel} from the bottom)[/]")
                .AddChoices(drives)
        );

        if (selected == Cancel)
        {
            return string.Empty;
        }

        return selected;
    }
}
