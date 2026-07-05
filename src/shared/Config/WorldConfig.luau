--!strict

local RankConfig = require(script.Parent.RankConfig)
type RankName = RankConfig.RankName

export type WorldTheme = {
	groundColor: Color3,
	groundMaterial: Enum.Material,
	accentColor: Color3, -- pillar caps, monument orb, stand tier ceiling color
	obbyColor: Color3,
	obbyMaterial: Enum.Material,
	skyAmbient: Color3,
	fogEnd: number,
}

export type WorldInfo = {
	id: string,
	order: number,
	displayName: string,
	requiredRank: RankName,
	requiredLevel: number, -- absolute level (see RankConfig.getLevelForXp) needed to enter
	placeId: number, -- fill in with the real Place ID once created in Studio (Game Settings > Places)
	xpMultiplier: number, -- additional world-specific multiplier, stacks with rank multiplier
	description: string,
	theme: WorldTheme, -- used by WorldBuilderService to make each world actually look distinct
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
		theme = {
			groundColor = Color3.fromRGB(100, 100, 108),
			groundMaterial = Enum.Material.Slate,
			accentColor = Color3.fromRGB(150, 150, 150),
			obbyColor = Color3.fromRGB(150, 110, 70),
			obbyMaterial = Enum.Material.Wood,
			skyAmbient = Color3.fromRGB(199, 199, 214),
			fogEnd = 100000,
		},
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
		theme = {
			groundColor = Color3.fromRGB(110, 108, 100),
			groundMaterial = Enum.Material.Rock,
			accentColor = Color3.fromRGB(160, 155, 140),
			obbyColor = Color3.fromRGB(140, 120, 90),
			obbyMaterial = Enum.Material.WoodPlanks,
			skyAmbient = Color3.fromRGB(190, 185, 170),
			fogEnd = 100000,
		},
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
		theme = {
			groundColor = Color3.fromRGB(70, 130, 90),
			groundMaterial = Enum.Material.Grass,
			accentColor = Color3.fromRGB(90, 200, 120),
			obbyColor = Color3.fromRGB(80, 150, 95),
			obbyMaterial = Enum.Material.LeafyGrass,
			skyAmbient = Color3.fromRGB(190, 220, 195),
			fogEnd = 100000,
		},
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
		theme = {
			groundColor = Color3.fromRGB(80, 140, 130),
			groundMaterial = Enum.Material.Concrete,
			accentColor = Color3.fromRGB(90, 200, 170),
			obbyColor = Color3.fromRGB(90, 150, 140),
			obbyMaterial = Enum.Material.Wood,
			skyAmbient = Color3.fromRGB(180, 210, 210),
			fogEnd = 100000,
		},
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
		theme = {
			groundColor = Color3.fromRGB(90, 140, 200),
			groundMaterial = Enum.Material.Ice,
			accentColor = Color3.fromRGB(110, 170, 250),
			obbyColor = Color3.fromRGB(120, 180, 240),
			obbyMaterial = Enum.Material.Glass,
			skyAmbient = Color3.fromRGB(180, 205, 235),
			fogEnd = 100000,
		},
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
		theme = {
			groundColor = Color3.fromRGB(140, 100, 190),
			groundMaterial = Enum.Material.Marble,
			accentColor = Color3.fromRGB(180, 110, 240),
			obbyColor = Color3.fromRGB(160, 110, 220),
			obbyMaterial = Enum.Material.Marble,
			skyAmbient = Color3.fromRGB(210, 190, 230),
			fogEnd = 100000,
		},
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
		theme = {
			groundColor = Color3.fromRGB(215, 215, 225),
			groundMaterial = Enum.Material.Marble,
			accentColor = Color3.fromRGB(230, 190, 60),
			obbyColor = Color3.fromRGB(220, 190, 100),
			obbyMaterial = Enum.Material.Marble,
			skyAmbient = Color3.fromRGB(235, 220, 190),
			fogEnd = 120000,
		},
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
		theme = {
			groundColor = Color3.fromRGB(200, 230, 235),
			groundMaterial = Enum.Material.Glass,
			accentColor = Color3.fromRGB(90, 210, 230),
			obbyColor = Color3.fromRGB(150, 220, 230),
			obbyMaterial = Enum.Material.Neon,
			skyAmbient = Color3.fromRGB(210, 235, 240),
			fogEnd = 140000,
		},
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
		theme = {
			groundColor = Color3.fromRGB(245, 235, 250),
			groundMaterial = Enum.Material.Marble,
			accentColor = Color3.fromRGB(255, 215, 255),
			obbyColor = Color3.fromRGB(240, 220, 255),
			obbyMaterial = Enum.Material.Neon,
			skyAmbient = Color3.fromRGB(230, 220, 245),
			fogEnd = 160000,
		},
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
		theme = {
			groundColor = Color3.fromRGB(250, 240, 255),
			groundMaterial = Enum.Material.Marble,
			accentColor = Color3.fromRGB(255, 225, 255),
			obbyColor = Color3.fromRGB(250, 230, 255),
			obbyMaterial = Enum.Material.Neon,
			skyAmbient = Color3.fromRGB(240, 225, 250),
			fogEnd = 180000,
		},
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
