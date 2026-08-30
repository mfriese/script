-- Planet Heli - LÖVR 0.19 prototype
-- A desktop/VR 3D canyon flight.  Start with: lovr .

local heli = { x = 0, velocity = 0, roll = 0 }
local world = { distance = 0, speed = 18, minSpeed = 8, maxSpeed = 32 }
local lightingShader
local terrainMesh
local heightmap = {}
local heightmapImage

-- One terrain tile is a 128 x 32 PNG.  Its alpha channel is the height
-- (0 = canyon floor, 1 = canyon rim); RGB is intentionally ignored.
local HEIGHTMAP_WIDTH, HEIGHTMAP_DEPTH = 64, 256
local TERRAIN_WIDTH, TERRAIN_DEPTH, TERRAIN_HEIGHT = 52, 84, 18
local TERRAIN_STEP_X, TERRAIN_STEP_Z = 4, 2

local function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end

local function reset()
  heli.x, heli.velocity, heli.roll = 0, 0, 0
  world.distance, world.speed = 0, 18
end

local function buildHeightmapTerrain()
  local vertices = {}
  local xStep = TERRAIN_WIDTH / (HEIGHTMAP_WIDTH - 1)
  local zStep = TERRAIN_DEPTH / (HEIGHTMAP_DEPTH - 1)

  local imageWidth, imageHeight = heightmapImage:getDimensions()
  assert(imageWidth == HEIGHTMAP_WIDTH and imageHeight == HEIGHTMAP_DEPTH,
    string.format('heightmap.png must be %d x %d pixels (got %d x %d)',
      HEIGHTMAP_WIDTH, HEIGHTMAP_DEPTH, imageWidth, imageHeight))
  for z = 0, HEIGHTMAP_DEPTH - 1 do
    heightmap[z + 1] = {}
    for x = 0, HEIGHTMAP_WIDTH - 1 do
      local _, _, _, alpha = heightmapImage:getPixel(x, z)
      heightmap[z + 1][x + 1] = alpha
    end
  end

  local function getHeight(x, z)
    x = clamp(x, 0, HEIGHTMAP_WIDTH - 1)
    z = z % (HEIGHTMAP_DEPTH - 1)
    return heightmap[z + 1][x + 1]
  end

  local function addTriangle(ax, az, bx, bz, cx, cz)
    local ay = getHeight(ax, az) * TERRAIN_HEIGHT
    local by = getHeight(bx, bz) * TERRAIN_HEIGHT
    local cy = getHeight(cx, cz) * TERRAIN_HEIGHT
    local axw, bxw, cxw = -TERRAIN_WIDTH * .5 + ax * xStep, -TERRAIN_WIDTH * .5 + bx * xStep, -TERRAIN_WIDTH * .5 + cx * xStep
    local azw, bzw, czw = -az * zStep, -bz * zStep, -cz * zStep
    local ux, uy, uz = bxw - axw, by - ay, bzw - azw
    local vx, vy, vz = cxw - axw, cy - ay, czw - azw
    local nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
    local length = math.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / length, ny / length, nz / length

    -- All three corners receive exactly the same face normal: flat shading.
    local function addCorner(x, y, z, wx, wz)
      vertices[#vertices + 1] = {
        wx, y, wz, nx, ny, nz,
        x / (HEIGHTMAP_WIDTH - 1), z / (HEIGHTMAP_DEPTH - 1)
      }
    end
    addCorner(ax, ay, az, axw, azw)
    addCorner(bx, by, bz, bxw, bzw)
    addCorner(cx, cy, cz, cxw, czw)
  end

  -- Keep the source heightmap at 128 x 32, but sample it coarsely for the
  -- visible mesh: 33 x 17 points, yielding broad low-poly canyon facets.
  local xSamples, zSamples = {}, {}
  for x = 0, HEIGHTMAP_WIDTH - 1, TERRAIN_STEP_X do xSamples[#xSamples + 1] = x end
  for z = 0, HEIGHTMAP_DEPTH - 1, TERRAIN_STEP_Z do zSamples[#zSamples + 1] = z end
  if xSamples[#xSamples] ~= HEIGHTMAP_WIDTH - 1 then xSamples[#xSamples + 1] = HEIGHTMAP_WIDTH - 1 end
  if zSamples[#zSamples] ~= HEIGHTMAP_DEPTH - 1 then zSamples[#zSamples + 1] = HEIGHTMAP_DEPTH - 1 end

  for z = 1, #zSamples - 1 do
    for x = 1, #xSamples - 1 do
      local x0, x1 = xSamples[x], xSamples[x + 1]
      local z0, z1 = zSamples[z], zSamples[z + 1]
      addTriangle(x0, z0, x1, z0, x0, z1)
      addTriangle(x1, z0, x1, z1, x0, z1)
    end
  end

  -- Be explicit about the layout: the terrain shader needs the generated
  -- normal and UV attributes in addition to the heightmap position.
  terrainMesh = lovr.graphics.newMesh({
    { 'VertexPosition', 'vec3' },
    { 'VertexNormal', 'vec3' },
    { 'VertexUV', 'vec2' }
  }, vertices)
end

local function canyonCenterAt(distance)
  return math.sin((distance % TERRAIN_DEPTH) / TERRAIN_DEPTH * math.pi * 2) * 3.5
end

local function drawTerrain(pass)
  local firstTile = math.floor(world.distance / TERRAIN_DEPTH)
  pass:setColor(.42, .28, .15)
  for tile = firstTile, firstTile + 3 do
    pass:draw(terrainMesh, 0, 0, world.distance - tile * TERRAIN_DEPTH)
  end
end

local function drawHelicopter(pass)
  local x, y, z = heli.x, 1.45, -3.8
  pass:push()
  pass:translate(x, y, z)
  pass:rotate(heli.roll, 0, 0, 1)

  -- Fuselage and cockpit.
  pass:setColor(.76, .20, .08)
  pass:box(0, 0, 0, 1.35, .55, 2.3)
  pass:setColor(.08, .17, .21)
  pass:sphere(0, .08, -1.05, .62)
  -- Tail boom, fin and landing skids.
  pass:setColor(.48, .13, .05)
  pass:box(0, .03, 1.7, .22, .22, 2.1)
  pass:box(0, .7, 2.45, .12, 1.25, .7)
  pass:setColor(.18, .19, .17)
  pass:box(-.48, -.48, .15, .08, .08, 2.1)
  pass:box(.48, -.48, .15, .08, .08, 2.1)
  -- Mast and spinning rotor (two crossed thin blades).
  pass:setColor(.22, .22, .20)
  pass:cylinder(0, .66, 0, .07, .75)
  local spin = lovr.timer.getTime() * 18
  pass:box(0, 1.08, 0, 6.2, .045, .11, spin, 0, 1, 0)
  pass:box(0, 1.08, 0, .11, .045, 6.2, spin, 0, 1, 0)
  pass:pop()
end

function lovr.load()
  lovr.graphics.setBackgroundColor(.11, .23, .32)
  heightmapImage = lovr.data.newImage('heightmap.png')
  lightingShader = lovr.graphics.newShader([[
    vec4 lovrmain() {
      return Projection * View * Transform * VertexPosition;
    }
  ]], [[
    Constants {
      vec3 lightPosition;
      vec3 lightColor;
      vec3 ambientColor;
    };

    vec4 lovrmain() {
      vec4 baseColor = Color * getPixel(ColorTexture, UV);
      vec3 toLight = lightPosition - PositionWorld;
      float distanceToLight = length(toLight);
      vec3 lightDirection = toLight / max(distanceToLight, .001);
      vec3 normal = normalize(Normal);

      // Lambert diffuse lighting: surfaces facing the light become brighter.
      float diffuse = max(dot(normal, lightDirection), 0.0);
      float attenuation = 1.0 / (1.0 + .018 * distanceToLight * distanceToLight);

      // A restrained Blinn-Phong highlight makes the helicopter's geometry
      // read clearly without turning the canyon into polished metal.
      vec3 viewDirection = normalize(CameraPositionWorld - PositionWorld);
      vec3 halfDirection = normalize(lightDirection + viewDirection);
      float specular = pow(max(dot(normal, halfDirection), 0.0), 28.0) * .16;
      vec3 illumination = ambientColor + (diffuse + specular) * lightColor * attenuation;
      return vec4(baseColor.rgb * illumination, baseColor.a);
    }
  ]], {})
  buildHeightmapTerrain()
  reset()
end

function lovr.update(dt)
  dt = math.min(dt, 1 / 30)
  local left = lovr.system.isKeyDown('left', 'a')
  local right = lovr.system.isKeyDown('right', 'd')
  if left then heli.velocity = heli.velocity - 18 * dt end
  if right then heli.velocity = heli.velocity + 18 * dt end
  if not left and not right then heli.velocity = heli.velocity * math.pow(.05, dt) end

  heli.velocity = clamp(heli.velocity, -10, 10)
  heli.x = heli.x + heli.velocity * dt
  local center = canyonCenterAt(world.distance)
  heli.x = clamp(heli.x, center - 9, center + 9)
  heli.roll = heli.roll + ((-heli.velocity * .055) - heli.roll) * math.min(1, dt * 7)

  if lovr.system.isKeyDown('w', 'up') then world.speed = world.speed + 13 * dt end
  if lovr.system.isKeyDown('s', 'down') then world.speed = world.speed - 13 * dt end
  world.speed = clamp(world.speed, world.minSpeed, world.maxSpeed)
  world.distance = world.distance + world.speed * dt

  if lovr.system.wasKeyPressed('r') then reset() end
  if lovr.system.wasKeyPressed('escape') then lovr.event.quit() end
end

function lovr.draw(pass)
  -- Fixed chase camera: 7.5 m above and behind the helicopter.  Looking at
  -- the fuselage creates a 45 degree downward view and keeps the canyon ahead
  -- in frame as the helicopter changes lanes.
  local targetX, targetY, targetZ = heli.x, 1.45, -3.8
  local cameraX, cameraY, cameraZ = targetX, targetY + 3.5, targetZ + 7.5
  local direction = vector(targetX - cameraX, targetY - cameraY, targetZ - cameraZ)
  local orientation = quaternion.lookdir(direction, vector(0, 1, 0))
  for view = 1, pass:getViewCount() do
    pass:setViewPose(view, vector(cameraX, cameraY, cameraZ), orientation)
  end

  -- A warm, mobile key light leads the flight path.  It stays above and 8 m
  -- ahead of the helicopter, so approaching canyon walls are illuminated.
  local lightX, lightY, lightZ = heli.x, 6.5, -11.8
  pass:setShader(lightingShader)
  pass:send('lightPosition', { lightX, lightY, lightZ })
  pass:send('lightColor', { 1.0, .76, .46 })
  pass:send('ambientColor', { .15, .19, .24 })
  drawTerrain(pass)
  drawHelicopter(pass)

  -- Visible, unlit marker for the helicopter's forward-mounted searchlight.
  pass:setShader()
  pass:setColor(1, .72, .28)
  pass:sphere(lightX, lightY, lightZ, .18)
end
