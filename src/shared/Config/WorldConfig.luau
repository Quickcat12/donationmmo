--!strict

local RankConfig = require(script.Parent.RankConfig)
type RankName = RankConfig.RankName

export type WorldInfo = {
	id: string,
	order: number,
	displayName: string,
	requiredRank: RankName,
	requiredLevel: number, -- absolute level (see RankConfig.getLevelForXp) needed to enter
	placeId: number, -- fill in with the real Place ID once created in Studio (Game Settings > Places)
	xpMultiplier: number, -- additional world-specific multiplier, stacks with rank multiplier
	description: string,
}

local WorldConfig = {}

-- IMPORTANT: placeId = 0 is a placeholder. Create each world as a separate Place inside
-- this experience (Studio > Game Settings > Places > Create Place), then paste the real
-- Place ID here before enabling cross-world teleports.
WorldConfig.Worlds = {
	{
		id = "gray_plaza",
		order = 1,
		displayName = "Gray Plaza",
		requiredRank = "Gray",
		requiredLevel = 1,
		placeId = 0,
		xpMultiplier = 1.0,
		description = "Simple architecture, starter stands, beginner activities.",
	},
	{
		id = "gray_outskirts",
		order = 2,
		displayName = "Gray Outskirts",
		requiredRank = "Gray",
		requiredLevel = 13,
		placeId = 0,
		xpMultiplier = 1.05,
		description = "The edge of the starting zone, tougher obbies and better starter rewards.",
	},
	{
		id = "green_district",
		order = 3,
		displayName = "Green District",
		requiredRank = "Green",
		requiredLevel = 26,
		placeId = 0,
		xpMultiplier = 1.1,
		description = "Improved visuals, larger gathering spaces, upgraded rewards.",
	},
	{
		id = "green_harbor",
		order = 4,
		displayName = "Green Harbor",
		requiredRank = "Green",
		requiredLevel = 38,
		placeId = 0,
		xpMultiplier = 1.15,
		description = "A bustling harbor district with expanded donation stands.",
	},
	{
		id = "blue_heights",
		order = 5,
		displayName = "Blue Heights",
		requiredRank = "Blue",
		requiredLevel = 51,
		placeId = 0,
		xpMultiplier = 1.3,
		description = "More advanced stand customization, improved XP opportunities, premium aesthetics.",
	},
	{
		id = "purple_gardens",
		order = 6,
		displayName = "Purple Gardens",
		requiredRank = "Purple",
		requiredLevel = 76,
		placeId = 0,
		xpMultiplier = 1.5,
		description = "Beautiful architecture, enhanced social spaces, exclusive cosmetics.",
	},
	{
		id = "gold_quarter",
		order = 7,
		displayName = "Gold Quarter",
		requiredRank = "Gold",
		requiredLevel = 101,
		placeId = 0,
		xpMultiplier = 1.75,
		description = "Luxury buildings, marble pathways, animated environments, elite status.",
	},
	{
		id = "diamond_realm",
		order = 8,
		displayName = "Diamond Realm",
		requiredRank = "Diamond",
		requiredLevel = 126,
		placeId = 0,
		xpMultiplier = 2.0,
		description = "Massive plazas, advanced visual effects, highly prestigious players.",
	},
	{
		id = "celestial_summit",
		order = 9,
		displayName = "Celestial Summit",
		requiredRank = "Celestial",
		requiredLevel = 151,
		placeId = 0,
		xpMultiplier = 2.4,
		description = "The pinnacle of progression, featuring the most exclusive content available.",
	},
	{
		id = "celestial_apex",
		order = 10,
		displayName = "Celestial Apex",
		requiredRank = "Celestial",
		requiredLevel = 175,
		placeId = 0,
		xpMultiplier = 2.75,
		description = "Endgame prestige world for top-ranked players. Always expanding.",
	},
} :: { WorldInfo }

function WorldConfig.getWorldById(id: string): WorldInfo?
	for _, world in WorldConfig.Worlds do
		if world.id == id then
			return world
		end
	end
	return nil
end

-- Returns true if a player's absolute level meets a world's entry requirement.
function WorldConfig.canEnter(world: WorldInfo, playerLevel: number): boolean
	return playerLevel >= world.requiredLevel
end

function WorldConfig.getHighestUnlockedWorld(playerLevel: number): WorldInfo
	local highest = WorldConfig.Worlds[1]
	for _, world in WorldConfig.Worlds do
		if playerLevel >= world.requiredLevel then
			highest = world
		else
			break
		end
	end
	return highest
end

return WorldConfig
