# Heightmap in SDL3 GPU

Eine C++-Umsetzung von `main.lua` mit der 3D-GPU-API von SDL3. Sie zeichnet dieselbe
Heightmap-Ebene zweimal: zuerst gefüllt, anschließend als weißes Wireframe. Die
Höhe stammt aus dem Alpha-Kanal von `heightmap.png`; der Fog folgt derselben
`atan(length(...) * .1)`-Formel wie im LÖVR-Shader.

## Architektur

```
Application (Lebenszyklus, Events)
        |
        +-- TerrainMesh (Domain: Wykobi-Punkte und -Dreiecke)
        |
        +-- TerrainRenderer (Infrastructure: SDL_GPU, Shader, Textur, Pipelines)
```

`TerrainMesh` enthält keine SDL-Typen und lässt sich unabhängig vom Renderer
testen oder durch andere Geometriequellen ersetzen. `TerrainRenderer` besitzt
seine GPU-Ressourcen per RAII und akzeptiert das Mesh nur als Eingabe. Die
header-only Bibliothek Wykobi wird beim Konfigurieren über CMake FetchContent
bezogen und ausschließlich vom Geometrie-Layer verwendet.

## Voraussetzungen

- macOS mit Xcode Command Line Tools (`xcode-select --install`)
- Homebrew, CMake 3.22+ und ein C++20-Compiler
- SDL3 und SDL3_image

Dieses Projekt ist bewusst auf macOS und Metal beschränkt. Die Shader liegen
direkt als Metal Shading Language (`.msl`) vor; ein externer Shader-Compiler
wie `shadercross` wird nicht benötigt.

## Einrichtung unter macOS mit Homebrew

Zuerst SDL3, SDL3_image, CMake und Git installieren:

```sh
brew install cmake git sdl3 sdl3_image
```

### Spiel konfigurieren, bauen und starten

Weiterhin im Verzeichnis `LÖVR`:

```sh
rm -rf build

cmake -S . -B build \
  -DCMAKE_PREFIX_PATH="$(brew --prefix)"

cmake --build build
./build/heightmap_sdl3
```

Zum Beenden `Esc` drücken oder das Fenster schließen.

### Häufige Fehler

| Meldung | Lösung |
| --- | --- |
| `Could not find ... SDL3Config.cmake` | `brew install sdl3 sdl3_image` ausführen und CMake mit `-DCMAKE_PREFIX_PATH="$(brew --prefix)"` erneut aufrufen. |
| CMake verwendet alte Pfade | `rm -rf build` ausführen und die Konfiguration erneut starten. |
