--!strict
-- World 1 (Gray Plaza): a harbor island at sea level instead of the old floating sky
-- plaza. Built entirely at server start, so the repo stays the single source of truth.
--
-- Layout (sea level is Y = 0, island ground is Y = GROUND_Y):
--   south  - arrival: spawn on the harbor path, the pier and moored boat beyond it
--   center - stone plaza with the fountain, prestige showcase, and the world portal
--   ring   - 30 market booths in two arcs facing the fountain, so a donor standing
--            anywhere in the plaza can see every booth at once (density sells)
--   north  - grass hill with a summit, a lighthouse on the north-east headland
--   sea    - three obby islets (Turtle Islet, Spire Islet, Sky Rocks to the sea stack)
--   around - 8 landmarks to discover (DiscoveryService) for one-time XP
--
-- Art: props come from ServerStorage.LobbyAssets (meshes modeled in Blender, see
-- art/blender) when present, and fall back to primitive builds otherwise, so the game
-- never breaks on a place without the imported assets.
--
-- World 1 is the Gray class: pleasant, natural, weathered stone and wood. It is
-- deliberately humble next to what Green and above get (no marble, gold or neon
-- architecture), so every promotion still feels like moving up.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local IslandBuilder = {}

local GROUND_Y = 5
local SEA_FLOOR_Y = -30
local STAND_COUNT = 30
local BOOTH_RADIUS = 108
local PLAZA_RADIUS = 60

IslandBuilder.GroundY = GROUND_Y
IslandBuilder.StandCount = STAND_COUNT
-- Water catches every fall on the island, so the kill plane is only a safety net for
-- anything that glitches through terrain.
IslandBuilder.KillY = -200

local TAGS = {
	stand = "DonationStand",
	obbyFinish = "ObbyFinish",
	checkpoint = "ObbyCheckpoint",
	teleporterPrompt = "WorldTeleporterPrompt",
	prestige = "PrestigeStand",
	discovery = "Discovery",
}

-- Palette for the Gray class: warm weathered wood, cool stone, off-white canvas.
local COLORS = {
	stone = Color3.fromRGB(150, 148, 142),
	stoneDark = Color3.fromRGB(108, 106, 102),
	stoneLight = Color3.fromRGB(190, 187, 180),
	wood = Color3.fromRGB(122, 92, 64),
	woodDark = Color3.fromRGB(86, 64, 46),
	canvas = Color3.fromRGB(226, 222, 212),
	canvasStripe = Color3.fromRGB(128, 132, 140),
	iron = Color3.fromRGB(52, 52, 56),
	lampGlow = Color3.fromRGB(255, 196, 120),
	water = Color3.fromRGB(70, 150, 170),
	rock = Color3.fromRGB(112, 108, 100),
	leaf = Color3.fromRGB(76, 118, 58),
	trunk = Color3.fromRGB(116, 90, 62),
}

------------------------------------------------------------------------------------
-- Small helpers
------------------------------------------------------------------------------------

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = props.Parent
	return p
end

-- Roblox cylinders run along X; this stands them upright.
local function uprightCylinder(props: { [string]: any }, position: Vector3, height: number, diameter: number): Part
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, diameter, diameter)
	props.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	return part(props)
end

local function smoothstep(edge0: number, edge1: number, x: number): number
	local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Clones a Blender-made template from ServerStorage.LobbyAssets if one exists.
-- Returns nil when the asset hasn't been imported, so callers fall back to primitives.
local assetFolder: Folder? = nil
local function tryAsset(name: string, pivot: CFrame, parent: Instance, scale: number?): Model?
	if not assetFolder then
		return nil
	end
	local template = assetFolder:FindFirstChild(name)
	if not template or not template:IsA("Model") then
		return nil
	end
	local clone = template:Clone()
	if scale and scale ~= 1 then
		clone:ScaleTo(scale)
	end
	clone:PivotTo(pivot)
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
	clone.Parent = parent
	return clone
end

local function addDiscovery(parent: Instance, id: string, displayName: string, position: Vector3, size: Vector3, xp: number)
	local trigger = part({
		Name = `Discovery_{id}`,
		Size = size,
		CFrame = CFrame.new(position),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = parent,
	})
	trigger:SetAttribute("DiscoveryId", id)
	trigger:SetAttribute("DisplayName", displayName)
	trigger:SetAttribute("XpReward", xp)
	CollectionService:AddTag(trigger, TAGS.discovery)
end

------------------------------------------------------------------------------------
-- Terrain: one height function describes the whole island; WriteVoxels turns it into
-- smooth terrain with materials chosen by height, slope and path masks.
------------------------------------------------------------------------------------

type Feature = { x: number, z: number, radius: number, height: number, kind: string }

local FEATURES: { Feature } = {
	-- North-west grass hill with the summit landmark.
	{ x = -170, z = -150, radius = 95, height = 40, kind = "dome" },
	-- North-east headland the lighthouse stands on.
	{ x = 168, z = -172, radius = 64, height = 22, kind = "mesa" },
	-- Obby islets.
	{ x = 392, z = 30, radius = 46, height = 1.5, kind = "islet" }, -- Turtle Islet (east)
	{ x = -402, z = 70, radius = 48, height = 1.5, kind = "islet" }, -- Spire Islet (west)
	{ x = -262, z = -352, radius = 16, height = 52, kind = "stack" }, -- sea stack (Sky Rocks)
}

local function coastRadius(x: number, z: number): number
	local theta = math.atan2(z, x)
	return 236 + math.noise(math.cos(theta) * 2.2, math.sin(theta) * 2.2, 3.1) * 30
end

local function baseHeight(x: number, z: number): number
	local r = math.sqrt(x * x + z * z)
	local coast = coastRadius(x, z)
	local h: number
	if r < coast - 46 then
		h = GROUND_Y + math.noise(x / 70, z / 70, 0.4) * 2 * smoothstep(150, 190, r)
	elseif r < coast + 8 then
		-- The beach: a long gentle slope from grass down into the shallows.
		h = lerp(GROUND_Y, -1.5, smoothstep(coast - 46, coast + 8, r))
	else
		h = lerp(-1.5, SEA_FLOOR_Y, smoothstep(coast + 8, coast + 110, r))
	end
	return h
end

local function featureHeight(f: Feature, x: number, z: number): number
	local d = math.sqrt((x - f.x) ^ 2 + (z - f.z) ^ 2)
	if d >= f.radius then
		return -math.huge
	end
	local t = d / f.radius
	if f.kind == "dome" then
		local bump = (1 - t * t) ^ 2
		return GROUND_Y + f.height * bump + math.noise(x / 26, z / 26, 7.7) * 3 * bump
	elseif f.kind == "mesa" then
		-- Flat top for the lighthouse, steep but climbable sides.
		return GROUND_Y + f.height * smoothstep(1, 0.62, t) + math.noise(x / 14, z / 14, 2.2) * 1.5 * (1 - t)
	elseif f.kind == "islet" then
		return lerp(SEA_FLOOR_Y, GROUND_Y + f.height, smoothstep(1, 0.55, t))
			+ math.noise(x / 18, z / 18, 5.5) * 1.5 * (1 - t)
	elseif f.kind == "stack" then
		return lerp(SEA_FLOOR_Y, f.height, smoothstep(1, 0.7, t)) + math.noise(x / 6, z / 6, 9.1) * 2
	end
	return -math.huge
end

