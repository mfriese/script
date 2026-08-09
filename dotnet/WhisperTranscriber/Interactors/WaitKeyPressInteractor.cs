using Spectre.Console;

namespace WhisperTranscriber.Interactors;

public class WaitKeyPressInteractor
{
    public T Perform<T>(T returnValue)
    {
        AnsiConsole.MarkupLine("Press [green]Enter[/] to continue ...");

        ConsoleKey key;
        do
        {
            key = Console.ReadKey(true).Key;
        } while (key != ConsoleKey.Enter);

        return returnValue;
    }
}
