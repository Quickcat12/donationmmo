--!strict
-- The "social class" layer from the design doc: players are identified by rank/title, not
-- a raw level number. This service:
--   - Unlocks + auto-equips a title whenever a player reaches a new rank
--   - Publishes RankName/RankColor/RankTitle/ShowChatTag as Player Attributes, which
--     replicate to every client for free - ChatTagController reads them client-side to
--     prefix chat messages, no extra remote needed for that part
--   - Builds a custom overhead nameplate (title + name) per character, replacing the
--     default Roblox nameplate so the rank color is always visible above a player's head
--   - Broadcasts a server-wide announcement when a high-enough rank joins

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RankConfig = require(Shared.Config.RankConfig)
local CosmeticConfig = require(Shared.Config.CosmeticConfig)
local PlayerDataSchema = require(Shared.Config.PlayerDataSchema)
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)

local PlayerDataService = require(script.Parent.PlayerDataService)
local XPService = require(script.Parent.XPService)

type RankInfo = RankConfig.RankInfo
type PlayerProfile = PlayerDataSchema.PlayerProfile

local CosmeticService = {}

local function pushCosmetics(player: Player, profile: PlayerProfile)
	Net.get(RemoteNames.Events.CosmeticsUpdated):FireClient(player, {
		ownedTitles = profile.cosmetics.ownedTitles,
		equippedTitle = profile.cosmetics.equippedTitle,
		showChatTag = profile.settings.showChatTag,
	})
end

-- Adds `rank`'s title to the profile's collection if missing, and equips it if the
-- player has never equipped anything yet (brand-new profile).
local function ensureTitleUnlocked(profile: PlayerProfile, rank: RankInfo)
	if not table.find(profile.cosmetics.ownedTitles, rank.title) then
		table.insert(profile.cosmetics.ownedTitles, rank.title)
	end
	if profile.cosmetics.equippedTitle == nil then
		profile.cosmetics.equippedTitle = rank.title
	end
end

local function applyAttributes(player: Player, profile: PlayerProfile)
	local rank = RankConfig.getRankForXp(profile.xp)
	player:SetAttribute("RankName", rank.name)
	player:SetAttribute("RankColor", rank.color)
	player:SetAttribute("RankTitle", profile.cosmetics.equippedTitle or rank.title)
	player:SetAttribute("ShowChatTag", profile.settings.showChatTag)
end

function CosmeticService.refreshOverhead(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local billboard = head and head:FindFirstChild("RankNameplate")
	local titleLabel = billboard and billboard:FindFirstChild("TitleLabel") :: TextLabel?
	if not titleLabel then
		return
	end

	local rankName = player:GetAttribute("RankName")
	local rank = (type(rankName) == "string" and RankConfig.getRankByName(rankName)) or RankConfig.Ranks[1]
	local title = player:GetAttribute("RankTitle")

	titleLabel.Text = (type(title) == "string" and title) or rank.title
	titleLabel.TextColor3 = rank.color
end

local function buildOverhead(player: Player, character: Model)
	local head = character:WaitForChild("Head", 5) :: BasePart?
	local humanoid = (character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)) :: Humanoid?
	if not head or not humanoid then
		return
	end

	-- Hide the default nameplate/health bar - our BillboardGui below is the only one shown.
	humanoid.NameDisplayDistance = 0
	humanoid.HealthDisplayDistance = 0

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "RankNameplate"
	billboard.Size = UDim2.fromOffset(220, 44)
	billboard.StudsOffset = Vector3.new(0, 2.4, 0)
	billboard.MaxDistance = CosmeticConfig.OverheadMaxDistance
	billboard.AlwaysOnTop = true
	billboard.Parent = head

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, 0, 0, 20)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextScaled = true
	titleLabel.TextStrokeTransparency = 0.4
	titleLabel.Parent = billboard

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 20)
	nameLabel.Position = UDim2.new(0, 0, 0, 22)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.Text = player.Name
	nameLabel.Parent = billboard

	CosmeticService.refreshOverhead(player)
end

local function announceJoin(player: Player, rank: RankInfo)
	if rank.order < CosmeticConfig.AnnounceMinRankOrder then
		return
	end
	Net.get(RemoteNames.Events.PlayerJoinedAnnouncement):FireAllClients({
		userId = player.UserId,
		name = player.Name,
		rankName = rank.name,
		rankColor = rank.color,
		title = player:GetAttribute("RankTitle") or rank.title,
	})
end

local function onRankChanged(player: Player, _oldRank: RankInfo, newRank: RankInfo)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end

	if not table.find(profile.cosmetics.ownedTitles, newRank.title) then
		table.insert(profile.cosmetics.ownedTitles, newRank.title)
	end
	-- Rank-up always re-equips the new title - showing off the latest promotion is the point.
	-- Players who prefer an older title can re-equip it afterwards via RequestEquipTitle.
	profile.cosmetics.equippedTitle = newRank.title

	applyAttributes(player, profile)
	CosmeticService.refreshOverhead(player)
	pushCosmetics(player, profile)
end

local function onRequestEquipTitle(player: Player, title: unknown)
	if type(title) ~= "string" then
		return
	end
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	if not table.find(profile.cosmetics.ownedTitles, title) then
		return
	end

	profile.cosmetics.equippedTitle = title
	applyAttributes(player, profile)
	CosmeticService.refreshOverhead(player)
	pushCosmetics(player, profile)
end

local function onRequestToggleChatTag(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	profile.settings.showChatTag = not profile.settings.showChatTag
	applyAttributes(player, profile)
	pushCosmetics(player, profile)
end

function CosmeticService.start()
	Net.get(RemoteNames.Events.RequestEquipTitle).OnServerEvent:Connect(onRequestEquipTitle)
	Net.get(RemoteNames.Events.RequestToggleChatTag).OnServerEvent:Connect(onRequestToggleChatTag)

	XPService.RankChanged:Connect(onRankChanged)

	PlayerDataService.DataLoaded:Connect(function(player: Player)
		local profile = PlayerDataService.get(player)
		if not profile then
			return
		end

		local rank = RankConfig.getRankForXp(profile.xp)
		ensureTitleUnlocked(profile, rank)
		applyAttributes(player, profile)
		pushCosmetics(player, profile)
		announceJoin(player, rank)

		if player.Character then
			task.spawn(buildOverhead, player, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			buildOverhead(player, character)
		end)
	end)
end

return CosmeticService
