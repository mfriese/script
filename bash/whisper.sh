#!/bin/bash

# Unterverzeichnis abfragen
read -p "Bitte gib das Unterverzeichnis an: " SUBDIR

# Prüfen, ob Verzeichnis existiert
if [ ! -d "$SUBDIR" ]; then
  echo "Fehler: Verzeichnis '$SUBDIR' existiert nicht."
  exit 1
fi

# Zielordner für Transkripte
OUTDIR="$SUBDIR/transscript"
mkdir -p "$OUTDIR"

# Alle Dateien im Unterverzeichnis durchgehen
for FILE in "$SUBDIR"/*; do
  # Nur reguläre Dateien berücksichtigen
  if [ -f "$FILE" ]; then
    echo "Verarbeite: $FILE"

    # Basename ohne Pfad und ohne Suffix
    NAME_ONLY=$(basename "$FILE")
    NAME_ONLY="${NAME_ONLY%.*}"   # alles nach letztem Punkt abschneiden

	# Hier nehmen wir das Datum direkt aus dem Dateinamen
    STAMP="$NAME_ONLY"

    # Ergebnisdatei (Whisper legt standardmäßig NAME_ONLY.txt ab)
    OUTFILE="$OUTDIR/$NAME_ONLY.txt"

    # Durch Skript ermittelter Dateiname
	echo "$OUTFILE"

    # Falls die Datei schon existiert -> überspringen
    if [ -f "$OUTFILE" ]; then
      echo "Überspringe $FILE, da $OUTFILE bereits existiert."
      continue
    fi

    # Transkription mit whisper
    whisper "$FILE" --model medium --output_format txt --language German --output_dir "$OUTDIR"

    # Zeitstempel anhängen
    echo "" >> "$OUTFILE"
    echo "[Aufgenommen am $STAMP]" >> "$OUTFILE"
  fi
done

echo "Alle Dateien wurden bearbeitet. Ergebnisse liegen in: $OUTDIR"
