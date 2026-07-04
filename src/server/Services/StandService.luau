--!strict
-- Assigns donation stands to players and wires up their ProximityPrompts.
--
-- Stands are currently generated procedurally by WorldBuilderService.luau. Each tagged
-- Model ("DonationStand" tag) is expected to contain: a "Podium" BasePart (recolored per
-- rank tier), a ProximityPrompt named "DonatePrompt" (on the Podium), and a "SignPost"
-- part with a BillboardGui named "Sign" containing a TextLabel named "OwnerLabel". If
-- this gets replaced with real 3D art in Studio, keep those same child names so this
-- script's visual updates keep working - or update findPrompt/updateStandVisual below to
-- match whatever new structure is used.

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

-- Stand materials get more premium as tier climbs, so a stand is a real "visual
-- representation of accomplishments" (design doc) and not just a re-tinted box.
local function materialForTier(tierOrder: number): Enum.Material
	if tierOrder >= 6 then
		return Enum.Material.Neon
	elseif tierOrder >= 4 then
		return Enum.Material.Marble
	elseif tierOrder >= 2 then
		return Enum.Material.Metal
	end
	return Enum.Material.SmoothPlastic
end

local function updateStandVisual(stand: Model, ownerName: string?, tierOrder: number, ownerTitle: string?)
	local prompt = findPrompt(stand)
	if prompt then
		prompt.ObjectText = ownerName or "Empty Stand"
	end

	local clampedTier = math.clamp(tierOrder, 1, #RankConfig.Ranks)
	local rank = RankConfig.Ranks[clampedTier]

	local podium = stand:FindFirstChild("Podium") :: BasePart?
	if podium then
		podium.Color = rank.color
		podium.Material = materialForTier(clampedTier)
		-- Stands grow with tier (bigger footprint), height stays put so it never sinks
		-- into or floats off the floor.
		local growth = (clampedTier - 1) * 0.6
		podium.Size = Vector3.new(6 + growth, 3, 6 + growth)
	end

	local tierRing = stand:FindFirstChild("TierRing") :: BasePart?
	if tierRing then
		tierRing.Color = rank.chatTagColor
		-- Invisible for the base tier, glows in brighter as rank climbs.
		tierRing.Transparency = clampedTier <= 1 and 1 or math.clamp(0.85 - clampedTier * 0.1, 0.1, 0.7)
	end

	local canopy = stand:FindFirstChild("Canopy") :: BasePart?
	if canopy then
		-- Canopies "unlock" starting at Gold (order 5).
		if clampedTier >= 5 then
			canopy.Transparency = 0
			canopy.Material = clampedTier >= 6 and Enum.Material.Neon or Enum.Material.Marble
			canopy.Color = rank.color
		else
			canopy.Transparency = 1
		end
	end

	local signPost = stand:FindFirstChild("SignPost")
	local billboard = signPost and signPost:FindFirstChild("Sign")
	local ownerLabel = billboard and billboard:FindFirstChild("OwnerLabel") :: TextLabel?
	if ownerLabel then
		ownerLabel.Text = ownerName or "Empty Stand"
	end

	local titleLabel = billboard and billboard:FindFirstChild("TitleLabel") :: TextLabel?
	if titleLabel then
		titleLabel.Text = ownerName and (ownerTitle or rank.title) or ""
		titleLabel.TextColor3 = rank.color
	end
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
	local tierOrder = rank and rank.order or 1
	local profile = PlayerDataService.get(player)
	stand:SetAttribute("Tier", tierOrder)
	updateStandVisual(stand, player.Name, tierOrder, profile and profile.cosmetics.equippedTitle)

	standByOwner[player] = stand
end

local function releaseStand(player: Player)
	local stand = standByOwner[player]
	if stand then
		stand:SetAttribute("OwnerUserId", 0)
		stand:SetAttribute("OwnerName", "")
		stand:SetAttribute("Tier", 1)
		updateStandVisual(stand, nil, 1)
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
			-- CosmeticService re-equips newRank.title on every rank-up, so use it directly
			-- here rather than racing profile.cosmetics.equippedTitle against listener order.
			updateStandVisual(stand, player.Name, newRank.order, newRank.title)
		end
	end)
end

return StandService
