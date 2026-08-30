cmake_minimum_required(VERSION 3.22)
project(heightmap_sdl3 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(SDL3 3.2 CONFIG REQUIRED)
find_package(SDL3_image CONFIG REQUIRED)

# Wykobi is header-only.  Keeping it as an explicit target prevents geometry
# code from depending on a global include path.
include(FetchContent)
FetchContent_Declare(wykobi
  GIT_REPOSITORY https://github.com/ArashPartow/wykobi.git
  GIT_TAG 37d0cd3cd6e3e3d18115c23c994e827a75052248
  GIT_SHALLOW TRUE)
set(FETCHCONTENT_UPDATES_DISCONNECTED_wykobi ON)
FetchContent_MakeAvailable(wykobi)
add_library(wykobi_headers INTERFACE)
target_include_directories(wykobi_headers INTERFACE "${wykobi_SOURCE_DIR}")

add_executable(heightmap_sdl3
  src/main.cpp
  src/Application.cpp
  src/TerrainMesh.cpp
  src/TerrainRenderer.cpp)
target_include_directories(heightmap_sdl3 PRIVATE include)
target_link_libraries(heightmap_sdl3 PRIVATE SDL3::SDL3 SDL3_image::SDL3_image wykobi_headers)

add_custom_target(runtime_assets ALL
  COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_FILE_DIR:heightmap_sdl3>/assets"
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
          "${CMAKE_CURRENT_SOURCE_DIR}/assets/canyon_heightmap.png"
          "$<TARGET_FILE_DIR:heightmap_sdl3>/assets/canyon_heightmap.png"
  COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_FILE_DIR:heightmap_sdl3>/assets/shaders"
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
          "${CMAKE_CURRENT_SOURCE_DIR}/assets/shaders/terrain.vert.msl"
          "$<TARGET_FILE_DIR:heightmap_sdl3>/assets/shaders/terrain.vert.msl"
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
          "${CMAKE_CURRENT_SOURCE_DIR}/assets/shaders/terrain.frag.msl"
          "$<TARGET_FILE_DIR:heightmap_sdl3>/assets/shaders/terrain.frag.msl")
add_dependencies(heightmap_sdl3 runtime_assets)
