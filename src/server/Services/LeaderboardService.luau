--!strict
-- Maintains global top-10 leaderboards (by XP and by lifetime donations given) using
-- OrderedDataStores, and periodically broadcasts a snapshot to every client.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)

local PlayerDataService = require(script.Parent.PlayerDataService)

local UPDATE_INTERVAL_SECONDS = 60
local TOP_N = 10

local LeaderboardService = {}

local xpStore = DataStoreService:GetOrderedDataStore("TopXP_v1")
local donationsStore = DataStoreService:GetOrderedDataStore("TopDonations_v1")

local function updatePlayerScores(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end

	local key = tostring(player.UserId)

	pcall(function()
		xpStore:SetAsync(key, math.floor(profile.xp))
	end)
	pcall(function()
		donationsStore:SetAsync(key, math.floor(profile.totalDonatedRobux))
	end)
end

local nameCache: { [number]: string } = {}

local function getDisplayName(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end

	local name = `Player{userId}`
	pcall(function()
		name = Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = name
	return name
end

local function fetchTop(store: OrderedDataStore): { { userId: number, name: string, value: number } }
	local results = {}
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, TOP_N)
	end)
	if not ok then
		return results
	end

	local page = pages:GetCurrentPage()
	for _, entry in page do
		local userId = tonumber(entry.key) or 0
		table.insert(results, { userId = userId, name = getDisplayName(userId), value = entry.value })
	end
	return results
end

local function broadcastLeaderboards()
	local snapshot = {
		topXp = fetchTop(xpStore),
		topDonations = fetchTop(donationsStore),
	}
	Net.get(RemoteNames.Events.LeaderboardUpdated):FireAllClients(snapshot)
end

function LeaderboardService.start()
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				updatePlayerScores(player)
			end
			broadcastLeaderboards()
			task.wait(UPDATE_INTERVAL_SECONDS)
		end
	end)

	Players.PlayerRemoving:Connect(updatePlayerScores)
end

return LeaderboardService
