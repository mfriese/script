#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
MAKEMKV="/Applications/MakeMKV.app/Contents/MacOS/makemkvcon"

find "$ROOT" -type d -name VIDEO_TS | while read -r vts; do
  dir="$(dirname "$vts")"
  echo "==> Verarbeite: $dir"

  "$MAKEMKV" mkv "file:$vts" all "$dir"
done
