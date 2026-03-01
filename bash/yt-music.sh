#!/bin/bash

PLAYLIST_URL="$1"

yt-dlp \
    -f "bestaudio" \
    --extract-audio \
    --audio-format mp3 \
    --audio-quality 192K \
    --embed-thumbnail \
    --add-metadata \
    --cookies-from-browser firefox \
    --metadata-from-title "%(artist)s - %(title)s" \
    -o "%(playlist_index)02d - %(title)s.%(ext)s" \
    "$PLAYLIST_URL"