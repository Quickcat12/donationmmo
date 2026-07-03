--!strict

export type RankName = "Gray" | "Green" | "Blue" | "Purple" | "Gold" | "Diamond" | "Celestial"

export type RankInfo = {
	name: RankName,
	order: number,
	xpToReach: number, -- cumulative XP required to enter this rank
	color: Color3,
	chatTagColor: Color3,
	xpMultiplier: number, -- passive multiplier applied to all XP gains while at this rank
	title: string, -- display title, e.g. "Gray Wanderer"
}

local RankConfig = {}

RankConfig.Ranks = {
	{
		name = "Gray",
		order = 1,
		xpToReach = 0,
		color = Color3.fromRGB(150, 150, 150),
		chatTagColor = Color3.fromRGB(180, 180, 180),
		xpMultiplier = 1.0,
		title = "Gray Wanderer",
	},
	{
		name = "Green",
		order = 2,
		xpToReach = 1_000,
		color = Color3.fromRGB(70, 200, 90),
		chatTagColor = Color3.fromRGB(90, 220, 110),
		xpMultiplier = 1.1,
		title = "Green Climber",
	},
	{
		name = "Blue",
		order = 3,
		xpToReach = 5_000,
		color = Color3.fromRGB(60, 140, 230),
		chatTagColor = Color3.fromRGB(80, 160, 250),
		xpMultiplier = 1.25,
		title = "Blue Ascendant",
	},
	{
		name = "Purple",
		order = 4,
		xpToReach = 15_000,
		color = Color3.fromRGB(160, 90, 220),
		chatTagColor = Color3.fromRGB(180, 110, 240),
		xpMultiplier = 1.4,
		title = "Purple Patron",
	},
	{
		name = "Gold",
		order = 5,
		xpToReach = 40_000,
		color = Color3.fromRGB(230, 190, 60),
		chatTagColor = Color3.fromRGB(250, 210, 80),
		xpMultiplier = 1.6,
		title = "Gold Elite",
	},
	{
		name = "Diamond",
		order = 6,
		xpToReach = 100_000,
		color = Color3.fromRGB(90, 210, 230),
		chatTagColor = Color3.fromRGB(110, 230, 250),
		xpMultiplier = 1.85,
		title = "Diamond Luminary",
	},
	{
		name = "Celestial",
		order = 7,
		xpToReach = 250_000,
		color = Color3.fromRGB(255, 215, 255),
		chatTagColor = Color3.fromRGB(255, 235, 255),
		xpMultiplier = 2.25,
		title = "Celestial Icon",
	},
} :: { RankInfo }

-- Levels within a rank: each rank spans LEVELS_PER_RANK levels, evenly dividing the
-- XP gap between this rank's threshold and the next rank's threshold.
RankConfig.LevelsPerRank = 25

function RankConfig.getRankByName(name: string): RankInfo?
	for _, rank in RankConfig.Ranks do
		if rank.name == name then
			return rank
		end
	end
	return nil
end

function RankConfig.getRankForXp(xp: number): RankInfo
	local result = RankConfig.Ranks[1]
	for _, rank in RankConfig.Ranks do
		if xp >= rank.xpToReach then
			result = rank
		else
			break
		end
	end
	return result
end

function RankConfig.getNextRank(currentRank: RankInfo): RankInfo?
	return RankConfig.Ranks[currentRank.order + 1]
end

-- Returns 0-1 progress of a player's XP through their current rank towards the next.
function RankConfig.getRankProgress(xp: number): number
	local current = RankConfig.getRankForXp(xp)
	local nextRank = RankConfig.getNextRank(current)
	if not nextRank then
		return 1
	end
	local span = nextRank.xpToReach - current.xpToReach
	if span <= 0 then
		return 1
	end
	return math.clamp((xp - current.xpToReach) / span, 0, 1)
end

-- Absolute level number (1-based, across all ranks) for a given XP total.
function RankConfig.getLevelForXp(xp: number): number
	local current = RankConfig.getRankForXp(xp)
	local nextRank = RankConfig.getNextRank(current)
	local baseLevel = (current.order - 1) * RankConfig.LevelsPerRank + 1

	if not nextRank then
		return baseLevel
	end

	local span = nextRank.xpToReach - current.xpToReach
	if span <= 0 then
		return baseLevel
	end

	local progress = (xp - current.xpToReach) / span
	local levelsIn = math.floor(progress * RankConfig.LevelsPerRank)
	return baseLevel + levelsIn
end

return RankConfig
