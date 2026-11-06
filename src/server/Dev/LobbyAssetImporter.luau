--!strict
-- Studio-only dev tool (never required at runtime). After importing
-- art/blender/out/lobby_props.glb with File > Import 3D, run in the command bar:
--
--     require(game.ServerScriptService.Server.Dev.LobbyAssetImporter:Clone())()
--
-- It turns the imported scene into clean templates in ServerStorage.LobbyAssets, which
-- IslandBuilder clones at runtime (falling back to primitives for anything missing).
-- Meshes arrive as plain geometry; the look comes from the ROLE table below, so art
-- direction (materials, colors) can be tuned here without re-exporting from Blender.
--
-- The Studio importer maps Blender (x, y, z) to Roblox (-x, z, y) at 1 stud per unit,
-- pivoting the scene at the Blender origin. ASSET_ORDER and GRID must match
-- art/blender/lobby_props.py.

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local GRID = 45
local ASSET_ORDER = {
	"PalmA",
	"PalmB",
	"RockA",
	"RockB",
	"RockC",
	"Fountain",
	"Lighthouse",
	"Rowboat",
	"Shipwreck",
	"BoothShell",
	"LampPost",
	"Bench",
	"Chest",
}

type Look = {
	material: Enum.Material,
	color: Color3,
	transparency: number?,
	doubleSided: boolean?,
	shadow: boolean?,
}

-- Gray-class palette: weathered wood, pale stone, off-white canvas, dark iron.
local ROLE: { [string]: Look } = {
	Trunk = { material = Enum.Material.Wood, color = Color3.fromRGB(118, 92, 64) },
	Fronds = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(84, 128, 60), doubleSided = true },
	Nuts = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(92, 64, 40) },
	Rock = { material = Enum.Material.Slate, color = Color3.fromRGB(120, 116, 108) },
	Stone = { material = Enum.Material.Slate, color = Color3.fromRGB(198, 195, 188) },
	Trim = { material = Enum.Material.Slate, color = Color3.fromRGB(142, 140, 134) },
	Water = { material = Enum.Material.Glass, color = Color3.fromRGB(78, 168, 190), transparency = 0.3, shadow = false },
	White = { material = Enum.Material.Concrete, color = Color3.fromRGB(236, 232, 224) },
	Red = { material = Enum.Material.Concrete, color = Color3.fromRGB(150, 70, 62) },
	Metal = { material = Enum.Material.Metal, color = Color3.fromRGB(52, 52, 56) },
	Glass = { material = Enum.Material.Glass, color = Color3.fromRGB(255, 238, 196), transparency = 0.35, shadow = false },
	Glow = { material = Enum.Material.Neon, color = Color3.fromRGB(255, 206, 140), shadow = false },
	Hull = { material = Enum.Material.WoodPlanks, color = Color3.fromRGB(124, 94, 66) },
	Wood = { material = Enum.Material.Wood, color = Color3.fromRGB(122, 92, 64) },
	WoodDark = { material = Enum.Material.WoodPlanks, color = Color3.fromRGB(88, 66, 48) },
	Canvas = { material = Enum.Material.Fabric, color = Color3.fromRGB(228, 224, 214), doubleSided = true },
	Stripe = { material = Enum.Material.Fabric, color = Color3.fromRGB(126, 132, 142), doubleSided = true },
	Iron = { material = Enum.Material.Metal, color = Color3.fromRGB(50, 50, 54) },
}

