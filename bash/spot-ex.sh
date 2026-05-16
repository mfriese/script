#!/bin/bash

FILE="$1"

yt-dlp -a "$FILE" \
  -x --audio-format mp3 --audio-quality 0 \
  --default-search "ytsearch1" \
  --embed-metadata \
  --embed-thumbnail \
  --add-metadata \
  -o "%(artist)s - %(title)s.%(ext)s"