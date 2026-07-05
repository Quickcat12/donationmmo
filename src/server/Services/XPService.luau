--!strict
-- Grants XP from any source (obbies, quests, donations), tracks rank/level, and
-- notifies other services + the client whenever a player's XP or rank changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RankConfig = require(Shared.Config.RankConfig)
local WorldConfig = require(Shared.Config.WorldConfig)
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)
local Signal = require(Shared.Util.Signal)

local PlayerDataService = require(script.Parent.PlayerDataService)
local VIPService = require(script.Parent.VIPService)
local ServerBoostService = require(script.Parent.ServerBoostService)

type RankInfo = RankConfig.RankInfo

local XPService = {}

-- Fires (player: Player, oldRank: RankInfo, newRank: RankInfo) whenever a player crosses
-- into a new rank. StandService/CosmeticService etc. should connect to this.
XPService.RankChanged = Signal.new()

-- The world multiplier for the place this server instance represents. Resolved once at
-- startup by matching game.PlaceId against WorldConfig. Defaults to 1.0 during local
-- testing / before real Place IDs are filled in (all placeholders are 0).
local currentWorldMultiplier = 1.0
do
	for _, world in WorldConfig.Worlds do
		if world.placeId ~= 0 and world.placeId == game.PlaceId then
			currentWorldMultiplier = world.xpMultiplier
			break
		end
	end
end

local function setupLeaderstats(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local rank = RankConfig.getRankForXp(profile.xp)
	local level = RankConfig.getLevelForXp(profile.xp)

	local rankValue = Instance.new("StringValue")
	rankValue.Name = "Rank"
	rankValue.Value = rank.name
	rankValue.Parent = leaderstats

	local levelValue = Instance.new("IntValue")
	levelValue.Name = "Level"
	levelValue.Value = level
	levelValue.Parent = leaderstats

	leaderstats.Parent = player
end

local function updateLeaderstats(player: Player, rank: RankInfo, level: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end
	local rankValue = leaderstats:FindFirstChild("Rank") :: StringValue?
	local levelValue = leaderstats:FindFirstChild("Level") :: IntValue?
	if rankValue then
		rankValue.Value = rank.name
	end
	if levelValue then
		levelValue.Value = level
	end
end

-- Grants XP to a player from the given source. `source` is a free-form string used only
-- for logging/analytics (e.g. "obby_1", "donation", "quest_daily_1").
function XPService.grantXp(player: Player, amount: number, source: string)
	if amount <= 0 then
		return
	end

	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end

	local oldRank = RankConfig.getRankForXp(profile.xp)
	local vipMultiplier = VIPService.getMultiplier(player)
	local serverBoostMultiplier = ServerBoostService.getMultiplier()
	local finalAmount =
		math.floor(amount * oldRank.xpMultiplier * currentWorldMultiplier * vipMultiplier * serverBoostMultiplier)

	profile.xp += finalAmount

	local newRank = RankConfig.getRankForXp(profile.xp)
	local newLevel = RankConfig.getLevelForXp(profile.xp)
	local progress = RankConfig.getRankProgress(profile.xp)

	updateLeaderstats(player, newRank, newLevel)

	Net.get(RemoteNames.Events.XpChanged):FireClient(player, {
		xp = profile.xp,
		level = newLevel,
		rank = newRank.name,
		progress = progress,
		gained = finalAmount,
		source = source,
	})

	if newRank.order ~= oldRank.order then
		XPService.RankChanged:Fire(player, oldRank, newRank)
		Net.get(RemoteNames.Events.RankUp):FireClient(player, {
			oldRank = oldRank.name,
			newRank = newRank.name,
			title = newRank.title,
		})
	end
end

function XPService.getRank(player: Player): RankInfo?
	local profile = PlayerDataService.get(player)
	if not profile then
		return nil
	end
	return RankConfig.getRankForXp(profile.xp)
end

function XPService.getLevel(player: Player): number?
	local profile = PlayerDataService.get(player)
	if not profile then
		return nil
	end
	return RankConfig.getLevelForXp(profile.xp)
end

function XPService.start()
	PlayerDataService.DataLoaded:Connect(function(player: Player)
		setupLeaderstats(player)

		local profile = PlayerDataService.get(player)
		if not profile then
			return
		end

		-- Push an initial snapshot so the client HUD has something to render before
		-- the player's first XP-granting action.
		local rank = RankConfig.getRankForXp(profile.xp)
		local level = RankConfig.getLevelForXp(profile.xp)
		local progress = RankConfig.getRankProgress(profile.xp)

		Net.get(RemoteNames.Events.XpChanged):FireClient(player, {
			xp = profile.xp,
			level = level,
			rank = rank.name,
			progress = progress,
			gained = 0,
			source = "initial",
		})
	end)
end

return XPService
