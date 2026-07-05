--!strict
-- Tracks a rough live player count per world for the world-select UI's "Population"
-- stat. Each world's server (once real Place IDs exist - see WorldConfig.luau)
-- periodically writes its own player count to a DataStore keyed by world id, and
-- periodically reads every world's entry back out to broadcast a snapshot to its own
-- players. An entry older than STALE_SECONDS is treated as 0 - a server that crashed
-- without ever reporting "0 players" shouldn't linger forever as a phantom population.
--
-- Until real per-world Places exist (all placeId placeholders are still 0 - see
-- WorldConfig.luau), every running server resolves to the same "current world" (the
-- first one), so only that entry will ever be non-zero during testing. That's expected,
-- not a bug - this is designed to scale correctly once each world is a separate Place.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldConfig = require(Shared.Config.WorldConfig)
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)

local UPDATE_INTERVAL_SECONDS = 30
local STALE_SECONDS = 120

local WorldPopulationService = {}

local store = DataStoreService:GetDataStore("WorldPopulation_v1")

-- Resolves which world this server instance represents, the same pattern XPService
-- uses for currentWorldMultiplier - falls back to the first/base world when no real
-- Place ID matches yet (local testing, or before WorldConfig is filled in).
local currentWorldId = WorldConfig.Worlds[1].id
do
	for _, world in WorldConfig.Worlds do
		if world.placeId ~= 0 and world.placeId == game.PlaceId then
			currentWorldId = world.id
			break
		end
	end
end

local function publishOwnCount()
	pcall(function()
		store:SetAsync(currentWorldId, {
			count = #Players:GetPlayers(),
			updatedAt = os.time(),
		})
	end)
end

local function broadcastSnapshot()
	local snapshot: { [string]: number } = {}

	for _, world in WorldConfig.Worlds do
		if world.id == currentWorldId then
			-- No DataStore round trip needed for our own world - we already know the
			-- live count.
			snapshot[world.id] = #Players:GetPlayers()
			continue
		end

		local ok, entry = pcall(function()
			return store:GetAsync(world.id)
		end)

		if ok and type(entry) == "table" then
			local age = os.time() - ((entry :: any).updatedAt or 0)
			snapshot[world.id] = (age <= STALE_SECONDS) and (entry :: any).count or 0
		else
			snapshot[world.id] = 0
		end
	end

	Net.get(RemoteNames.Events.WorldPopulationUpdated):FireAllClients(snapshot)
end

function WorldPopulationService.start()
	task.spawn(function()
		while true do
			publishOwnCount()
			broadcastSnapshot()
			task.wait(UPDATE_INTERVAL_SECONDS)
		end
	end)
end

return WorldPopulationService
