#pragma once

namespace heightmap {

// Application layer: lifetime, event loop and coordination only.
class Application final {
public:
    int run();
};

} // namespace heightmap