-- Which parts players can bump into, and how precisely. Anything unlisted is
-- decoration only (no collision), which keeps thin frames from becoming invisible
-- convex-hull walls - e.g. a booth's four posts would otherwise hull into a solid box.
local COLLISION: { [string]: { [string]: Enum.CollisionFidelity } } = {
	PalmA = { Trunk = Enum.CollisionFidelity.Hull },
	PalmB = { Trunk = Enum.CollisionFidelity.Hull },
	RockA = { Rock = Enum.CollisionFidelity.Hull },
	RockB = { Rock = Enum.CollisionFidelity.Hull },
	RockC = { Rock = Enum.CollisionFidelity.Hull },
	Fountain = { Stone = Enum.CollisionFidelity.PreciseConvexDecomposition, Trim = Enum.CollisionFidelity.PreciseConvexDecomposition },
	Lighthouse = {
		White = Enum.CollisionFidelity.PreciseConvexDecomposition,
		Red = Enum.CollisionFidelity.PreciseConvexDecomposition,
		Stone = Enum.CollisionFidelity.Hull,
	},
	Shipwreck = { Wood = Enum.CollisionFidelity.PreciseConvexDecomposition, WoodDark = Enum.CollisionFidelity.PreciseConvexDecomposition },
	BoothShell = { WoodDark = Enum.CollisionFidelity.Box },
	Bench = { Wood = Enum.CollisionFidelity.Box },
	Chest = { Wood = Enum.CollisionFidelity.Box },
	LampPost = { Iron = Enum.CollisionFidelity.Hull },
}

local function toRoblox(blender: Vector3): Vector3
	return Vector3.new(-blender.X, blender.Z, blender.Y)
end

-- The importer names root-level objects "<Name>_Node" and may suffix duplicates ".001".
local function clean(name: string): string
	return (string.gsub(string.gsub(name, "_Node$", ""), "%.%d+$", ""))
end

local function findScene(): Model?
	for _, child in Workspace:GetChildren() do
		if child:IsA("Model") then
			for _, node in child:GetChildren() do
				if table.find(ASSET_ORDER, clean(node.Name)) then
					return child
				end
			end
		end
	end
	return nil
end

local function configure(part: MeshPart, asset: string, role: string)
	part.Name = role
	part.Anchored = true
	part.CanTouch = false
	local look = ROLE[role]
	if look then
		part.Material = look.material
		part.Color = look.color
		part.Transparency = look.transparency or 0
		part.DoubleSided = look.doubleSided == true
		part.CastShadow = look.shadow ~= false
		-- Imported meshes may carry a baked texture; our look is material + color.
		part.TextureID = ""
	end
	local fidelity = COLLISION[asset] and COLLISION[asset][role]
	part.CanCollide = fidelity ~= nil
	part.CanQuery = fidelity ~= nil
	if fidelity then
		part.CollisionFidelity = fidelity
	end
end

return function(): string
	local scene = findScene()
	if not scene then
		return "LobbyAssetImporter: no imported lobby_props scene found in Workspace"
	end
	local origin = scene.WorldPivot.Position

	local folder = ServerStorage:FindFirstChild("LobbyAssets")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "LobbyAssets"
		folder.Parent = ServerStorage
	end

	local assets, parts = 0, 0
	for _, node in scene:GetChildren() do
		local assetName = clean(node.Name)
		local index = table.find(ASSET_ORDER, assetName)
		if not index then
			continue
		end
		local model = Instance.new("Model")
		model.Name = assetName
		local meshParts: { MeshPart } = {}
		if node:IsA("MeshPart") then
			table.insert(meshParts, node)
		end
		for _, descendant in node:GetDescendants() do
			if descendant:IsA("MeshPart") then
				table.insert(meshParts, descendant)
			end
		end
		for _, part in meshParts do
			local holder = part.Parent
			local raw = if holder and holder ~= node and holder ~= scene and holder:IsA("Model") then holder.Name else part.Name
			local role = clean(raw)
			role = string.gsub(role, "^" .. assetName .. "_", "")
			configure(part, assetName, role)
			part.Parent = model
			parts += 1
		end
		local previous = folder:FindFirstChild(assetName)
		if previous then
			previous:Destroy()
		end
		model.WorldPivot = CFrame.new(origin + toRoblox(Vector3.new((index - 1) * GRID, 0, 0)))
		model:PivotTo(CFrame.new((index - 1) * 60, -400, 0)) -- out of the way in storage
		model.Parent = folder
		assets += 1
	end

	scene:Destroy()
	local message = `LobbyAssetImporter: {assets} assets, {parts} mesh parts -> ServerStorage.LobbyAssets`
	print(message)
	return message
end
