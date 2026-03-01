#!/bin/bash

if [ -z "$1" ]; then
    echo "Bitte eine MKV-Datei angeben."
    echo "Beispiel: ./mkv2mp4.sh input.mkv"
    exit 1
fi

INPUT="$1"

if [ ! -f "$INPUT" ]; then
    echo "Datei nicht gefunden: $INPUT"
    exit 1
fi

BASENAME="${INPUT%.*}"
OUTPUT="${BASENAME}.mp4"

VIDEO_BITRATE="590k"
AUDIO_BITRATE="128k"

echo "Starte 2-Pass Konvertierung..."

# PASS 1
caffeinate -i -s ffmpeg -y -i "$INPUT" \
    -map 0:v:0 \
    -c:v libx264 \
    -b:v $VIDEO_BITRATE \
    -preset slow \
    -profile:v high \
    -pix_fmt yuv420p \
    -pass 1 \
    -passlogfile "$BASENAME" \
    -an \
    -f mp4 \
    /dev/null

# PASS 2
caffeinate -i -s ffmpeg -y -i "$INPUT" \
    -map 0:v:0 \
    -map 0:a? \
    -c:v libx264 \
    -b:v $VIDEO_BITRATE \
    -preset slow \
    -profile:v high \
    -pix_fmt yuv420p \
    -pass 2 \
    -passlogfile "$BASENAME" \
    -c:a aac \
    -b:a $AUDIO_BITRATE \
    -ac 2 \
    -movflags +faststart \
    "$OUTPUT"

# Cleanup
rm -f "${BASENAME}-0.log" "${BASENAME}-0.log.mbtree"

echo "Fertig: $OUTPUT"