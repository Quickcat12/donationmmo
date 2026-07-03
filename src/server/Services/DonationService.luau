--!strict
-- Donations happen via player-owned Gamepasses: each player creates their own Gamepass(es)
-- on creator.roblox.com at whatever price they want, then links the Gamepass ID to their
-- stand here. Other players buy that Gamepass directly via
-- MarketplaceService:PromptGamePassPurchase, so Robux goes straight to the receiver's
-- account - no Group Payout workaround needed, unlike a Developer-Product-based design.
--
-- The server never trusts the client's claim that a purchase happened.
-- ReportGamepassDonation is re-verified with MarketplaceService:UserOwnsGamePassAsync and
-- cross-checked against the receiver's actually-configured gamepass list before any reward
-- is granted.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)

local PlayerDataService = require(script.Parent.PlayerDataService)
local XPService = require(script.Parent.XPService)
local QuestService = require(script.Parent.QuestService)

local DonationService = {}

local MAX_GAMEPASS_SLOTS = 6

-- Donor XP scales with the live Robux price of whatever Gamepass they bought, so it works
-- for any price a player sets on their own Gamepass (not a fixed set of tiers).
local function computeDonorXp(robuxPrice: number): number
	return math.floor(robuxPrice * 10 * (1 + robuxPrice / 2000))
end

local function removeSlot(donationGamepasses: { any }, slot: number)
	for i = #donationGamepasses, 1, -1 do
		if donationGamepasses[i].slot == slot then
			table.remove(donationGamepasses, i)
		end
	end
end

local function onRequestSetDonationGamepass(player: Player, slot: unknown, gamepassId: unknown)
	if type(slot) ~= "number" or type(gamepassId) ~= "number" then
		return
	end
	if slot ~= math.floor(slot) or slot < 1 or slot > MAX_GAMEPASS_SLOTS then
		return
	end

	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end

	local resultEvent = Net.get(RemoteNames.Events.SetDonationGamepassResult)
	local donationGamepasses = profile.stand.donationGamepasses

	if gamepassId == 0 then
		removeSlot(donationGamepasses, slot)
		resultEvent:FireClient(player, { success = true, slot = slot, cleared = true })
		return
	end

	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(gamepassId, Enum.InfoType.GamePass)
	end)

	if not ok or not info then
		resultEvent:FireClient(player, { success = false, slot = slot, reason = "That Gamepass ID doesn't exist." })
		return
	end

	local creator = info.Creator
	if not creator or creator.CreatorType ~= "User" or creator.Id ~= player.UserId then
		resultEvent:FireClient(player, { success = false, slot = slot, reason = "You don't own that Gamepass." })
		return
	end

	if not info.IsForSale then
		resultEvent:FireClient(player, { success = false, slot = slot, reason = "That Gamepass isn't for sale." })
		return
	end

	removeSlot(donationGamepasses, slot)
	if #donationGamepasses >= MAX_GAMEPASS_SLOTS then
		resultEvent:FireClient(player, { success = false, slot = slot, reason = "All donation slots are full." })
		return
	end

	table.insert(donationGamepasses, { gamepassId = gamepassId, slot = slot })
	resultEvent:FireClient(player, {
		success = true,
		slot = slot,
		gamepassId = gamepassId,
		name = info.Name,
		price = info.PriceInRobux,
	})
end

local function onReportGamepassDonation(donor: Player, receiverUserId: unknown, gamepassId: unknown)
	if type(receiverUserId) ~= "number" or type(gamepassId) ~= "number" then
		return
	end
	if donor.UserId == receiverUserId then
		return
	end

	local receiver = Players:GetPlayerByUserId(receiverUserId)
	local receiverProfile = receiver and PlayerDataService.get(receiver)
	if not receiver or not receiverProfile then
		return
	end

	local isLinked = false
	for _, entry in receiverProfile.stand.donationGamepasses do
		if entry.gamepassId == gamepassId then
			isLinked = true
			break
		end
	end
	if not isLinked then
		return
	end

	local ownsOk, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(donor.UserId, gamepassId)
	end)
	if not ownsOk or not owns then
		return
	end

	local infoOk, info = pcall(function()
		return MarketplaceService:GetProductInfo(gamepassId, Enum.InfoType.GamePass)
	end)
	if not infoOk or not info then
		return
	end

	local robuxPrice = (info.PriceInRobux :: number?) or 0
	local donorXp = computeDonorXp(robuxPrice)

	XPService.grantXp(donor, donorXp, "donation_sent")
	QuestService.reportProgress(donor, "donate_sent")

	local donorProfile = PlayerDataService.get(donor)
	if donorProfile then
		donorProfile.totalDonatedRobux += robuxPrice
		donorProfile.donationCount += 1
	end

	receiverProfile.totalReceivedRobux += robuxPrice
	receiverProfile.receivedCount += 1
	receiverProfile.stand.totalReceived += robuxPrice

	XPService.grantXp(receiver, math.floor(donorXp * 0.35), "donation_received")
	QuestService.reportProgress(receiver, "donate_received")

	Net.get(RemoteNames.Events.DonationReceived):FireClient(receiver, {
		fromUserId = donor.UserId,
		fromName = donor.Name,
		robuxAmount = robuxPrice,
	})
end

function DonationService.start()
	Net.get(RemoteNames.Events.RequestSetDonationGamepass).OnServerEvent:Connect(onRequestSetDonationGamepass)
	Net.get(RemoteNames.Events.ReportGamepassDonation).OnServerEvent:Connect(onReportGamepassDonation)
end

return DonationService
