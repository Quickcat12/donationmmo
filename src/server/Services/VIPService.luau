--!strict
-- Tracks ownership of the one game-owned Game Pass (VIPConfig.GamepassId - see
-- VIPConfig.luau), which grants a permanent XP multiplier. Checked once per join via
-- MarketplaceService (the authoritative source - never trust the client), cached for
-- the session, and re-checked immediately if a player buys it mid-session.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local VIPConfig = require(Shared.Config.VIPConfig)

local VIPService = {}

local vipCache: { [Player]: boolean } = {}

local function checkOwnership(player: Player)
	if VIPConfig.GamepassId == 0 then
		-- Not created yet (see scripts/monetization/create_products.py) - no-op until it is.
		vipCache[player] = false
		player:SetAttribute("VIPOwned", false)
		return
	end

	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIPConfig.GamepassId)
	end)

	local isOwner = ok and owns == true
	vipCache[player] = isOwner
	player:SetAttribute("VIPOwned", isOwner)
end

-- Returns 1 for non-owners, or VIPConfig.XpMultiplier for owners. Multiply this in
-- alongside the rank/world multipliers wherever XP is granted (see XPService.grantXp).
function VIPService.getMultiplier(player: Player): number
	if vipCache[player] then
		return VIPConfig.XpMultiplier
	end
	return 1
end

function VIPService.start()
	Players.PlayerAdded:Connect(checkOwnership)
	for _, player in Players:GetPlayers() do
		task.spawn(checkOwnership, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		vipCache[player] = nil
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamePassId: number, wasPurchased: boolean)
		if wasPurchased and gamePassId == VIPConfig.GamepassId then
			checkOwnership(player)
		end
	end)
end

return VIPService
