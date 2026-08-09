namespace WhisperTranscriber.Interactors.Directories;

public class PathSelectorInteractor
{
    public string Perform(string defaultDir = "")
    {
        var workingDir = defaultDir;
        
        if (!Directory.Exists(workingDir))
        {
            DriveSelectorInteractor driveSelector = new();
            workingDir = driveSelector.Perform();

            if (!Directory.Exists(workingDir))
                return workingDir;
        }

        DirectorySelectorInteractor directorySelector = new();
        return directorySelector.Perform(workingDir);
    }
}
