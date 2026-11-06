--!strict
-- Auto-discovers a player's own Gamepasses so they don't have to hunt down and paste IDs
-- manually in the Stand Manager UI. Uses Roblox's public web APIs (the same data
-- https://www.roblox.com/users/<id>/inventory shows) proxied through roproxy.com, because
-- HttpService can't reach games.roblox.com directly from inside a live experience - only a
-- small allowlist of domains is reachable, and roproxy is the standard community workaround
-- Roblox developers use for this. This never touches private/authenticated data - only
-- public game and Game Pass listings anyone could see on the website.
--
-- Requires "Allow HTTP Requests" enabled in Game Settings > Security, or every call here
-- just fails gracefully (caught by pcall) and the player falls back to pasting IDs manually.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)

local GamepassDiscoveryService = {}

local GAMES_URL = "https://games.roproxy.com/v2/users/%d/games?sortOrder=Asc&limit=50"
local GAMEPASSES_URL = "https://games.roproxy.com/v1/games/%d/game-passes?sortOrder=Asc&limit=100"

local MAX_GAMES_TO_SCAN = 15
local MAX_GAMEPASSES_RETURNED = 30
local COOLDOWN_SECONDS = 30

local lastDiscoverAt: { [Player]: number } = {}

local function isOnCooldown(player: Player): boolean
	local last = lastDiscoverAt[player]
	local now = os.clock()
	if last and (now - last) < COOLDOWN_SECONDS then
		return true
	end
	lastDiscoverAt[player] = now
	return false
end

local function fetchJson(url: string): any?
	local ok, result = pcall(function()
		return HttpService:JSONDecode(HttpService:GetAsync(url))
	end)
	if not ok then
		return nil
	end
	return result
end

local function getUniverseIdsForPlayer(userId: number): { number }
	local data = fetchJson(GAMES_URL:format(userId))
	if not data or not data.data then
		return {}
	end

	local universeIds = {}
	for i, game in data.data do
		if i > MAX_GAMES_TO_SCAN then
			break
		end
		if game.id then
			table.insert(universeIds, game.id)
		end
	end
	return universeIds
end

local function getPaidGamepassesForUniverse(universeId: number): { { id: number, name: string, price: number } }
	local data = fetchJson(GAMEPASSES_URL:format(universeId))
	if not data or not data.data then
		return {}
	end

	local gamepasses = {}
	for _, pass in data.data do
		if pass.price and pass.price > 0 then
			table.insert(gamepasses, { id = pass.id, name = pass.displayName or pass.name, price = pass.price })
		end
	end
	return gamepasses
end

local function onRequestDiscoverGamepasses(player: Player)
	local resultEvent = Net.get(RemoteNames.Events.DiscoverGamepassesResult)

	if isOnCooldown(player) then
		resultEvent:FireClient(player, { success = false, reason = "Please wait before discovering again." })
		return
	end

	local universeIds = getUniverseIdsForPlayer(player.UserId)
	if #universeIds == 0 then
		resultEvent:FireClient(player, {
			success = false,
			reason = "Couldn't find any public games for your account (or HTTP requests are disabled for this experience).",
		})
		return
	end

	local allGamepasses = {}
	for _, universeId in universeIds do
		for _, pass in getPaidGamepassesForUniverse(universeId) do
			table.insert(allGamepasses, pass)
			if #allGamepasses >= MAX_GAMEPASSES_RETURNED then
				break
			end
		end
		if #allGamepasses >= MAX_GAMEPASSES_RETURNED then
			break
		end
	end

	if #allGamepasses == 0 then
		resultEvent:FireClient(player, {
			success = false,
			reason = "No paid Gamepasses found across your public games. Create one on creator.roblox.com first.",
		})
		return
	end

	resultEvent:FireClient(player, { success = true, gamepasses = allGamepasses })
end

function GamepassDiscoveryService.start()
	Net.get(RemoteNames.Events.RequestDiscoverGamepasses).OnServerEvent:Connect(onRequestDiscoverGamepasses)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastDiscoverAt[player] = nil
	end)
end

return GamepassDiscoveryService
