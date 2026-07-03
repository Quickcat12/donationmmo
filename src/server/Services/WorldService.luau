--!strict
-- Validates and executes teleports between the game's worlds (each world is a separate
-- Place within this multi-place experience). The client can read WorldConfig directly
-- (it's shared) to render a world-select menu, but the actual travel request must be
-- re-validated here since the client can't be trusted to enforce rank gating.

local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldConfig = require(Shared.Config.WorldConfig)
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)

local XPService = require(script.Parent.XPService)
local QuestService = require(script.Parent.QuestService)

local WorldService = {}

local function onRequestWorldTravel(player: Player, worldId: unknown)
	if type(worldId) ~= "string" then
		return
	end

	local world = WorldConfig.getWorldById(worldId)
	local deniedEvent = Net.get(RemoteNames.Events.WorldTravelDenied)

	if not world then
		deniedEvent:FireClient(player, "That world doesn't exist.")
		return
	end

	if world.placeId == 0 then
		deniedEvent:FireClient(player, `{world.displayName} hasn't been built yet. Check back soon!`)
		return
	end

	local level = XPService.getLevel(player) or 1
	if not WorldConfig.canEnter(world, level) then
		deniedEvent:FireClient(
			player,
			`You need to reach level {world.requiredLevel} ({world.requiredRank}) to enter {world.displayName}.`
		)
		return
	end

	QuestService.reportProgress(player, "world_travel")

	local ok, err = pcall(function()
		TeleportService:TeleportAsync(world.placeId, { player })
	end)

	if not ok then
		warn(`[WorldService] Teleport failed for {player.Name} to {world.displayName}: {err}`)
		deniedEvent:FireClient(player, "Teleport failed, please try again.")
	end
end

function WorldService.start()
	Net.get(RemoteNames.Events.RequestWorldTravel).OnServerEvent:Connect(onRequestWorldTravel)
end

return WorldService
