#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <endung>"
  exit 1
fi

EXT="*.$1"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
WORKER="$SCRIPT_DIR/convert2mp4.sh"

find . -type f -iname "$EXT" -print0 | while IFS= read -r -d '' f; do
  "$WORKER" "$f"
done
