#!/usr/bin/env bash

if [ $# -lt 1 ]; then
  echo "Usage: $0 <endung>"
  exit 1
fi

EXT="*.$1"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
WORKER="$SCRIPT_DIR/convert2mp4.sh"

count=0
max=2

find . -type f -iname "$EXT" -print0 | while IFS= read -r -d '' f; do
  "$WORKER" "$f" &
  
  ((count++))

  if [ "$count" -ge "$max" ]; then
    echo "$max Prozesse gestartet – warte..."
    
    wait    # wartet auf alle gestarteten Hintergrundjobs

    count=0 # Zähler zurücksetzen
  fi
done

wait  # Restliche Prozesse am Ende abwarten