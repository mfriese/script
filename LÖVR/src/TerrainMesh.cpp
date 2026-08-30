#include "heightmap/TerrainMesh.hpp"

#include <stdexcept>

#include <wykobi.hpp>

namespace heightmap {
namespace {

using Point = wykobi::point2d<float>;
using Triangle = wykobi::triangle<float, 2>;

TerrainVertex toVertex(const Point& point) {
    return {point.x, point.y};
}

void appendTriangle(std::vector<TerrainVertex>& destination,
                    const Point& a, const Point& b, const Point& c) {
    // Wykobi is the source of truth for the domain primitive.  The GPU only
    // receives the triangle's UV vertices in its own compact representation.
    Triangle triangle;
    triangle[0] = a;
    triangle[1] = b;
    triangle[2] = c;
    (void)triangle;
    destination.push_back(toVertex(a));
    destination.push_back(toVertex(b));
    destination.push_back(toVertex(c));
}

} // namespace

TerrainMesh::TerrainMesh(int subdivisions) {
    if (subdivisions < 1) throw std::invalid_argument("subdivisions must be positive");
    vertices_.reserve(static_cast<size_t>(subdivisions) * subdivisions * 6);
    for (int y = 0; y < subdivisions; ++y) {
        for (int x = 0; x < subdivisions; ++x) {
            const float x0 = static_cast<float>(x) / subdivisions;
            const float x1 = static_cast<float>(x + 1) / subdivisions;
            const float y0 = static_cast<float>(y) / subdivisions;
            const float y1 = static_cast<float>(y + 1) / subdivisions;
            Point bottomLeft; bottomLeft.x = x0; bottomLeft.y = y0;
            Point bottomRight; bottomRight.x = x1; bottomRight.y = y0;
            Point topRight; topRight.x = x1; topRight.y = y1;
            Point topLeft; topLeft.x = x0; topLeft.y = y1;
            appendTriangle(vertices_, bottomLeft, bottomRight, topRight);
            appendTriangle(vertices_, bottomLeft, topRight, topLeft);
        }
    }
}

} // namespace heightmap
