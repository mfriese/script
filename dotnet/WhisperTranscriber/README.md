# WhisperTranscriber

Kommandozeilenprogramm zum lokalen Transkribieren aller MP3-Dateien eines Verzeichnisses. Für jede `aufnahme.mp3` wird die nebenliegende Datei `aufnahme.txt` erzeugt.

## Voraussetzungen

- .NET SDK 9.0 oder neuer
- `ffmpeg` im `PATH` (wandelt MP3 vor der Verarbeitung in 16-kHz-Mono-WAV um)
- Eine lokale Whisper-GGML-Modelldatei, etwa `ggml-medium.bin`

Auf Apple Silicon verwendet das Projekt die CoreML-Laufzeit von Whisper.net.

## Start

```bash
dotnet run --project dotnet/WhisperTranscriber -- \
  "/Pfad/zu/aufnahmen" \
  --model-path "/Pfad/zu/ggml-medium.bin" \
  --language de
```

Optionen:

- `--recursive` durchsucht Unterverzeichnisse.
- `--overwrite` ersetzt schon vorhandene `.txt`-Dateien. Ohne diese Option werden sie übersprungen.
- `--language auto` aktiviert automatische Spracherkennung.

Die vollständige Hilfe ist über `dotnet run --project dotnet/WhisperTranscriber -- --help` verfügbar.
