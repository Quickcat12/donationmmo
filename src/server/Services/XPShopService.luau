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

local XPShopService = {}

local function processReceipt(receiptInfo): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	local item = XPShopConfig.getItemByProductId(receiptInfo.ProductId)

	if not player or not item then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok = pcall(function()
		XPService.grantXp(player, item.xpAmount, "xp_shop")
	end)

	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function onRequestBuyXp(player: Player, productId: unknown)
	if type(productId) ~= "number" then
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
