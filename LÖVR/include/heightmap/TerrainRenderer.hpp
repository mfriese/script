#pragma once

#include <SDL3/SDL.h>
#include <vector>

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
    void update(float deltaSeconds);

private:
    void createPipelines();
    void uploadMesh(const TerrainMesh& mesh);
    void loadHeightmap();
    void ensureDepthBuffer(Uint32 width, Uint32 height);
    [[nodiscard]] float terrainHeightAt(float worldX, float worldZ) const;

    SDL_Window* window_{};
    SDL_GPUDevice* device_{};
    SDL_GPUGraphicsPipeline* fillPipeline_{};
    SDL_GPUGraphicsPipeline* wirePipeline_{};
    SDL_GPUBuffer* vertexBuffer_{};
    SDL_GPUTexture* heightmap_{};
    SDL_GPUSampler* sampler_{};
    SDL_GPUTexture* depthBuffer_{};
    Uint32 depthWidth_{}, depthHeight_{};
    Uint32 vertexCount_{};
    float flightDistance_{0.f};
    std::vector<float> heightSamples_;
    int heightmapWidth_{}, heightmapHeight_{};
};

} // namespace heightmap
