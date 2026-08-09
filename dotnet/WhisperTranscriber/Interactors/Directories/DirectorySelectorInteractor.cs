using Spectre.Console;

namespace WhisperTranscriber.Interactors.Directories;

public class DirectorySelectorInteractor
{
    private const string Cancel = "[red]Cancel[/]";
    private const string Accept = "[green]Accept[/]";

    public string Perform(string directory)
    {
        if (!Directory.Exists(directory))
        {
            AnsiConsole.MarkupLine($"[red]Selected path '{directory}' does not exist![/]");

            return directory;
        }

        List<string> directories;

        try
        {
            directories = Directory.
                EnumerateDirectories(directory).
                Select(md => md.ToString()).Order().ToList();
        }
        catch (Exception exp)
        {
            AnsiConsole.MarkupLine($"[red]Error while reading directory![/]");
            AnsiConsole.WriteLine($"\r\n-> {exp.Message}\r\n");

            WaitKeyPressInteractor waitKeyPress = new();
            return waitKeyPress.Perform(directory);
        }

        directories.Add(Accept);
        directories.Add(Cancel);

        var selected = AnsiConsole.Prompt(
            new SelectionPrompt<string>()
                .Title($"Pick a subfolder of {directory} and {Accept} or {Cancel}.")
                .PageSize(16)
                .EnableSearch()
                .MoreChoicesText($"[grey](Navigate with arrow keys. Pick {Accept} or {Cancel} from the bottom)[/]")
                .AddChoices(directories)
        );

        if (selected == Cancel)
        {
            return string.Empty;
        }

        if (selected == Accept)
        {
            return directory;
        }

        return Perform(selected);
    }
}
