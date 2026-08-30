#include "heightmap/TerrainRenderer.hpp"

#include <SDL3_image/SDL_image.h>

#include <cmath>
#include <cstring>
#include <filesystem>
#include <stdexcept>
#include <string>

namespace heightmap {
namespace {

struct Vec3 { float x, y, z; };
struct Mat4 { float m[16]; };
struct Material { float terrain[4]; float fog[4]; };
struct GpuVertex { float x, y, z; };

[[noreturn]] void fail(const char* what) { throw std::runtime_error(std::string(what) + ": " + SDL_GetError()); }
std::filesystem::path assetPath(const char* path) { return std::filesystem::path(SDL_GetBasePath()) / path; }
Vec3 sub(Vec3 a, Vec3 b) { return {a.x-b.x,a.y-b.y,a.z-b.z}; }
float dot(Vec3 a, Vec3 b) { return a.x*b.x+a.y*b.y+a.z*b.z; }
Vec3 cross(Vec3 a, Vec3 b) { return {a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x}; }
Vec3 norm(Vec3 a) { float l=std::sqrt(dot(a,a)); return {a.x/l,a.y/l,a.z/l}; }
Mat4 mul(const Mat4& a, const Mat4& b) { Mat4 r{}; for(int c=0;c<4;++c) for(int row=0;row<4;++row) for(int k=0;k<4;++k) r.m[c*4+row]+=a.m[k*4+row]*b.m[c*4+k]; return r; }
Mat4 camera(Vec3 eye, Vec3 target, float aspect) {
    const Vec3 forward=norm(sub(target,eye)), right=norm(cross({0,1,0},forward)), up=cross(forward,right);
    Mat4 view{{right.x,up.x,forward.x,0,right.y,up.y,forward.y,0,right.z,up.z,forward.z,0,-dot(right,eye),-dot(up,eye),-dot(forward,eye),1}};
    float ys=1.f/std::tan(.5f), xs=ys/aspect;
    Mat4 projection{{xs,0,0,0,0,ys,0,0,0,0,300.f/299.9f,1,0,0,-30.f/299.9f,0}};
    // Metal multiplies matrices with column vectors: clip = projection * view * world.
    return mul(projection,view);
}

SDL_GPUShader* shader(SDL_GPUDevice* device, const char* name, const char* entrypoint, SDL_GPUShaderStage stage, Uint32 samplers, Uint32 uniforms) {
    const auto path=assetPath((std::string("assets/shaders/")+name+".msl").c_str()); size_t size{};
    void* code=SDL_LoadFile(path.string().c_str(),&size); if(!code) fail("Shader laden");
    SDL_GPUShaderCreateInfo info{}; info.code=static_cast<Uint8*>(code); info.code_size=size; info.entrypoint=entrypoint; info.format=SDL_GPU_SHADERFORMAT_MSL; info.stage=stage; info.num_samplers=samplers; info.num_uniform_buffers=uniforms;
    SDL_GPUShader* result=SDL_CreateGPUShader(device,&info); SDL_free(code); if(!result) fail("SDL_CreateGPUShader"); return result;
}

void upload(SDL_GPUDevice* d, SDL_GPUBuffer* dst, const void* data, Uint32 bytes) {
    SDL_GPUTransferBufferCreateInfo i{}; i.usage=SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD; i.size=bytes;
    SDL_GPUTransferBuffer* t=SDL_CreateGPUTransferBuffer(d,&i); if(!t) fail("Transferbuffer");
    void* p=SDL_MapGPUTransferBuffer(d,t,false); if(!p) fail("Transferbuffer mappen"); std::memcpy(p,data,bytes); SDL_UnmapGPUTransferBuffer(d,t);
    SDL_GPUCommandBuffer* c=SDL_AcquireGPUCommandBuffer(d); SDL_GPUCopyPass* pass=SDL_BeginGPUCopyPass(c);
    SDL_GPUTransferBufferLocation from{t,0}; SDL_GPUBufferRegion to{dst,0,bytes}; SDL_UploadToGPUBuffer(pass,&from,&to,false); SDL_EndGPUCopyPass(pass);
    if(!SDL_SubmitGPUCommandBuffer(c)) fail("Geometrie hochladen"); SDL_ReleaseGPUTransferBuffer(d,t);
}

} // namespace

TerrainRenderer::TerrainRenderer(SDL_Window& window, const TerrainMesh& mesh) : window_(&window), vertexCount_(static_cast<Uint32>(mesh.vertices().size())) {
    device_=SDL_CreateGPUDevice(SDL_GPU_SHADERFORMAT_MSL,true,"metal"); if(!device_) fail("SDL_CreateGPUDevice");
    if(!SDL_ClaimWindowForGPUDevice(device_,window_)) fail("GPU-Fenster zuweisen");
    loadHeightmap(); createPipelines(); uploadMesh(mesh);
    SDL_GPUSamplerCreateInfo info{}; info.min_filter=SDL_GPU_FILTER_LINEAR; info.mag_filter=SDL_GPU_FILTER_LINEAR; info.address_mode_u=SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE; info.address_mode_v=SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE;
    sampler_=SDL_CreateGPUSampler(device_,&info); if(!sampler_) fail("SDL_CreateGPUSampler");
}

TerrainRenderer::~TerrainRenderer() {
    SDL_ReleaseGPUSampler(device_,sampler_); SDL_ReleaseGPUTexture(device_,heightmap_); SDL_ReleaseGPUTexture(device_,depthBuffer_); SDL_ReleaseGPUBuffer(device_,vertexBuffer_);
    SDL_ReleaseGPUGraphicsPipeline(device_,wirePipeline_); SDL_ReleaseGPUGraphicsPipeline(device_,fillPipeline_);
    if(device_) { SDL_ReleaseWindowFromGPUDevice(device_,window_); SDL_DestroyGPUDevice(device_); }
}

void TerrainRenderer::createPipelines() {
    SDL_GPUShader* vs=shader(device_,"terrain.vert","terrain_vertex",SDL_GPU_SHADERSTAGE_VERTEX,0,1); SDL_GPUShader* fs=shader(device_,"terrain.frag","terrain_fragment",SDL_GPU_SHADERSTAGE_FRAGMENT,0,1);
    SDL_GPUVertexBufferDescription buffer{0,sizeof(GpuVertex),SDL_GPU_VERTEXINPUTRATE_VERTEX,0}; SDL_GPUVertexAttribute attribute{0,0,SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3,0};
    SDL_GPUColorTargetDescription target{SDL_GetGPUSwapchainTextureFormat(device_,window_),{}};
    SDL_GPUGraphicsPipelineCreateInfo info{}; info.vertex_shader=vs; info.fragment_shader=fs; info.vertex_input_state={&buffer,1,&attribute,1}; info.primitive_type=SDL_GPU_PRIMITIVETYPE_TRIANGLELIST; info.rasterizer_state.cull_mode=SDL_GPU_CULLMODE_NONE; info.depth_stencil_state.compare_op=SDL_GPU_COMPAREOP_LESS_OR_EQUAL; info.depth_stencil_state.enable_depth_test=true; info.depth_stencil_state.enable_depth_write=true; info.target_info={&target,1,SDL_GPU_TEXTUREFORMAT_D32_FLOAT,true};
    fillPipeline_=SDL_CreateGPUGraphicsPipeline(device_,&info); info.rasterizer_state.fill_mode=SDL_GPU_FILLMODE_LINE; wirePipeline_=SDL_CreateGPUGraphicsPipeline(device_,&info);
    SDL_ReleaseGPUShader(device_,vs); SDL_ReleaseGPUShader(device_,fs); if(!fillPipeline_||!wirePipeline_) fail("Terrain-Pipeline");
}

void TerrainRenderer::uploadMesh(const TerrainMesh& mesh) {
    std::vector<GpuVertex> vertices;
    vertices.reserve(mesh.vertices().size());
    for (const TerrainVertex& vertex : mesh.vertices()) {
        const float x = (vertex.u - .5f) * 52.f;
        const float z = -vertex.v * 168.f;
        vertices.push_back({x, terrainHeightAt(x, z), z});
    }
    SDL_GPUBufferCreateInfo info{SDL_GPU_BUFFERUSAGE_VERTEX,static_cast<Uint32>(vertices.size()*sizeof(GpuVertex))}; vertexBuffer_=SDL_CreateGPUBuffer(device_,&info); if(!vertexBuffer_) fail("Terrain-Buffer"); upload(device_,vertexBuffer_,vertices.data(),info.size);
}

void TerrainRenderer::loadHeightmap() {
    SDL_Surface* input=IMG_Load(assetPath("assets/heightmap.png").string().c_str()); if(!input) fail("Heightmap laden");
    SDL_Surface* image=SDL_ConvertSurface(input,SDL_PIXELFORMAT_RGBA32); SDL_DestroySurface(input); if(!image) fail("Heightmap konvertieren");
    heightmapWidth_ = image->w;
    heightmapHeight_ = image->h;
    heightSamples_.resize(static_cast<size_t>(heightmapWidth_) * heightmapHeight_);
    for (int y = 0; y < heightmapHeight_; ++y) {
        const auto* row = static_cast<const Uint8*>(image->pixels) + y * image->pitch;
        for (int x = 0; x < heightmapWidth_; ++x) heightSamples_[y * heightmapWidth_ + x] = row[x * 4 + 3] / 255.f * 18.f;
    }
    SDL_GPUTextureCreateInfo info{}; info.type=SDL_GPU_TEXTURETYPE_2D; info.format=SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM; info.usage=SDL_GPU_TEXTUREUSAGE_SAMPLER; info.width=image->w; info.height=image->h; info.layer_count_or_depth=1; info.num_levels=1; info.sample_count=SDL_GPU_SAMPLECOUNT_1;
    heightmap_=SDL_CreateGPUTexture(device_,&info); if(!heightmap_) fail("Heightmap-Textur"); const Uint32 bytes=image->pitch*image->h;
    SDL_GPUTransferBufferCreateInfo uploadInfo{SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,bytes}; SDL_GPUTransferBuffer* transfer=SDL_CreateGPUTransferBuffer(device_,&uploadInfo); void* p=SDL_MapGPUTransferBuffer(device_,transfer,false); std::memcpy(p,image->pixels,bytes); SDL_UnmapGPUTransferBuffer(device_,transfer);
    SDL_GPUCommandBuffer* c=SDL_AcquireGPUCommandBuffer(device_); SDL_GPUCopyPass* pass=SDL_BeginGPUCopyPass(c); SDL_GPUTextureTransferInfo from{transfer,0,static_cast<Uint32>(image->pitch/4),static_cast<Uint32>(image->h)}; SDL_GPUTextureRegion to{heightmap_,0,0,0,0,info.width,info.height,1}; SDL_UploadToGPUTexture(pass,&from,&to,false); SDL_EndGPUCopyPass(pass); SDL_DestroySurface(image); if(!SDL_SubmitGPUCommandBuffer(c)) fail("Heightmap hochladen"); SDL_ReleaseGPUTransferBuffer(device_,transfer);
}

float TerrainRenderer::terrainHeightAt(float worldX, float worldZ) const {
    // Gleiche 100×100-m-Abbildung wie im Vertex-Shader; bilineare Abtastung.
    const float u = std::clamp(worldX / 52.f + .5f, 0.f, 1.f);
    const float v = std::clamp(-worldZ / 168.f, 0.f, 1.f);
    const int x = std::clamp(static_cast<int>(u * (heightmapWidth_ - 1)), 0, heightmapWidth_ - 1);
    const int z = std::clamp(static_cast<int>(v * (heightmapHeight_ - 1)), 0, heightmapHeight_ - 1);
    return heightSamples_[z * heightmapWidth_ + x];
}

void TerrainRenderer::ensureDepthBuffer(Uint32 width, Uint32 height) {
    if (depthBuffer_ && width == depthWidth_ && height == depthHeight_) return;
    SDL_ReleaseGPUTexture(device_, depthBuffer_);
    SDL_GPUTextureCreateInfo info{}; info.type=SDL_GPU_TEXTURETYPE_2D; info.format=SDL_GPU_TEXTUREFORMAT_D32_FLOAT; info.usage=SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET; info.width=width; info.height=height; info.layer_count_or_depth=1; info.num_levels=1; info.sample_count=SDL_GPU_SAMPLECOUNT_1;
    depthBuffer_=SDL_CreateGPUTexture(device_, &info); if (!depthBuffer_) fail("Depth-Buffer"); depthWidth_=width; depthHeight_=height;
}

void TerrainRenderer::update(float deltaSeconds) {
    // Langsamer, gleichmäßiger Vorwärtsflug ausschließlich entlang der Z-Achse.
    flightDistance_ += 4.f * deltaSeconds;
    if (flightDistance_ > 145.f) flightDistance_ -= 145.f;
}

void TerrainRenderer::render() {
    SDL_GPUCommandBuffer* commands=SDL_AcquireGPUCommandBuffer(device_); SDL_GPUTexture* backbuffer=nullptr; Uint32 width{},height{};
    if(!SDL_WaitAndAcquireGPUSwapchainTexture(commands,window_,&backbuffer,&width,&height)) fail("Swapchain"); if(!backbuffer) { SDL_SubmitGPUCommandBuffer(commands); return; }
    ensureDepthBuffer(width, height);
    SDL_GPUColorTargetInfo target{}; target.texture=backbuffer; target.clear_color={.208f,.208f,.275f,1}; target.load_op=SDL_GPU_LOADOP_CLEAR; target.store_op=SDL_GPU_STOREOP_STORE;
    SDL_GPUDepthStencilTargetInfo depth{}; depth.texture=depthBuffer_; depth.clear_depth=1.f; depth.load_op=SDL_GPU_LOADOP_CLEAR; depth.store_op=SDL_GPU_STOREOP_DONT_CARE;
    SDL_GPURenderPass* pass=SDL_BeginGPURenderPass(commands,&target,1,&depth); SDL_GPUBufferBinding buffer{vertexBuffer_,0}; SDL_BindGPUVertexBuffers(pass,0,&buffer,1);
    const float flightZ = -4.f - flightDistance_;
    // main.lua erzeugt das Terrain von z=0 nach z=-84: Flug ausschließlich -Z.
    const Vec3 eye{0.f, 32.f, flightZ + 12.f};
    const Vec3 lookAt{0.f, terrainHeightAt(0.f, flightZ - 10.f), flightZ - 10.f};
    const Mat4 viewProjection=camera(eye, lookAt, static_cast<float>(width)/height); SDL_PushGPUVertexUniformData(commands,0,&viewProjection,sizeof(viewProjection));
    const Material fill{{.565f,.404f,.463f,1},{.208f,.208f,.275f,1}}, wire{{1,1,1,1},{.208f,.208f,.275f,1}};
    SDL_BindGPUGraphicsPipeline(pass,fillPipeline_); SDL_PushGPUFragmentUniformData(commands,0,&fill,sizeof(fill)); SDL_DrawGPUPrimitives(pass,vertexCount_,1,0,0); SDL_EndGPURenderPass(pass);
    if(!SDL_SubmitGPUCommandBuffer(commands)) fail("Frame einreichen");
}

} // namespace heightmap
