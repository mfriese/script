#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <endung> <verzeichnis>"
  exit 1
fi

EXT="$1"
ROOT="$2"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
WORKER="$SCRIPT_DIR/convert2mp4.sh"

if [ ! -x "$WORKER" ]; then
  echo "Worker nicht ausführbar: $WORKER"
  exit 1
fi

while IFS= read -r -d '' f; do
  echo "==> Verarbeite: $f"
  if ! "$WORKER" "$f"; then
    echo "Fehler bei: $f (überspringe, fahre fort)" >&2
  fi
done < <(find "$ROOT" -type f -iname "*.${EXT}" -print0)
