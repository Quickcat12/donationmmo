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

-- The player list shows Rank, Donated and Raised, never the raw level: players identify
-- by color ("I'm a Gold"), and lifetime Robux totals are the social proof that makes a
-- generous donor worth standing next to.
local function setupLeaderstats(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local rankValue = Instance.new("StringValue")
	rankValue.Name = "Rank"
	rankValue.Value = RankConfig.getRankForXp(profile.xp).name
	rankValue.Parent = leaderstats

	local donatedValue = Instance.new("IntValue")
	donatedValue.Name = "Donated"
	donatedValue.Value = profile.totalDonatedRobux
	donatedValue.Parent = leaderstats

	local raisedValue = Instance.new("IntValue")
	raisedValue.Name = "Raised"
	raisedValue.Value = profile.totalReceivedRobux
	raisedValue.Parent = leaderstats

	leaderstats.Parent = player
end

local function updateLeaderstats(player: Player, rank: RankInfo, _level: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	local rankValue = leaderstats and leaderstats:FindFirstChild("Rank") :: StringValue?
	if rankValue then
		rankValue.Value = rank.name
	end
end

-- Called by DonationService after a donation so both columns update live.
function XPService.refreshDonationStats(player: Player)
	local profile = PlayerDataService.get(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not profile or not leaderstats then
		return
	end
	local donatedValue = leaderstats:FindFirstChild("Donated") :: IntValue?
	local raisedValue = leaderstats:FindFirstChild("Raised") :: IntValue?
	if donatedValue then
		donatedValue.Value = profile.totalDonatedRobux
	end
	if raisedValue then
		raisedValue.Value = profile.totalReceivedRobux
	end
end

-- Fires (player, finalAmount, source) after every grant, for listeners that react to XP
-- itself (e.g. session stats) rather than to rank changes.
XPService.XpGranted = Signal.new()

-- Sources whose XP-per-Robux must stay fixed. The whole economy rests on this: the XP
-- Shop is the efficient route in World 1, but rank and world multipliers only boost
-- everything else, so climbing makes donating cheaper per XP than the shop. If shop XP
-- were multiplied too, both would scale together and that crossover would never come.
-- VIP still applies, since it was sold as "+15% XP from every source".
local FIXED_RATE_SOURCES = {
	xp_shop = true,
}

-- The combined multiplier a grant from `source` would receive right now. Exposed so
-- UIs (and the HUD popup) can show players exactly what their climb is worth.
function XPService.getMultiplierFor(player: Player, source: string): number
	local profile = PlayerDataService.get(player)
	local vipMultiplier = VIPService.getMultiplier(player)
	if FIXED_RATE_SOURCES[source] then
		return vipMultiplier
	end
	local rank = RankConfig.getRankForXp(profile and profile.xp or 0)
	return rank.xpMultiplier * currentWorldMultiplier * vipMultiplier * ServerBoostService.getMultiplier()
end

function XPService.getWorldMultiplier(): number
	return currentWorldMultiplier
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
	local multiplier = XPService.getMultiplierFor(player, source)
	local finalAmount = math.floor(amount * multiplier)

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
		multiplier = multiplier,
		xpToNext = RankConfig.getXpToNextRank(profile.xp),
		donationMultiplier = XPService.getMultiplierFor(player, "donation_sent"),
	})

	XPService.XpGranted:Fire(player, finalAmount, source)

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
			multiplier = XPService.getMultiplierFor(player, "donation_sent"),
			xpToNext = RankConfig.getXpToNextRank(profile.xp),
		donationMultiplier = XPService.getMultiplierFor(player, "donation_sent"),
		})
	end)
end

return XPService
