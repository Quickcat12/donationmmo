--!strict
-- Validates and executes teleports between the game's worlds (each world is a separate
-- Place within this multi-place experience). The client can read WorldConfig directly
-- (it's shared) to render a world-select menu, but the actual travel request must be
-- re-validated here since the client can't be trusted to enforce rank gating.

local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldConfig = require(Shared.Config.WorldConfig)
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)

local XPService = require(script.Parent.XPService)
local PlayerDataService = require(script.Parent.PlayerDataService)
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

	if world.id == WorldConfig.getCurrentWorld().id then
		deniedEvent:FireClient(player, `You're already in {world.displayName}.`)
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

-- Higher worlds are only worth reaching because everyone in them earned it. A player
-- can't normally land here under-level (travel is gated above), but a stale link,
-- a friend-join or a future rank change could put them here, so every non-start world
-- double-checks on arrival and sends them home with an explanation.
local function enforceGate(player: Player)
	local world = WorldConfig.getCurrentWorld()
	local home = WorldConfig.Worlds[1]
	-- Studio previews (Workspace "PreviewWorld") would otherwise bounce the tester
	-- straight into the live published place.
	if world.order == 1 or home.placeId == 0 or RunService:IsStudio() then
		return
	end
	local level = XPService.getLevel(player) or 1
	if WorldConfig.canEnter(world, level) then
		return
	end
	Net.get(RemoteNames.Events.WorldTravelDenied):FireClient(
		player,
		`{world.displayName} needs level {world.requiredLevel}. Sending you back to {home.displayName}...`
	)
	task.wait(3)
	pcall(function()
		TeleportService:TeleportAsync(home.placeId, { player })
	end)
end

function WorldService.start()
	Net.get(RemoteNames.Events.RequestWorldTravel).OnServerEvent:Connect(onRequestWorldTravel)
	PlayerDataService.DataLoaded:Connect(function(player: Player)
		task.spawn(enforceGate, player)
	end)
end

return WorldService