local function surfaceHeight(x: number, z: number): number
	local h = baseHeight(x, z)
	for _, f in FEATURES do
		h = math.max(h, featureHeight(f, x, z))
	end
	-- The plaza and booth ring are dead flat so stalls sit cleanly on the ground.
	local r = math.sqrt(x * x + z * z)
	local flatten = 1 - smoothstep(138, 160, r)
	return lerp(h, GROUND_Y, flatten)
end

local function distanceToSegment(px: number, pz: number, ax: number, az: number, bx: number, bz: number): number
	local abx, abz = bx - ax, bz - az
	local t = math.clamp(((px - ax) * abx + (pz - az) * abz) / (abx * abx + abz * abz), 0, 1)
	local cx, cz = ax + abx * t, az + abz * t
	return math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2)
end

-- Footpaths are what make the island read as a place people walk around in rather
-- than a heightmap: the booth promenade, the harbor road, and trails to each landmark.
local PATHS = {
	{ 0, 124, 0, 236, 9 }, -- harbor road south to the pier
	{ 0, -124, 120, -150, 6 }, -- to the lighthouse headland
	{ -60, -110, -150, -130, 5 }, -- to the hill
	{ 110, 40, 222, 30, 5 }, -- east to the Turtle Islet stepping stones
	{ -110, 50, -226, 64, 5 }, -- west to the Spire Islet
}

local function pathMask(x: number, z: number): boolean
	local r = math.sqrt(x * x + z * z)
	if r > BOOTH_RADIUS - 18 and r < BOOTH_RADIUS + 16 then
		return true
	end
	for _, seg in PATHS do
		if distanceToSegment(x, z, seg[1], seg[2], seg[3], seg[4]) < seg[5] then
			return true
		end
	end
	return false
end

local function materialFor(x: number, z: number, h: number): Enum.Material
	local slope = math.max(
		math.abs(surfaceHeight(x + 4, z) - h),
		math.abs(surfaceHeight(x, z + 4) - h)
	) / 4
	if h < -0.5 then
		return if math.noise(x / 40, z / 40, 1.1) > 0.25 then Enum.Material.Ground else Enum.Material.Sand
	end
	if slope > 0.85 then
		return Enum.Material.Rock
	end
	if h < 3.2 then
		return Enum.Material.Sand
	end
	-- Under the paved plaza: no grass, or its blades poke up through the paving parts.
	if x * x + z * z < (PLAZA_RADIUS + 3) ^ 2 then
		return Enum.Material.Pavement
	end
	if pathMask(x, z) and h < GROUND_Y + 1.5 then
		return Enum.Material.Cobblestone
	end
	if slope > 0.5 or h > GROUND_Y + 30 then
		return if math.noise(x / 12, z / 12, 4.4) > 0 then Enum.Material.Rock else Enum.Material.Grass
	end
	local patch = math.noise(x / 34, z / 34, 8.8)
	if patch > 0.3 then
		return Enum.Material.LeafyGrass
	end
	return Enum.Material.Grass
end

local VOXEL = 4
local TERRAIN_HALF = 512 -- island region spans -512..512 on X and Z
local TERRAIN_MIN_Y = -48
local TERRAIN_MAX_Y = 80
local CHUNK = 64 -- voxels per chunk side

local function writeChunk(terrain: Terrain, cx0: number, cz0: number)
	local ny = (TERRAIN_MAX_Y - TERRAIN_MIN_Y) // VOXEL
	local materials = table.create(CHUNK)
	local occupancies = table.create(CHUNK)
	for ix = 1, CHUNK do
		local matX = table.create(ny)
		local occX = table.create(ny)
		for iy = 1, ny do
			matX[iy] = table.create(CHUNK)
			occX[iy] = table.create(CHUNK)
		end
		local x = cx0 + (ix - 0.5) * VOXEL
		for iz = 1, CHUNK do
			local z = cz0 + (iz - 0.5) * VOXEL
			local h = surfaceHeight(x, z)
			local surfaceMat = materialFor(x, z, h)
			for iy = 1, ny do
				local y0 = TERRAIN_MIN_Y + (iy - 1) * VOXEL
				local occupancy = math.clamp((h - y0) / VOXEL, 0, 1)
				if occupancy > 0 then
					matX[iy][iz] = if h - y0 > 10 then Enum.Material.Rock else surfaceMat
					occX[iy][iz] = occupancy
				elseif y0 < 0 then
					matX[iy][iz] = Enum.Material.Water
					occX[iy][iz] = 1
				else
					matX[iy][iz] = Enum.Material.Air
					occX[iy][iz] = 0
				end
			end
		end
		materials[ix] = matX
		occupancies[ix] = occX
	end
	local region = Region3.new(
		Vector3.new(cx0, TERRAIN_MIN_Y, cz0),
		Vector3.new(cx0 + CHUNK * VOXEL, TERRAIN_MAX_Y, cz0 + CHUNK * VOXEL)
	)
	terrain:WriteVoxels(region, VOXEL, materials, occupancies)
end

local function buildTerrain()
	local terrain = Workspace.Terrain
	terrain:Clear()

	-- Open ocean well past the island region, so the horizon is water in every
	-- direction (atmosphere haze hides the far edge).
	terrain:FillBlock(CFrame.new(0, -40, 0), Vector3.new(4096, 16, 4096), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(0, -16, 0), Vector3.new(4096, 32, 4096), Enum.Material.Water)

	local chunkStuds = CHUNK * VOXEL
	for cx = -TERRAIN_HALF, TERRAIN_HALF - chunkStuds, chunkStuds do
		for cz = -TERRAIN_HALF, TERRAIN_HALF - chunkStuds, chunkStuds do
			writeChunk(terrain, cx, cz)
		end
	end

	terrain.WaterColor = Color3.fromRGB(38, 118, 128)
	terrain.WaterTransparency = 0.45
	terrain.WaterReflectance = 0.6
	terrain.WaterWaveSize = 0.18
	terrain.WaterWaveSpeed = 8
	pcall(function()
		terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(104, 132, 70))
		terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(92, 120, 62))
		terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(212, 196, 156))
		terrain:SetMaterialColor(Enum.Material.Cobblestone, Color3.fromRGB(150, 146, 138))
		terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(118, 114, 106))
		terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(120, 106, 82))
	end)

	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.55
	clouds.Color = Color3.fromRGB(240, 240, 245)
	clouds.Parent = terrain
end

------------------------------------------------------------------------------------
-- Lighting: soft afternoon. Pleasant and clean - the dramatic skies are saved for
-- higher worlds.
------------------------------------------------------------------------------------

local function setupLighting()
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") or child:IsA("PostEffect") or child:IsA("Sky") then
			child:Destroy()
		end
	end

	Lighting.ClockTime = 15.2
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(88, 90, 100)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 130, 140)
	Lighting.EnvironmentDiffuseScale = 0.8
	Lighting.EnvironmentSpecularScale = 0.8
	Lighting.ShadowSoftness = 0.25
	Lighting.FogEnd = 100000

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.27
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(200, 214, 228)
	atmosphere.Decay = Color3.fromRGB(110, 128, 150)
	atmosphere.Glare = 0.25
	atmosphere.Haze = 1.4
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 26
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Intensity = 0.05
	sunRays.Spread = 0.6
	sunRays.Parent = Lighting

	local grade = Instance.new("ColorCorrectionEffect")
	grade.Saturation = 0.06
	grade.Contrast = 0.06
	grade.TintColor = Color3.fromRGB(255, 251, 244)
	grade.Parent = Lighting
