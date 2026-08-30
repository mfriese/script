#pragma once

#include <SDL3/SDL.h>

#include "heightmap/TerrainMesh.hpp"

namespace heightmap {

// Infrastructure object: translates domain geometry into SDL_GPU resources.
class TerrainRenderer final {
public:
    TerrainRenderer(SDL_Window& window, const TerrainMesh& mesh);
    ~TerrainRenderer();

    TerrainRenderer(const TerrainRenderer&) = delete;
    TerrainRenderer& operator=(const TerrainRenderer&) = delete;

    void render();

private:
    void createPipelines();
    void uploadMesh(const TerrainMesh& mesh);
    void loadHeightmap();

    SDL_Window* window_{};
    SDL_GPUDevice* device_{};
    SDL_GPUGraphicsPipeline* fillPipeline_{};
    SDL_GPUGraphicsPipeline* wirePipeline_{};
    SDL_GPUBuffer* vertexBuffer_{};
    SDL_GPUTexture* heightmap_{};
    SDL_GPUSampler* sampler_{};
    Uint32 vertexCount_{};
};

} // namespace heightmap
