#pragma once

#include <vector>

namespace heightmap {

struct TerrainVertex {
    float u;
    float v;
};

// Domain object: owns only terrain topology, never GPU resources.
class TerrainMesh final {
public:
    explicit TerrainMesh(int subdivisions);

    [[nodiscard]] const std::vector<TerrainVertex>& vertices() const noexcept { return vertices_; }

private:
    std::vector<TerrainVertex> vertices_;
};

} // namespace heightmap
