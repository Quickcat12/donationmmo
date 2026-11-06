--!strict
-- Game-owned XP boosts sold as real Developer Products (see XPShopConfig.luau). Unlike
-- donations (player-owned Gamepasses, see DonationService.luau), this revenue goes to the
-- experience/group - it's the one place Developer Products are actually the right tool.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local XPShopConfig = require(Shared.Config.XPShopConfig)
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)

local XPService = require(script.Parent.XPService)
local ServerBoostService = require(script.Parent.ServerBoostService)

local XPShopService = {}

local PlayerDataService = require(script.Parent.PlayerDataService)

-- Roblox retries a receipt until it gets PurchaseGranted, and can deliver the same
-- receipt again after a server crash. Keeping the last few PurchaseIds in the profile
-- (which ProfileService saves) means a retry can never grant paid XP twice.
local PURCHASE_HISTORY_SIZE = 50

local function alreadyGranted(profile: any, purchaseId: string): boolean
	return table.find(profile.purchaseHistory, purchaseId) ~= nil
end

local function recordPurchase(profile: any, purchaseId: string)
	table.insert(profile.purchaseHistory, purchaseId)
	while #profile.purchaseHistory > PURCHASE_HISTORY_SIZE do
		table.remove(profile.purchaseHistory, 1)
	end
end

-- The sole owner of MarketplaceService.ProcessReceipt for the whole experience - only
-- one callback can be registered at a time, so any other Developer Product (e.g. the
-- server-wide XP boost) delegates through here rather than registering its own.
local function processReceipt(receiptInfo): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	-- No profile means the player left or their data hasn't loaded. Granting now would
	-- silently drop the XP, so let Roblox retry on their next session instead.
	local profile = player and PlayerDataService.get(player)
	if not player or not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(receiptInfo.PurchaseId)
	if alreadyGranted(profile, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local item = XPShopConfig.getItemByProductId(receiptInfo.ProductId)
	if item then
		local ok = pcall(function()
			XPService.grantXp(player, item.xpAmount, "xp_shop")
		end)
		if not ok then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		recordPurchase(profile, purchaseId)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local boostDecision = ServerBoostService.tryProcessReceipt(receiptInfo)
	if boostDecision then
		if boostDecision == Enum.ProductPurchaseDecision.PurchaseGranted then
			recordPurchase(profile, purchaseId)
		end
		return boostDecision
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function onRequestBuyXp(player: Player, productId: unknown)
	-- productId 0 is the "not created yet" placeholder; every unset tier would match it.
	if type(productId) ~= "number" or productId == 0 then
		return
	end
	if not XPShopConfig.getItemByProductId(productId) then
		return
	end
	MarketplaceService:PromptProductPurchase(player, productId)
end

function XPShopService.start()
	MarketplaceService.ProcessReceipt = processReceipt
	Net.get(RemoteNames.Events.RequestBuyXp).OnServerEvent:Connect(onRequestBuyXp)
end

return XPShopService