end

------------------------------------------------------------------------------------
-- Props (Blender asset first, primitive fallback)
------------------------------------------------------------------------------------

local function buildLamp(parent: Instance, position: Vector3)
	local pivot = CFrame.new(position)
	local asset = tryAsset("LampPost", pivot, parent)
	if asset then
		local glass = asset:FindFirstChild("Glass")
		if glass then
			local light = Instance.new("PointLight")
			light.Color = COLORS.lampGlow
			light.Range = 18
			light.Brightness = 1.2
			light.Shadows = false
			light.Parent = glass
		end
		return
	end
	local lamp = Instance.new("Model")
	lamp.Name = "LampPost"
	uprightCylinder({ Name = "Pole", Material = Enum.Material.Metal, Color = COLORS.iron, Parent = lamp },
		position + Vector3.new(0, 6, 0), 12, 0.5)
	uprightCylinder({ Name = "Base", Material = Enum.Material.Slate, Color = COLORS.stoneDark, Parent = lamp },
		position + Vector3.new(0, 0.5, 0), 1, 1.6)
	local lantern = part({
		Name = "Lantern",
		Size = Vector3.new(1.3, 1.6, 1.3),
		CFrame = CFrame.new(position + Vector3.new(0, 12.6, 0)),
		Material = Enum.Material.Glass,
		Transparency = 0.2,
		Color = COLORS.lampGlow,
		CanCollide = false,
		Parent = lamp,
	})
	part({
		Name = "Cap",
		Size = Vector3.new(1.8, 0.35, 1.8),
		CFrame = CFrame.new(position + Vector3.new(0, 13.5, 0)),
		Material = Enum.Material.Metal,
		Color = COLORS.iron,
		CanCollide = false,
		Parent = lamp,
	})
	local light = Instance.new("PointLight")
	light.Color = COLORS.lampGlow
	light.Range = 18
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = lantern
	lamp.Parent = parent
end

local function buildPalm(parent: Instance, position: Vector3, seed: number)
	local yaw = CFrame.Angles(0, seed * 2.39, 0)
	local scale = 0.85 + (seed % 5) * 0.08
	if tryAsset(seed % 2 == 0 and "PalmA" or "PalmB", CFrame.new(position) * yaw, parent, scale) then
		return
	end
	local palm = Instance.new("Model")
	palm.Name = "Palm"
	-- A gently curving trunk from short tapered segments, leaning away from the center.
	local lean = yaw * CFrame.Angles(math.rad(6), 0, 0)
	local cf = CFrame.new(position) * lean
	local segments = 7
	for i = 1, segments do
		local diameter = 2.2 - i * 0.15
		local seg = part({
			Name = "Trunk",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3.4 * scale, diameter, diameter),
			CFrame = cf * CFrame.new(0, 1.7 * scale, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Wood,
			Color = COLORS.trunk,
			Parent = palm,
		})
		seg.CanCollide = i <= 2
		cf = cf * CFrame.new(0, 3.2 * scale, 0) * CFrame.Angles(math.rad(3), 0, 0)
	end
	for i = 1, 7 do
		local angle = i / 7 * math.pi * 2
		local frond = part({
			Name = "Frond",
			Size = Vector3.new(1.6, 0.25, 9 * scale),
			CFrame = cf * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -4 * scale) * CFrame.Angles(math.rad(-22), 0, 0),
			Material = Enum.Material.Grass,
			Color = COLORS.leaf,
			CanCollide = false,
			Parent = palm,
		})
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = frond
	end
	palm.Parent = parent
end

local function buildRock(parent: Instance, position: Vector3, size: number, seed: number)
	local cf = CFrame.new(position) * CFrame.Angles(seed * 0.7, seed * 1.9, seed * 0.3)
	local names = { "RockA", "RockB", "RockC" }
	if tryAsset(names[(seed % 3) + 1], cf, parent, size / 8) then
		return
	end
	part({
		Name = "Rock",
		Size = Vector3.new(size, size * 0.7, size * 0.9),
		CFrame = cf,
		Material = Enum.Material.Slate,
		Color = COLORS.rock,
		Parent = parent,
	})
end

local function buildBench(parent: Instance, cf: CFrame)
	if tryAsset("Bench", cf, parent) then
		return
	end
	part({ Name = "Seat", Size = Vector3.new(7, 0.5, 2), CFrame = cf * CFrame.new(0, 1.6, 0), Material = Enum.Material.WoodPlanks, Color = COLORS.wood, Parent = parent })
	part({ Name = "Back", Size = Vector3.new(7, 1.6, 0.4), CFrame = cf * CFrame.new(0, 2.6, 0.9) * CFrame.Angles(math.rad(-10), 0, 0), Material = Enum.Material.WoodPlanks, Color = COLORS.wood, Parent = parent })
	for _, side in { -1, 1 } do
		part({ Name = "Leg", Size = Vector3.new(0.5, 1.4, 2), CFrame = cf * CFrame.new(side * 3, 0.7, 0), Material = Enum.Material.Metal, Color = COLORS.iron, Parent = parent })
	end
end

------------------------------------------------------------------------------------
-- Plaza and fountain
------------------------------------------------------------------------------------

local function buildFountain(parent: Instance)
	local base = Vector3.new(0, GROUND_Y + 0.6, 0)
	local fountain: Model = tryAsset("Fountain", CFrame.new(base), parent) or Instance.new("Model")
	if not fountain.Parent then
		local f = fountain
		f.Name = "Fountain"
		uprightCylinder({ Name = "Basin", Material = Enum.Material.Slate, Color = COLORS.stoneLight, Parent = f }, base + Vector3.new(0, 1.2, 0), 2.4, 30)
		uprightCylinder({ Name = "BasinWater", Material = Enum.Material.Glass, Transparency = 0.35, Color = COLORS.water, CanCollide = false, Parent = f }, base + Vector3.new(0, 2.1, 0), 0.6, 27)
		uprightCylinder({ Name = "Column", Material = Enum.Material.Slate, Color = COLORS.stone, Parent = f }, base + Vector3.new(0, 5, 0), 7, 3.2)
		uprightCylinder({ Name = "UpperBowl", Material = Enum.Material.Slate, Color = COLORS.stoneLight, Parent = f }, base + Vector3.new(0, 8.6, 0), 1.2, 11)
		uprightCylinder({ Name = "UpperWater", Material = Enum.Material.Glass, Transparency = 0.35, Color = COLORS.water, CanCollide = false, Parent = f }, base + Vector3.new(0, 9.1, 0), 0.4, 9.6)
		uprightCylinder({ Name = "Spire", Material = Enum.Material.Slate, Color = COLORS.stone, Parent = f }, base + Vector3.new(0, 11.2, 0), 4, 1.4)
		part({ Name = "Finial", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.2, 2.2), CFrame = CFrame.new(base + Vector3.new(0, 13.6, 0)), Material = Enum.Material.Slate, Color = COLORS.stoneLight, Parent = f })
		f.Parent = parent
	end

	-- Water spray: particles read as moving water far better than any static mesh.
	local emitterPart = part({
		Name = "SprayEmitter",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(base + Vector3.new(0, 14, 0)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = fountain,
	})
	local spray = Instance.new("ParticleEmitter")
	spray.Texture = "rbxasset://textures/particles/smoke_main.dds"
	spray.Color = ColorSequence.new(Color3.fromRGB(220, 240, 255))
	spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.8) })
	spray.Lifetime = NumberRange.new(1.1, 1.5)
	spray.Speed = NumberRange.new(9, 12)
	spray.SpreadAngle = Vector2.new(18, 18)
	spray.Acceleration = Vector3.new(0, -26, 0)
	spray.Rate = 60
	spray.Parent = emitterPart
