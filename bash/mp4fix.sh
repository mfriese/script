#!/bin/bash

clear
shopt -s nullglob  

mp4_files=(*.*)

if [ ${#mp4_files[@]} -eq 0 ]; then
    echo "Keine MP4-Dateien im aktuellen Ordner gefunden!"
    exit 1
fi

for f in "${mp4_files[@]}"; do
    # Video- und Audio-Codec prüfen
    video_codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$f")
    audio_codec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$f")
    
    # Container prüfen (codec_tag_string zeigt z. B. 'mp4a' oder 'adts')
    audio_container=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_tag_string -of default=nw=1:nk=1 "$f")

    # Zeilenumbrüche entfernen
    video_codec="${video_codec%%$'\n'*}"
    audio_codec="${audio_codec%%$'\n'*}"
    audio_container="${audio_container%%$'\n'*}"

    echo "Datei: $f"
    echo "Video-Codec: $video_codec, Audio-Codec: $audio_codec, Audio-Container: $audio_container"

    out="${f%}.fix.mp4"
    vcodec="copy"
    acodec="copy"
    remux=false

    # Video neu kodieren falls nötig
    if [ "$video_codec" != "h264" ]; then
        vcodec="libx264"
        echo "Video wird neu kodiert..."
    fi

    # Audio neu kodieren falls nötig
    if [ "$audio_codec" != "aac" ]; then
        acodec="aac"
        echo "Audio wird neu kodiert..."
    fi

    # Remuxen falls Container nicht Standard AAC
    # MP4 Standard: 'mp4a'
    if [ "$audio_codec" = "aac" ] && [ "$audio_container" != "mp4a" ]; then
        remux=true
        echo "Audio-Container wird remuxt von $audio_container → mp4a ..."
    fi

    if [ "$vcodec" = "copy" ] && [ "$acodec" = "copy" ] && [ "$remux" = false ]; then
        echo "Datei bereits korrekt, kein Re-Encoding oder Remux nötig."
    else
        ffmpeg_args=("-i" "$f" "-movflags" "+faststart")

        # Video
        ffmpeg_args+=("-c:v" "$vcodec")

        # Audio
        ffmpeg_args+=("-c:a" "$acodec" "-b:a" "128k")

        # Falls nur remux nötig ist, copy verwenden
        if [ "$remux" = true ] && [ "$acodec" = "copy" ]; then
            # Kein Re-Encoding, nur Remux
            ffmpeg_args=("-i" "$f" "-c" "copy" "-movflags" "+faststart")
        fi

        ffmpeg_args+=("$out")

        echo "Konvertiere/Remuxe $f → $out ..."
        ffmpeg "${ffmpeg_args[@]}"
        
        rm "$f"
    fi

    echo "-----------------------------"
done