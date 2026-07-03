--!strict
-- Assigns donation stands to players and wires up their ProximityPrompts.
--
-- BUILDER CONTRACT (for whoever builds the physical stands in Studio, since I can't
-- place 3D geometry): tag each stand Model with the CollectionService tag
-- "DonationStand". Each tagged model must contain a ProximityPrompt named
-- "DonatePrompt" somewhere in its descendants. This script will set two attributes on
-- the Model that a separate (builder-owned) visual script can read to swap
-- meshes/materials per tier:
--   OwnerUserId: number   -- 0 while unclaimed
--   Tier: number          -- 1+, follows the owner's rank order (see RankConfig)

local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RankConfig = require(Shared.Config.RankConfig)
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)

local PlayerDataService = require(script.Parent.PlayerDataService)
local XPService = require(script.Parent.XPService)

local STAND_TAG = "DonationStand"

local StandService = {}

local standByOwner: { [Player]: Model } = {}

local function findPrompt(stand: Model): ProximityPrompt?
	return stand:FindFirstChildWhichIsA("ProximityPrompt", true)
end

local function getUnclaimedStand(): Model?
	for _, instance in CollectionService:GetTagged(STAND_TAG) do
		if instance:IsA("Model") and (instance:GetAttribute("OwnerUserId") or 0) == 0 then
			return instance
		end
	end
	return nil
end

local function assignStand(player: Player)
	local stand = getUnclaimedStand()
	if not stand then
		warn(`[StandService] No unclaimed stand available for {player.Name}`)
		return
	end

	stand:SetAttribute("OwnerUserId", player.UserId)
	stand:SetAttribute("OwnerName", player.Name)

	local rank = XPService.getRank(player)
	stand:SetAttribute("Tier", rank and rank.order or 1)

	standByOwner[player] = stand
end

local function releaseStand(player: Player)
	local stand = standByOwner[player]
	if stand then
		stand:SetAttribute("OwnerUserId", 0)
		stand:SetAttribute("OwnerName", "")
		stand:SetAttribute("Tier", 1)
		standByOwner[player] = nil
	end
end

local function onPromptTriggered(prompt: ProximityPrompt, donorPlayer: Player)
	local stand = prompt:FindFirstAncestorOfClass("Model")
	if not stand or not CollectionService:HasTag(stand, STAND_TAG) then
		return
	end

	local ownerUserId = stand:GetAttribute("OwnerUserId")
	if type(ownerUserId) ~= "number" or ownerUserId == 0 then
		return
	end

	if ownerUserId == donorPlayer.UserId then
		return -- can't donate to your own stand
	end

	local owner = Players:GetPlayerByUserId(ownerUserId)
	local ownerProfile = owner and PlayerDataService.get(owner)
	if not owner or not ownerProfile then
		return
	end

	-- Fetch live name/price/icon for each of the owner's linked Gamepasses so the donor's
	-- client can render an up-to-date picker without trusting stale cached data.
	local gamepasses = {}
	for _, entry in ownerProfile.stand.donationGamepasses do
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(entry.gamepassId, Enum.InfoType.GamePass)
		end)
		if ok and info and info.IsForSale then
			table.insert(gamepasses, {
				gamepassId = entry.gamepassId,
				slot = entry.slot,
				name = info.Name,
				price = info.PriceInRobux,
			})
		end
	end

	table.sort(gamepasses, function(a, b)
		return a.slot < b.slot
	end)

	-- Hands off to the client to open the gamepass picker UI; the client prompts the
	-- purchase directly and then fires ReportGamepassDonation once it completes.
	Net.get(RemoteNames.Events.OpenDonationMenu):FireClient(donorPlayer, ownerUserId, stand:GetAttribute("OwnerName"), gamepasses)
end

local function hookStand(stand: Instance)
	if not stand:IsA("Model") then
		return
	end
	local prompt = findPrompt(stand)
	if not prompt then
		warn(`[StandService] Stand "{stand:GetFullName()}" is missing a ProximityPrompt named "DonatePrompt"`)
		return
	end
	prompt.Triggered:Connect(function(playerWhoTriggered)
		onPromptTriggered(prompt, playerWhoTriggered)
	end)
	if stand:GetAttribute("OwnerUserId") == nil then
		stand:SetAttribute("OwnerUserId", 0)
		stand:SetAttribute("Tier", 1)
	end
end

function StandService.start()
	for _, stand in CollectionService:GetTagged(STAND_TAG) do
		hookStand(stand)
	end
	CollectionService:GetInstanceAddedSignal(STAND_TAG):Connect(hookStand)

	PlayerDataService.DataLoaded:Connect(assignStand)
	Players.PlayerRemoving:Connect(releaseStand)

	XPService.RankChanged:Connect(function(player: Player, _oldRank: RankConfig.RankInfo, newRank: RankConfig.RankInfo)
		local stand = standByOwner[player]
		if stand then
			stand:SetAttribute("Tier", newRank.order)
		end
	end)
end

return StandService
