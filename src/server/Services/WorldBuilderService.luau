--!strict
-- Builds this server's world at startup. Workspace isn't Rojo-managed, so the whole map
-- is generated from code and the repo stays the single source of truth.
--
-- Every world shares one island layout (IslandBuilder) dressed in its social class's
-- visual language (WorldStyles): the layout is what players learn once, the styling is
-- what tells them they've moved up.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage").Shared
local WorldConfig = require(Shared.Config.WorldConfig)

local IslandBuilder = require(script.Parent.Parent.World.IslandBuilder)
local WorldStyles = require(script.Parent.Parent.World.WorldStyles)

local WorldBuilderService = {}
WorldBuilderService.WorldY = IslandBuilder.GroundY
-- FallenPartsDestroyHeight can't be written by game scripts (plugin capability only);
-- it's set to this value in default.project.json.
WorldBuilderService.KillY = IslandBuilder.KillY

function WorldBuilderService.build()
	local existing = Workspace:FindFirstChild("GeneratedWorld")
	if existing then
		existing:Destroy()
	end

	-- The place template's baseplate would poke out of the sea, and its SpawnLocation sits
	-- inside the fountain (Roblox picks randomly between spawns). The island has its own.
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	for _, child in Workspace:GetChildren() do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end

	local world = WorldConfig.getCurrentWorld()
	local root = Instance.new("Folder")
	root.Name = "GeneratedWorld"
	root.Parent = Workspace
	IslandBuilder.build(root, WorldStyles.get(world.id), world)
end

return WorldBuilderService