end

local function buildPlaza(parent: Instance)
	local plaza = Instance.new("Folder")
	plaza.Name = "Plaza"
	plaza.Parent = parent

	-- Paved disc with a darker inlaid ring; slightly raised so it reads as built ground.
	uprightCylinder({ Name = "Paving", Material = Enum.Material.Pavement, Color = COLORS.stoneLight, Parent = plaza },
		Vector3.new(0, GROUND_Y + 0.3, 0), 0.6, PLAZA_RADIUS * 2)
	uprightCylinder({ Name = "Inlay", Material = Enum.Material.Slate, Color = COLORS.stoneDark, Parent = plaza },
		Vector3.new(0, GROUND_Y + 0.35, 0), 0.6, 44)
	uprightCylinder({ Name = "InlayInner", Material = Enum.Material.Pavement, Color = COLORS.stoneLight, Parent = plaza },
		Vector3.new(0, GROUND_Y + 0.4, 0), 0.6, 40)
	uprightCylinder({ Name = "Curb", Material = Enum.Material.Slate, Color = COLORS.stoneDark, Parent = plaza },
		Vector3.new(0, GROUND_Y + 0.15, 0), 0.6, PLAZA_RADIUS * 2 + 3)

	buildFountain(plaza)

	-- Benches facing the fountain, between the plaza's four entrances.
	for i = 0, 7 do
		local angle = (i + 0.5) / 8 * math.pi * 2
		local pos = Vector3.new(math.cos(angle) * 34, GROUND_Y + 0.6, math.sin(angle) * 34)
		buildBench(plaza, CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0)) * CFrame.Angles(0, math.pi, 0))
	end
	-- Lamps around the plaza rim.
	for i = 0, 11 do
		local angle = i / 12 * math.pi * 2 + math.pi / 12
		buildLamp(plaza, Vector3.new(math.cos(angle) * (PLAZA_RADIUS - 3), GROUND_Y + 0.6, math.sin(angle) * (PLAZA_RADIUS - 3)))
	end
end

------------------------------------------------------------------------------------
-- Booths (DonationStand contract: Podium + DonatePrompt, SignPost > Sign > OwnerLabel
-- / TitleLabel / RaisedLabel, optional TierRing and Canopy). See StandService.
------------------------------------------------------------------------------------

