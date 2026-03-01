#!/bin/bash

PLAYLIST_URL="$1"

yt-dlp --cookies-from-browser firefox -f "bv*+ba/b" --recode-video mp4 --postprocessor-args "ffmpeg:-c:v libx264 -b:v 910k -pix_fmt yuv420p -c:a aac -b:a 128k -movflags +faststart" -o "%(playlist_index)02d - %(title)s.%(ext)s" "$PLAYLIST_URL"