namespace WhisperTranscriber.Interactors;

public class GetAppSettingsDirInteractor
{
    public string Invoke()
    {
        var appSettingsDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "WhisperTranscriber");
        
        if (!Directory.Exists(appSettingsDir))
            Directory.CreateDirectory(appSettingsDir);
        
        return appSettingsDir;
    }
}