-- y/height are fractions of the sign. Signs are sized in studs (UDim2 scale on a
-- BillboardGui), so they shrink with distance like real signage; pixel-sized signs
-- stay huge from across the plaza and 30 of them bury the view.
local function signLabel(name: string, y: number, height: number, font: Enum.Font, color: Color3, parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.fromScale(1, height)
	label.Position = UDim2.fromScale(0, y)
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.5
	label.Text = ""
	label.Parent = parent
	return label
end

local function buildBooth(parent: Instance, index: number, standCf: CFrame)
	-- standCf: origin on the ground at the booth center, -Z (LookVector) facing the plaza.
	local stand = Instance.new("Model")
	stand.Name = `Stand_{index}`

	local deck = part({
		Name = "Deck",
		Size = Vector3.new(11, 0.6, 9),
		CFrame = standCf * CFrame.new(0, 0.3, 0.5),
		Material = Enum.Material.WoodPlanks,
		Color = COLORS.woodDark,
		Parent = stand,
	})
	deck:SetAttribute("BoothIndex", index)

	-- The shell (awning, posts, back wall) is the Blender booth when available.
	local shell = tryAsset("BoothShell", standCf, stand)
	if not shell then
		for _, side in { -1, 1 } do
			for _, depth in { -3, 4 } do
				part({
					Name = "Post",
					Size = Vector3.new(0.6, 9, 0.6),
					CFrame = standCf * CFrame.new(side * 5, 4.8, depth),
					Material = Enum.Material.Wood,
					Color = COLORS.wood,
					Parent = stand,
				})
			end
		end
		part({
			Name = "BackWall",
			Size = Vector3.new(10, 5, 0.4),
			CFrame = standCf * CFrame.new(0, 3.1, 4.2),
			Material = Enum.Material.WoodPlanks,
			Color = COLORS.wood,
			Parent = stand,
		})
		-- Striped canvas awning, tilted down toward the front.
		for stripe = 0, 5 do
			part({
				Name = "Awning",
				Size = Vector3.new(11.6 / 6, 0.2, 9.6),
				CFrame = standCf * CFrame.new(-5.8 + (stripe + 0.5) * 11.6 / 6, 9.6, 0.4) * CFrame.Angles(math.rad(-12), 0, 0),
				Material = Enum.Material.Fabric,
				Color = stripe % 2 == 0 and COLORS.canvas or COLORS.canvasStripe,
				CanCollide = false,
				Parent = stand,
			})
		end
	end

	local tierRing = part({
		Name = "TierRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 15, 15),
		CFrame = standCf * CFrame.new(0, 0.62, 0.5) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(150, 150, 150),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = stand,
	})
	tierRing.CastShadow = false

	-- The counter is the Podium: StandService recolors and re-materials it by rank, so
	-- the most visible surface of the booth is the one that shows the owner's class.
	local podium = part({
		Name = "Podium",
		Size = Vector3.new(7, 3, 2.4),
		CFrame = standCf * CFrame.new(0, 2.1, -2.2),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(150, 150, 150),
		Parent = stand,
	})
	part({
		Name = "CounterTop",
		Size = Vector3.new(7.6, 0.3, 2.9),
		CFrame = standCf * CFrame.new(0, 3.75, -2.2),
		Material = Enum.Material.WoodPlanks,
		Color = COLORS.wood,
		Parent = stand,
	})

	-- Gold+ upgrade roof, hidden until StandService reveals it.
	part({
		Name = "Canopy",
		Size = Vector3.new(12.4, 0.5, 10.4),
		CFrame = standCf * CFrame.new(0, 10.6, 0.4),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = stand,
	})

	local signPost = part({
		Name = "SignPost",
		Size = Vector3.new(0.4, 0.4, 0.4),
		CFrame = standCf * CFrame.new(0, 12.2, -1),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = stand,
	})
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sign"
	billboard.Size = UDim2.fromScale(9, 3.8)
	billboard.StudsOffset = Vector3.new(0, 1.2, 0)
	billboard.MaxDistance = 220
	billboard.LightInfluence = 0
	billboard.Parent = signPost
	signLabel("OwnerLabel", 0, 0.4, Enum.Font.GothamBold, Color3.fromRGB(245, 245, 248), billboard).Text = "Empty Booth"
	signLabel("TitleLabel", 0.4, 0.27, Enum.Font.GothamMedium, Color3.fromRGB(180, 180, 185), billboard)
	signLabel("RaisedLabel", 0.68, 0.3, Enum.Font.GothamBold, Color3.fromRGB(255, 205, 70), billboard)

	local effectAttachment = Instance.new("Attachment")
	effectAttachment.Name = "EffectAttachment"
	effectAttachment.Position = Vector3.new(0, 1.8, 0)
	effectAttachment.Parent = podium
	local burst = Instance.new("ParticleEmitter")
	burst.Name = "DonationBurst"
	burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	burst.Color = ColorSequence.new(Color3.fromRGB(255, 221, 110))
	burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	burst.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	burst.Lifetime = NumberRange.new(0.8, 1.4)
	burst.Speed = NumberRange.new(8, 16)
	burst.SpreadAngle = Vector2.new(45, 45)
	burst.Rate = 0
	burst.Enabled = false
	burst.Parent = effectAttachment

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DonatePrompt"
	prompt.ActionText = "Donate"
	prompt.ObjectText = "Empty Booth"
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = podium

	stand.PrimaryPart = podium
	stand:SetAttribute("StandIndex", index)
	stand.Parent = parent
	CollectionService:AddTag(stand, TAGS.stand)
end

local function buildBooths(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Booths"
	folder.Parent = parent

	-- Two arcs of 15, leaving a wide southern gap (arrival from spawn) and a narrower
	-- northern gap (trail to the hill and lighthouse). Indexes alternate east/west from
	-- the south entrance outward, so the first players to join fill the booths nearest
	-- spawn - where new arrivals look first.
	local perArc = STAND_COUNT // 2
	local arcs = {
		{ from = math.rad(68), to = math.rad(-72) }, -- east arc, south -> north
		{ from = math.rad(112), to = math.rad(252) }, -- west arc, south -> north
	}
	local index = 0
	for i = 0, perArc - 1 do
		for _, arc in arcs do
			index += 1
			local angle = lerp(arc.from, arc.to, i / (perArc - 1))
			local pos = Vector3.new(math.cos(angle) * BOOTH_RADIUS, GROUND_Y, math.sin(angle) * BOOTH_RADIUS)
			local cf = CFrame.lookAt(pos, Vector3.new(0, GROUND_Y, 0))
			buildBooth(folder, index, cf)
		end
	end

	-- Lamps between booths on the plaza side, palms behind the ring as a backdrop.
	for i = 0, 35 do
		local angle = i / 36 * math.pi * 2
		local deg = math.deg(angle)
		local inGap = math.abs(deg - 90) < 22 or math.abs(deg - 270) < 16
		if not inGap then
			buildPalm(folder, Vector3.new(math.cos(angle) * 134, GROUND_Y - 0.5, math.sin(angle) * 134), i + 3)
		end
	end
end

------------------------------------------------------------------------------------
-- Arrival: spawn, welcome arch, pier, boat
------------------------------------------------------------------------------------

local function buildArrival(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Arrival"
	folder.Parent = parent

	local spawnPos = Vector3.new(0, GROUND_Y + 0.5, 150)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MainSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = CFrame.lookAt(spawnPos, Vector3.new(0, spawnPos.Y, 0))
	spawn.Material = Enum.Material.Pavement
	spawn.Color = COLORS.stoneLight
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = folder
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end

	-- Welcome arch over the harbor road where it enters the booth ring.
	local archZ = 126
	for _, side in { -1, 1 } do
		part({
			Name = "ArchPillar",
			Size = Vector3.new(3, 16, 3),
			CFrame = CFrame.new(side * 11, GROUND_Y + 8, archZ),
			Material = Enum.Material.Slate,
			Color = COLORS.stone,
			Parent = folder,
		})
		buildLamp(folder, Vector3.new(side * 15, GROUND_Y, archZ + 2))
	end
	local beam = part({
		Name = "ArchBeam",
		Size = Vector3.new(26, 3, 3.4),
		CFrame = CFrame.new(0, GROUND_Y + 15, archZ),
		Material = Enum.Material.Wood,
		Color = COLORS.woodDark,
		Parent = folder,
	})
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local surface = Instance.new("SurfaceGui")
		surface.Face = face
		surface.CanvasSize = Vector2.new(520, 60)
		surface.LightInfluence = 0.4
		surface.Parent = beam
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Text = "GRAY PLAZA  ·  WORLD 1"
		text.Font = Enum.Font.GothamBlack
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(236, 232, 222)
		text.Parent = surface
	end

	-- Pier: from the beach out into open water. Its end is a landmark.
	local pierStart, pierEnd = 214, 318
	local pierLength = pierEnd - pierStart
	part({
		Name = "PierDeck",
		Size = Vector3.new(12, 1, pierLength),
		CFrame = CFrame.new(0, 2.6, (pierStart + pierEnd) / 2),
		Material = Enum.Material.WoodPlanks,
		Color = COLORS.wood,
		Parent = folder,
	})
	for z = pierStart + 6, pierEnd, 12 do
		for _, side in { -1, 1 } do
			uprightCylinder({ Name = "Piling", Material = Enum.Material.Wood, Color = COLORS.woodDark, Parent = folder },
				Vector3.new(side * 5.6, -8, z), 24, 1.4)
			part({
				Name = "Rail",
				Size = Vector3.new(0.4, 0.4, 12),
				CFrame = CFrame.new(side * 5.8, 5.2, z - 6),
				Material = Enum.Material.Wood,
				Color = COLORS.woodDark,
				Parent = folder,
			})
		end
	end
	buildLamp(folder, Vector3.new(-5, 3.1, pierEnd - 2))
	buildLamp(folder, Vector3.new(5, 3.1, pierEnd - 2))
	addDiscovery(folder, "pier_end", "End of the Pier", Vector3.new(0, 6, pierEnd - 6), Vector3.new(12, 8, 10), 150)

	-- A rowboat tied up beside the pier.
	local boatCf = CFrame.new(11, 0.6, 290) * CFrame.Angles(0, math.rad(4), 0)
	local boat = tryAsset("Rowboat", boatCf, folder)
	if not boat then
		part({ Name = "Hull", Size = Vector3.new(5, 2, 14), CFrame = boatCf, Material = Enum.Material.WoodPlanks, Color = COLORS.wood, Parent = folder })
	end
	-- Gentle bob so the harbor feels alive.
	local bobTarget = boat or folder:FindFirstChild("Hull")
	if bobTarget then
		task.spawn(function()
			local t0 = os.clock()
			while bobTarget.Parent do
				local t = os.clock() - t0
				local cf = boatCf * CFrame.new(0, math.sin(t * 1.3) * 0.25, 0) * CFrame.Angles(math.sin(t * 0.9) * 0.03, 0, math.sin(t * 1.1) * 0.04)
				if bobTarget:IsA("Model") then
					bobTarget:PivotTo(cf)
				elseif bobTarget:IsA("BasePart") then
					bobTarget.CFrame = cf
				end
				task.wait(0.05)
			end
		end)
	end
end

------------------------------------------------------------------------------------
-- Portal and prestige showcase (moved from the old plaza, same tags/contracts)
------------------------------------------------------------------------------------

local function buildPortal(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Teleporter"
	folder.Parent = parent

	local baseZ = -78
	local postSpacing = 9
	local y = GROUND_Y

	part({
		Name = "Dais",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 26, 26),
		CFrame = CFrame.new(0, y + 0.6, baseZ) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Slate,
		Color = COLORS.stoneDark,
		Parent = folder,
	})
	for _, side in { -1, 1 } do
		part({
			Name = "Post",
			Size = Vector3.new(3, 18, 3),
			CFrame = CFrame.new(side * postSpacing, y + 10, baseZ),
			Material = Enum.Material.Slate,
			Color = COLORS.stone,
			Parent = folder,
		})
	end
	part({
		Name = "Lintel",
		Size = Vector3.new(postSpacing * 2 + 4, 2.4, 3.4),
		CFrame = CFrame.new(0, y + 20, baseZ),
		Material = Enum.Material.Slate,
		Color = COLORS.stone,
		Parent = folder,
	})

	local disc = part({
		Name = "PortalDisc",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 15, 15),
		CFrame = CFrame.new(0, y + 10, baseZ) * CFrame.Angles(0, math.rad(90), 0),
		-- Glass, not Neon: Neon plus bloom washes the disc out to a flat white blob.
		Material = Enum.Material.Glass,
		Color = Color3.fromRGB(120, 140, 220),
		Transparency = 0.35,
		CanCollide = false,
		CanQuery = false,
		Parent = folder,
	})
	local swirl = Instance.new("ParticleEmitter")
	swirl.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	swirl.Color = ColorSequence.new(Color3.fromRGB(200, 215, 255))
	swirl.Size = NumberSequence.new(0.5)
	swirl.Lifetime = NumberRange.new(1, 2)
	swirl.Speed = NumberRange.new(1, 3)
	swirl.Rate = 25
	swirl.Parent = disc
	local spin = math.rad(30)
	task.spawn(function()
		while disc.Parent do
			local dt = RunService.Heartbeat:Wait()
			disc.CFrame = disc.CFrame * CFrame.Angles(spin * dt, 0, 0)
		end
	end)

	local label = Instance.new("BillboardGui")
	label.Size = UDim2.fromScale(20, 4)
	label.StudsOffset = Vector3.new(0, 13, 0)
	label.MaxDistance = 220
	label.LightInfluence = 0
	label.Parent = disc
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "WORLD PORTAL\nHigher ranks, richer worlds"
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(220, 228, 255)
	text.TextStrokeTransparency = 0.4
	text.Parent = label

	local pad = part({
		Name = "TeleporterPad",
		Size = Vector3.new(postSpacing * 2, 0.4, 6),
		CFrame = CFrame.new(0, y + 1.4, baseZ + 5),
		Material = Enum.Material.Slate,
		Color = COLORS.stoneLight,
		Parent = folder,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TeleporterPrompt"
	prompt.ActionText = "Explore Worlds"
	prompt.ObjectText = "World Portal"
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad
	CollectionService:AddTag(prompt, TAGS.teleporterPrompt)
end

local function buildPrestigePedestal(parent: Instance, index: number, total: number)
	local spread = 56
	-- Order across the row: #1 in the middle, then alternating outward.
	local order = { 3, 2, 4, 1, 5 }
	local x = -spread / 2 + (order[index] - 1) * (spread / (total - 1))
	local z = 44
	local height = index == 1 and 6 or (index <= 3 and 4.5 or 3.5)
	local y = GROUND_Y + 0.6

	local pedestal = Instance.new("Model")
	pedestal.Name = `PrestigePedestal_{index}`

	local riser = part({
		Name = "Riser",
		Size = Vector3.new(7, height, 7),
		CFrame = CFrame.new(x, y + height / 2, z),
		Material = Enum.Material.Slate,
		Color = COLORS.stoneLight,
		Parent = pedestal,
	})
	part({
		Name = "RankPlate",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 6, 6),
		CFrame = CFrame.new(x, y + height + 0.15, z) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(150, 150, 150),
		CanCollide = false,
		CanQuery = false,
		Parent = pedestal,
	})
	local signPost = part({
		Name = "SignPost",
		Size = Vector3.new(0.4, 0.4, 0.4),
		CFrame = CFrame.new(x, y + height + 6, z),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = pedestal,
	})
	local sign = Instance.new("BillboardGui")
	sign.Name = "Sign"
	sign.Size = UDim2.fromScale(7, 3.6)
	sign.MaxDistance = 160
	sign.LightInfluence = 0
	sign.Parent = signPost
	signLabel("RankLabel", 0, 0.2, Enum.Font.GothamBold, Color3.fromRGB(230, 190, 60), sign).Text = `#{index} DONOR`
	signLabel("NameLabel", 0.2, 0.3, Enum.Font.GothamBold, Color3.fromRGB(240, 240, 245), sign).Text = "Unclaimed"
	signLabel("TitleLabel", 0.5, 0.22, Enum.Font.Gotham, Color3.fromRGB(200, 200, 210), sign)
	signLabel("AmountLabel", 0.73, 0.22, Enum.Font.Gotham, Color3.fromRGB(150, 220, 160), sign)

	pedestal.PrimaryPart = riser
	pedestal.Parent = parent
	CollectionService:AddTag(pedestal, TAGS.prestige)
	pedestal:SetAttribute("Rank", index)
end

local function buildShowcase(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "PrestigeShowcase"
	folder.Parent = parent
	for i = 1, 5 do
		buildPrestigePedestal(folder, i, 5)
	end
end

------------------------------------------------------------------------------------
-- Landmarks: lighthouse, summit, shipwreck, tide pools, cove, palm grove
------------------------------------------------------------------------------------

local function buildLighthouse(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Lighthouse"
	folder.Parent = parent

	local baseX, baseZ = 172, -178
	local groundY = surfaceHeight(baseX, baseZ) - 1
	local towerHeight = 46
	local pivot = CFrame.new(baseX, groundY, baseZ)

	if not tryAsset("Lighthouse", pivot, folder) then
		local bands = 6
		for i = 0, bands - 1 do
			local t = i / bands
			local diameter = lerp(14, 9, t)
			uprightCylinder({
				Name = "Band",
				Material = Enum.Material.Concrete,
				Color = i % 2 == 0 and Color3.fromRGB(236, 232, 224) or Color3.fromRGB(150, 70, 62),
				Parent = folder,
			}, Vector3.new(baseX, groundY + (i + 0.5) * towerHeight / bands, baseZ), towerHeight / bands + 0.05, diameter)
		end
		local lanternY = groundY + towerHeight
		uprightCylinder({ Name = "Gallery", Material = Enum.Material.Metal, Color = COLORS.iron, Parent = folder },
			Vector3.new(baseX, lanternY + 0.4, baseZ), 0.8, 15)
		uprightCylinder({ Name = "LanternGlass", Material = Enum.Material.Glass, Transparency = 0.4, Color = Color3.fromRGB(255, 240, 200), CanCollide = false, Parent = folder },
			Vector3.new(baseX, lanternY + 3.4, baseZ), 5.4, 7)
		part({ Name = "Roof", Shape = Enum.PartType.Ball, Size = Vector3.new(8, 5, 8), CFrame = CFrame.new(baseX, lanternY + 6.4, baseZ), Material = Enum.Material.Metal, Color = COLORS.iron, Parent = folder })
	end

	-- Gallery railing posts + a ladder up the landward side. A Truss is the one
	-- climbable primitive Roblox characters handle reliably.
	local topY = groundY + towerHeight
	part({
		Name = "GalleryFloor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 16, 16),
		CFrame = CFrame.new(baseX, topY + 0.4, baseZ) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Metal,
		Color = COLORS.iron,
		Parent = folder,
	})
	local ladderDir = Vector3.new(-baseX, 0, -baseZ).Unit -- face the island center
	local ladderAngle = math.atan2(ladderDir.Z, ladderDir.X)
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		-- Leave a gap in the railing where the ladder arrives.
		local diff = math.abs(math.atan2(math.sin(a - ladderAngle), math.cos(a - ladderAngle)))
		if diff < math.rad(30) then
			continue
		end
		part({
			Name = "Rail",
			Size = Vector3.new(0.3, 3, 0.3),
			CFrame = CFrame.new(baseX + math.cos(a) * 7.6, topY + 2.3, baseZ + math.sin(a) * 7.6),
			Material = Enum.Material.Metal,
			Color = COLORS.iron,
			Parent = folder,
		})
	end
	-- Outside the gallery floor's edge (radius 8), and tall enough to step off onto it.
	local ladderHeight = towerHeight + 4
	local truss = Instance.new("TrussPart")
	truss.Name = "Ladder"
	truss.Anchored = true
	truss.Size = Vector3.new(2, ladderHeight, 2)
	truss.CFrame = CFrame.lookAt(
		Vector3.new(baseX, groundY + ladderHeight / 2, baseZ) + ladderDir * 9,
		Vector3.new(baseX, groundY + ladderHeight / 2, baseZ)
	)
	truss.Material = Enum.Material.Metal
	truss.Color = COLORS.iron
	truss.Parent = folder

	-- The beacon: a slow rotating beam, visible from the whole island.
	local beacon = part({
		Name = "Beacon",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(baseX, topY + 3.4, baseZ),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = folder,
	})
	local spot = Instance.new("SpotLight")
	spot.Angle = 24
	spot.Range = 60
	spot.Brightness = 4
	spot.Color = Color3.fromRGB(255, 236, 190)
	spot.Face = Enum.NormalId.Front
	spot.Parent = beacon
	local glow = Instance.new("PointLight")
	glow.Range = 16
	glow.Brightness = 2
	glow.Color = Color3.fromRGB(255, 220, 160)
	glow.Parent = beacon
	-- Per-frame spin: a tween to a full turn is a no-op (same orientation).
	task.spawn(function()
		while beacon.Parent do
			local dt = RunService.Heartbeat:Wait()
			beacon.CFrame = beacon.CFrame * CFrame.Angles(0, math.rad(45) * dt, 0)
		end
	end)

	addDiscovery(folder, "lighthouse", "The Old Lighthouse", Vector3.new(baseX, topY + 3, baseZ), Vector3.new(16, 6, 16), 300)
end

local function buildLandmarks(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Landmarks"
	folder.Parent = parent

	buildLighthouse(folder)

	-- Summit of the north-west hill: a weathered cairn and a bench with the view.
	local summitX, summitZ = -170, -150
	local summitY = surfaceHeight(summitX, summitZ)
	buildRock(folder, Vector3.new(summitX, summitY + 2, summitZ), 7, 4)
	buildRock(folder, Vector3.new(summitX + 2, summitY + 6, summitZ + 1), 4, 7)
	buildBench(folder, CFrame.lookAt(Vector3.new(summitX + 8, summitY, summitZ + 8), Vector3.new(0, summitY, 0)) * CFrame.Angles(0, math.pi, 0))
	addDiscovery(folder, "summit", "Windward Summit", Vector3.new(summitX, summitY + 4, summitZ), Vector3.new(24, 10, 24), 200)

	-- Shipwreck on the south-west beach.
	local wreckAngle = math.rad(140)
	local wreckR = coastRadius(math.cos(wreckAngle), math.sin(wreckAngle)) - 8
	local wreckPos = Vector3.new(math.cos(wreckAngle) * wreckR, 0.5, math.sin(wreckAngle) * wreckR)
	local wreckCf = CFrame.new(wreckPos) * CFrame.Angles(0, math.rad(30), math.rad(18))
	if not tryAsset("Shipwreck", wreckCf, folder) then
		part({ Name = "WreckHull", Size = Vector3.new(9, 5, 28), CFrame = wreckCf, Material = Enum.Material.WoodPlanks, Color = COLORS.woodDark, Parent = folder })
		part({ Name = "WreckMast", Size = Vector3.new(1, 18, 1), CFrame = wreckCf * CFrame.new(0, 8, -3) * CFrame.Angles(math.rad(20), 0, 0), Material = Enum.Material.Wood, Color = COLORS.woodDark, Parent = folder })
	end
	addDiscovery(folder, "shipwreck", "The Driftwood Wreck", wreckPos + Vector3.new(0, 3, 0), Vector3.new(24, 10, 34), 200)

	-- Tide pools: a cluster of rocks in the east shallows.
	local poolAngle = math.rad(-25)
	local poolR = coastRadius(math.cos(poolAngle), math.sin(poolAngle)) + 4
	local poolCenter = Vector3.new(math.cos(poolAngle) * poolR, 0, math.sin(poolAngle) * poolR)
	for i = 1, 7 do
		local a = i * 0.9
		buildRock(folder, poolCenter + Vector3.new(math.cos(a) * (6 + i), 0.5, math.sin(a) * (6 + i)), 3 + (i % 3) * 2, i)
	end
	addDiscovery(folder, "tide_pools", "Tide Pools", poolCenter + Vector3.new(0, 2, 0), Vector3.new(26, 8, 26), 150)

	-- Hidden cove on the south-east shore: palms and a half-buried chest.
	local coveAngle = math.rad(52)
	local coveR = coastRadius(math.cos(coveAngle), math.sin(coveAngle)) - 18
	local coveCenter = Vector3.new(math.cos(coveAngle) * coveR, 0, math.sin(coveAngle) * coveR)
	local coveY = surfaceHeight(coveCenter.X, coveCenter.Z)
	for i = 1, 3 do
		buildPalm(folder, Vector3.new(coveCenter.X + i * 6 - 12, surfaceHeight(coveCenter.X + i * 6 - 12, coveCenter.Z + 6) - 0.5, coveCenter.Z + 6), i * 7)
	end
	local chestCf = CFrame.new(coveCenter.X, coveY + 0.6, coveCenter.Z) * CFrame.Angles(0, 0.4, math.rad(-8))
	if not tryAsset("Chest", chestCf, folder) then
		part({ Name = "Chest", Size = Vector3.new(4, 2.4, 2.6), CFrame = chestCf, Material = Enum.Material.WoodPlanks, Color = COLORS.wood, Parent = folder })
	end
	addDiscovery(folder, "hidden_cove", "Hidden Cove", coveCenter + Vector3.new(0, coveY + 3, 0), Vector3.new(22, 10, 22), 200)

	-- Palm grove in the west, between the booth ring and the beach.
	local groveCenter = Vector3.new(-180, 0, 110)
	for i = 1, 9 do
		local a = i * 2.4
		local px, pz = groveCenter.X + math.cos(a) * (6 + i * 2), groveCenter.Z + math.sin(a) * (6 + i * 2)
		buildPalm(folder, Vector3.new(px, surfaceHeight(px, pz) - 0.5, pz), i + 11)
	end
	addDiscovery(folder, "palm_grove", "Palm Grove", Vector3.new(groveCenter.X, surfaceHeight(groveCenter.X, groveCenter.Z) + 4, groveCenter.Z), Vector3.new(20, 10, 20), 150)

	-- Scattered shoreline rocks so the coast isn't a clean ring.
	for i = 1, 26 do
		local a = i / 26 * math.pi * 2 + 0.13
		local r = coastRadius(math.cos(a), math.sin(a)) + (i % 3) * 6 - 4
		buildRock(folder, Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), 4 + (i % 4) * 2, i + 20)
	end
end

------------------------------------------------------------------------------------
-- Obbies: three courses out to sea. Falling means a swim back, not a reset.
------------------------------------------------------------------------------------

local function platform(parent: Instance, cf: CFrame, size: Vector3, material: Enum.Material, color: Color3): Part
	local p = part({
		Name = "Platform",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(size.Y, size.X, size.X),
		CFrame = cf * CFrame.Angles(0, 0, math.rad(90)),
		Material = material,
		Color = color,
		Parent = parent,
	})
	return p
end

local function finishPad(parent: Instance, position: Vector3, courseId: string, xp: number, displayName: string)
	local pad = part({
		Name = "FinishPad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 10, 10),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(110, 210, 140),
		Parent = parent,
	})
	pad:SetAttribute("XpReward", xp)
	pad:SetAttribute("CourseId", courseId)
	CollectionService:AddTag(pad, TAGS.obbyFinish)

	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromScale(10, 2.4)
	board.StudsOffset = Vector3.new(0, 5, 0)
	board.MaxDistance = 180
	board.LightInfluence = 0
	board.Parent = pad
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = `{displayName}\n+{xp} XP`
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(170, 240, 190)
	text.TextStrokeTransparency = 0.4
	text.Parent = board
end

local function startSign(parent: Instance, position: Vector3, text: string)
	local post = part({
		Name = "CourseSign",
		Size = Vector3.new(0.6, 6, 0.6),
		CFrame = CFrame.new(position + Vector3.new(0, 3, 0)),
		Material = Enum.Material.Wood,
		Color = COLORS.woodDark,
		Parent = parent,
	})
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromScale(9, 2.4)
	board.StudsOffset = Vector3.new(0, 4.5, 0)
	board.MaxDistance = 120
	board.LightInfluence = 0
	board.Parent = post
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(240, 236, 226)
	label.TextStrokeTransparency = 0.4
	label.Parent = board
end

-- Turtle Islet (east): stepping stones across the water. Easy, quick, replayable.
local function buildTurtleIslet(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "turtle_islet"
	folder.Parent = parent
	local startX, endX, z = 236, 352, 32
	startSign(folder, Vector3.new(startX - 6, surfaceHeight(startX - 6, z), z + 6), "Turtle Islet\nEasy · stepping stones")
	local stones = 11
	for i = 1, stones do
		local t = i / (stones + 1)
		local x = lerp(startX, endX, t)
		local wobble = math.sin(i * 1.7) * 6
		local y = 2 + math.abs(math.sin(i * 0.9)) * 3
		platform(folder, CFrame.new(x, y, z + wobble), Vector3.new(6, 1.2, 6), Enum.Material.Slate, COLORS.stone)
	end
	finishPad(folder, Vector3.new(392, surfaceHeight(392, 30) + 0.6, 30), "turtle_islet", 80, "Turtle Islet")
end

-- Spire Islet (west): rising rocks to the top of a sea spire. Medium.
local function buildSpireIslet(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "spire_islet"
	folder.Parent = parent
	local startPos = Vector3.new(-236, 0, 64)
	startSign(folder, Vector3.new(startPos.X + 6, surfaceHeight(startPos.X + 6, startPos.Z), startPos.Z + 6), "Spire Islet\nMedium · climb the spire")
	local spireX, spireZ = -402, 70
	local spireTop = 34
	-- Spire column (rock) on the islet.
	part({
		Name = "Spire",
		Size = Vector3.new(12, spireTop, 12),
		CFrame = CFrame.new(spireX, spireTop / 2, spireZ) * CFrame.Angles(0, 0.4, 0),
		Material = Enum.Material.Slate,
		Color = COLORS.rock,
		Parent = folder,
	})
	local steps = 13
	for i = 1, steps do
		local t = i / steps
		local x = lerp(startPos.X - 8, spireX + 12, t)
		local zOff = math.sin(i * 1.3) * 9
		local y = lerp(3, spireTop - 2, t ^ 1.3)
		local p = platform(folder, CFrame.new(x, y, spireZ + zOff), Vector3.new(5, 1.2, 5), Enum.Material.Slate, COLORS.stone)
		if i == 7 then
			p.Color = Color3.fromRGB(110, 170, 200)
			CollectionService:AddTag(p, TAGS.checkpoint)
		end
	end
	finishPad(folder, Vector3.new(spireX, spireTop + 0.5, spireZ), "spire_islet", 130, "Spire Islet")
end

-- Sky Rocks (north-west): floating rocks from the summit out to the sea stack. Hard.
local function buildSkyRocks(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "sky_rocks"
	folder.Parent = parent
	local startX, startZ = -186, -176
	local startY = surfaceHeight(startX, startZ)
	startSign(folder, Vector3.new(startX, startY, startZ), "Sky Rocks\nHard · floating rocks")
	local stackX, stackZ = -262, -352
	local stackTop = 52
	local steps = 15
	local movers = { [6] = true, [11] = true }
	local checkpoints = { [5] = true, [10] = true }
	for i = 1, steps do
		local t = i / (steps + 1)
		local x = lerp(startX, stackX, t) + math.sin(i * 2.1) * 7
		local z = lerp(startZ, stackZ, t)
		local y = lerp(startY + 3, stackTop - 1, t) + math.sin(i * 1.4) * 2.5
		local cf = CFrame.new(x, y, z)
		local p = platform(folder, cf, Vector3.new(4.5, 1.4, 4.5), Enum.Material.Slate, COLORS.rock)
		if movers[i] then
			p.Color = Color3.fromRGB(170, 120, 100)
			TweenService:Create(p, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
				CFrame = p.CFrame + Vector3.new(10, 0, 0),
			}):Play()
		elseif checkpoints[i] then
			p.Color = Color3.fromRGB(110, 170, 200)
			p.Size = Vector3.new(1.4, 7, 7)
			CollectionService:AddTag(p, TAGS.checkpoint)
		end
	end
	finishPad(folder, Vector3.new(stackX, surfaceHeight(stackX, stackZ) + 0.8, stackZ), "sky_rocks", 300, "Sky Rocks")
	addDiscovery(folder, "sea_stack", "The Sea Stack", Vector3.new(stackX, stackTop + 4, stackZ), Vector3.new(18, 8, 18), 250)
end

------------------------------------------------------------------------------------

function IslandBuilder.build(root: Instance)
	local found = ServerStorage:FindFirstChild("LobbyAssets")
	assetFolder = if found and found:IsA("Folder") then found else nil

	local started = os.clock()
	setupLighting()
	buildTerrain()
	local terrainSeconds = os.clock() - started

	buildPlaza(root)
	buildBooths(root)
	buildArrival(root)
	buildPortal(root)
	buildShowcase(root)
	buildLandmarks(root)

	local obbies = Instance.new("Folder")
	obbies.Name = "Obbies"
	obbies.Parent = root
	buildTurtleIslet(obbies)
	buildSpireIslet(obbies)
	buildSkyRocks(obbies)

	print(string.format(
		"[IslandBuilder] World 1 built in %.2fs (terrain %.2fs), Blender assets: %s",
		os.clock() - started,
		terrainSeconds,
		assetFolder and "yes" or "no (primitive fallbacks)"
	))
end

-- Exposed for tooling (edit-mode previews) and for anything that needs ground height.
IslandBuilder.surfaceHeight = surfaceHeight

return IslandBuilder
