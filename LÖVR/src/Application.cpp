#include "heightmap/Application.hpp"

#include "heightmap/TerrainMesh.hpp"
#include "heightmap/TerrainRenderer.hpp"

#include <SDL3/SDL.h>

#include <cstdio>
#include <stdexcept>

namespace heightmap {

int Application::run() {
    try {
        if (!SDL_Init(SDL_INIT_VIDEO)) throw std::runtime_error(SDL_GetError());
        SDL_Window* window = SDL_CreateWindow("LÖVR Heightmap — SDL3 GPU", 1280, 720, SDL_WINDOW_RESIZABLE);
        if (!window) throw std::runtime_error(SDL_GetError());
        {
            TerrainMesh terrain(128);
            TerrainRenderer renderer(*window, terrain);
            bool running = true;
            while (running) {
                SDL_Event event;
                while (SDL_PollEvent(&event)) {
                    if (event.type == SDL_EVENT_QUIT ||
                        (event.type == SDL_EVENT_KEY_DOWN && event.key.key == SDLK_ESCAPE)) running = false;
                }
                renderer.render();
            }
        }
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 0;
    } catch (const std::exception& error) {
        std::fprintf(stderr, "%s\n", error.what());
        SDL_Quit();
        return 1;
    }
}

} // namespace heightmap
