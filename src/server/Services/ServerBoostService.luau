--!strict
-- A single Developer Product that any player can buy to temporarily boost XP for
-- EVERYONE currently in the server, with a server-wide announcement crediting the
-- buyer - a social-status purchase (see ServerBoostConfig.luau). Whales get public
-- credit for "blessing" the server, which is the point: it builds status for the
-- buyer while giving every other player in the room a reason to be glad they're there,
-- reinforcing the "everyone here benefits" loop rather than a purely private purchase.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ServerBoostConfig = require(Shared.Config.ServerBoostConfig)
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)

local ServerBoostService = {}

local boostEndsAt = 0

-- Returns 1 when no boost is active, or ServerBoostConfig.Multiplier while one is -
-- multiply this in alongside the rank/world/VIP multipliers in XPService.grantXp.
function ServerBoostService.getMultiplier(): number
	if os.time() < boostEndsAt then
		return ServerBoostConfig.Multiplier
	end
	return 1
end

local function activateBoost(buyerName: string)
	boostEndsAt = os.time() + ServerBoostConfig.DurationSeconds
	Net.get(RemoteNames.Events.ServerBoostActivated):FireAllClients({
		buyerName = buyerName,
		multiplier = ServerBoostConfig.Multiplier,
		durationSeconds = ServerBoostConfig.DurationSeconds,
	})
end

-- Called from XPShopService.processReceipt when a receipt's product isn't one of its
-- own XP-shop items - MarketplaceService.ProcessReceipt only accepts a single callback
-- for the whole experience, so XPShopService stays the sole owner of it and delegates
-- here instead of this service registering a second, competing callback.
function ServerBoostService.tryProcessReceipt(receiptInfo: any): Enum.ProductPurchaseDecision?
	if ServerBoostConfig.ProductId == 0 or receiptInfo.ProductId ~= ServerBoostConfig.ProductId then
		return nil
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok = pcall(activateBoost, player.Name)
	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function onRequestBuyServerBoost(player: Player)
	if ServerBoostConfig.ProductId == 0 then
		return
	end
	MarketplaceService:PromptProductPurchase(player, ServerBoostConfig.ProductId)
end

function ServerBoostService.start()
	Net.get(RemoteNames.Events.RequestBuyServerBoost).OnServerEvent:Connect(onRequestBuyServerBoost)
end

return ServerBoostService
