--!strict
-- Handles the donation purchase flow: a donor prompts a Robux purchase (Developer
-- Product) intended for a specific receiver standing at a stand. Grants XP to both
-- sides and records donation stats.
--
-- IMPORTANT ROBLOX PLATFORM LIMITATION (read before wiring up real products):
-- Roblox does not expose any scripting API that transfers real Robux from a Developer
-- Product purchase directly to another player. Revenue from a Developer Product always
-- goes to the experience's owner (you, or your group). There is no ProcessReceipt-time
-- "pay this other player" call.
--
-- The only Roblox-sanctioned way for donation *receivers* to actually receive Robux is
-- Group Payouts (Group > Configure > Payouts), which lets the group owner allocate a
-- percentage of group funds to members periodically. That is a manual/administrative
-- action on the group's Configure page, not something this script can trigger live.
--
-- So this service tracks `totalReceivedRobux` as a donation-credit STAT (drives XP,
-- rank progress, leaderboards, and stand tier) - it is not itself a Robux transfer.
-- If you want receivers to be paid out in real Robux, use that stat as the basis for
-- periodically configuring Group Payout percentages yourself; I cannot automate that
-- part since it's a group-ownership action outside of any script's reach.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DonationConfig = require(Shared.Config.DonationConfig)
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)

local PlayerDataService = require(script.Parent.PlayerDataService)
local XPService = require(script.Parent.XPService)
local QuestService = require(script.Parent.QuestService)

local DonationService = {}

-- Cross-server-safe record of "this donor intends this donation to go to this receiver",
-- written right before prompting the purchase and consumed in ProcessReceipt. A DataStore
-- (not a plain in-memory table) is used because ProcessReceipt can be retried by Roblox
-- on a different server if the original server crashes before confirming the receipt.
local PendingDonationsStore = DataStoreService:GetDataStore("PendingDonations_v1")

local function setPendingReceiver(donorUserId: number, receiverUserId: number, productId: number)
	local key = `{donorUserId}_{productId}`
	local ok, err = pcall(function()
		PendingDonationsStore:SetAsync(key, receiverUserId)
	end)
	if not ok then
		warn(`[DonationService] Failed to record pending donation intent: {err}`)
	end
end

local function consumePendingReceiver(donorUserId: number, productId: number): number?
	local key = `{donorUserId}_{productId}`
	local receiverUserId: number? = nil
	pcall(function()
		receiverUserId = PendingDonationsStore:GetAsync(key)
	end)
	pcall(function()
		PendingDonationsStore:RemoveAsync(key)
	end)
	return receiverUserId
end

local function grantDonationRewards(donor: Player, receiver: Player?, tier: DonationConfig.DonationTier)
	XPService.grantXp(donor, tier.donorXp, "donation_sent")
	QuestService.reportProgress(donor, "donate_sent")

	local donorProfile = PlayerDataService.get(donor)
	if donorProfile then
		donorProfile.totalDonatedRobux += tier.robuxPrice
		donorProfile.donationCount += 1
	end

	if receiver then
		local receiverProfile = PlayerDataService.get(receiver)
		if receiverProfile then
			receiverProfile.totalReceivedRobux += tier.robuxPrice
			receiverProfile.receivedCount += 1
			receiverProfile.stand.totalReceived += tier.robuxPrice
		end

		XPService.grantXp(receiver, math.floor(tier.donorXp * DonationConfig.ReceiverXpShare), "donation_received")
		QuestService.reportProgress(receiver, "donate_received")

		Net.get(RemoteNames.Events.DonationReceived):FireClient(receiver, {
			fromUserId = donor.UserId,
			fromName = donor.Name,
			robuxAmount = tier.robuxPrice,
		})
	end
end

local function processReceipt(receiptInfo): Enum.ProductPurchaseDecision
	local donor = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	local tier = DonationConfig.getTierByProductId(receiptInfo.ProductId)

	if not donor or not tier then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local receiverUserId = consumePendingReceiver(receiptInfo.PlayerId, receiptInfo.ProductId)
	local receiver = receiverUserId and Players:GetPlayerByUserId(receiverUserId) or nil

	local ok = pcall(function()
		grantDonationRewards(donor, receiver, tier)
	end)

	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Called from the client when a player chooses to donate to a stand's owner.
function DonationService.requestDonate(donor: Player, receiverUserId: number, productId: number)
	if donor.UserId == receiverUserId then
		return -- no self-donation
	end

	local tier = DonationConfig.getTierByProductId(productId)
	if not tier then
		warn(`[DonationService] Unknown donation productId {productId}`)
		return
	end

	setPendingReceiver(donor.UserId, receiverUserId, productId)
	MarketplaceService:PromptProductPurchase(donor, productId)
end

function DonationService.start()
	MarketplaceService.ProcessReceipt = processReceipt

	Net.get(RemoteNames.Events.RequestDonate).OnServerEvent:Connect(function(player: Player, receiverUserId, productId)
		if type(receiverUserId) ~= "number" or type(productId) ~= "number" then
			return
		end
		DonationService.requestDonate(player, receiverUserId, productId)
	end)
end

return DonationService
