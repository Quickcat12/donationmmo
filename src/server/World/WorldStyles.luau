--!strict
-- The visual language of each world. One island layout, re-dressed per social class so
-- every promotion lands somewhere that is obviously a step up:
--
--   Gray       weathered stone and wood, plain daylight         (approachable, humble)
--   Green      gardens, brick, warm brass, richer greens         (nicer, more alive)
--   Blue       slate and glass, crisp sky, cool accent light     (premium)
--   Purple     dusk, flower gardens, lilac marble, gold accents  (beautiful)
--   Gold       white marble, gold trim, colonnades, golden hour  (luxury)
--   Diamond    night, crystal spires, reflective glass, ice      (expensive effects)
--   Celestial  floating island above the clouds, starfield sky   (monumental)
--
-- Rule of thumb when tuning: nothing a lower world has may look better than the same
-- thing in the world above it. Gray must never borrow gold, marble, glass or neon.

export type RoleLook = { material: Enum.Material, color: Color3, transparency: number? }

export type Style = {
	id: string,
	archText: string,
	-- Lighting
	clockTime: number,
	brightness: number,
	ambient: Color3,
	outdoorAmbient: Color3,
	atmosphere: { density: number, offset: number, color: Color3, decay: Color3, glare: number, haze: number },
	bloom: { intensity: number, size: number, threshold: number },
	grade: { saturation: number, contrast: number, tint: Color3 },
	sunRays: number,
	starCount: number,
	cloudCover: number,
	cloudColor: Color3,
	-- Terrain
	floating: boolean, -- no ocean: the island hangs in the sky
	terrainColors: { [Enum.Material]: Color3 },
	pathMaterial: Enum.Material,
	water: { color: Color3, transparency: number, reflectance: number },
	-- Built palette (primitive parts)
	palette: { [string]: Color3 },
	paving: Enum.Material,
	pavingColor: Color3,
	inlay: Enum.Material,
	inlayColor: Color3,
	trimMaterial: Enum.Material,
	plazaRadius: number,
	-- Imported Blender props are re-skinned per world by role name.
	roleLooks: { [string]: RoleLook },
	-- Dressing
	decor: string, -- "palms" | "columns" | "crystals" | "orbs"
	features: { [string]: boolean },
}

local M = Enum.Material

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local GRAY: Style = {
	id = "gray_plaza",
	archText = "GRAY PLAZA  ·  WORLD 1",
	clockTime = 15.2,
	brightness = 2.6,
	ambient = rgb(88, 90, 100),
	outdoorAmbient = rgb(128, 130, 140),
	atmosphere = { density = 0.27, offset = 0.15, color = rgb(200, 214, 228), decay = rgb(110, 128, 150), glare = 0.25, haze = 1.4 },
	bloom = { intensity = 0.5, size = 26, threshold = 1.6 },
	grade = { saturation = 0.06, contrast = 0.06, tint = rgb(255, 251, 244) },
	sunRays = 0.05,
	starCount = 3000,
	cloudCover = 0.55,
	cloudColor = rgb(240, 240, 245),
	floating = false,
	terrainColors = {
		[M.Grass] = rgb(104, 132, 70),
		[M.LeafyGrass] = rgb(92, 120, 62),
		[M.Sand] = rgb(212, 196, 156),
		[M.Cobblestone] = rgb(150, 146, 138),
		[M.Rock] = rgb(118, 114, 106),
		[M.Ground] = rgb(120, 106, 82),
		[M.Pavement] = rgb(170, 168, 162),
	},
	pathMaterial = M.Cobblestone,
	water = { color = rgb(38, 118, 128), transparency = 0.45, reflectance = 0.6 },
	palette = {
		stone = rgb(150, 148, 142),
		stoneDark = rgb(108, 106, 102),
		stoneLight = rgb(190, 187, 180),
		wood = rgb(122, 92, 64),
		woodDark = rgb(86, 64, 46),
		canvas = rgb(226, 222, 212),
		canvasStripe = rgb(128, 132, 140),
		iron = rgb(52, 52, 56),
		lampGlow = rgb(255, 196, 120),
		water = rgb(70, 150, 170),
		rock = rgb(112, 108, 100),
		leaf = rgb(76, 118, 58),
		trunk = rgb(116, 90, 62),
		accent = rgb(150, 150, 150),
	},
	paving = M.Pavement,
	pavingColor = rgb(190, 187, 180),
	inlay = M.Slate,
	inlayColor = rgb(108, 106, 102),
	trimMaterial = M.Slate,
	plazaRadius = 60,
	roleLooks = {},
	decor = "palms",
	features = {},
}

-- Builds a style from Gray plus overrides; nested tables replace wholesale.
local function derive(overrides: { [string]: any }): Style
	local style = table.clone(GRAY) :: any
	for key, value in overrides do
		style[key] = value
	end
	style.palette = table.clone(GRAY.palette)
	for key, value in overrides.palette or {} do
		style.palette[key] = value
	end
	style.terrainColors = table.clone(GRAY.terrainColors)
	for key, value in overrides.terrainColors or {} do
		style.terrainColors[key] = value
	end
	return style :: Style
end

local GRAY_OUTSKIRTS = derive({
	id = "gray_outskirts",
	archText = "GRAY OUTSKIRTS  ·  WORLD 2",
	clockTime = 17.2,
	ambient = rgb(96, 88, 84),
	outdoorAmbient = rgb(140, 124, 112),
	atmosphere = { density = 0.32, offset = 0.12, color = rgb(232, 206, 176), decay = rgb(150, 118, 96), glare = 0.4, haze = 1.8 },
	grade = { saturation = 0.08, contrast = 0.08, tint = rgb(255, 240, 222) },
	sunRays = 0.09,
	palette = { canvas = rgb(214, 200, 176), canvasStripe = rgb(140, 112, 84) },
	features = { extraRocks = true },
})

local GREEN_DISTRICT = derive({
	id = "green_district",
	archText = "GREEN DISTRICT  ·  WORLD 3",
	clockTime = 13.5,
	brightness = 2.9,
	ambient = rgb(92, 100, 92),
	outdoorAmbient = rgb(132, 146, 132),
	atmosphere = { density = 0.24, offset = 0.18, color = rgb(206, 226, 214), decay = rgb(112, 140, 126), glare = 0.2, haze = 1.2 },
	grade = { saturation = 0.14, contrast = 0.07, tint = rgb(250, 255, 246) },
	terrainColors = {
		[M.Grass] = rgb(86, 142, 64),
		[M.LeafyGrass] = rgb(70, 128, 56),
		[M.Pavement] = rgb(168, 112, 88),
	},
	pathMaterial = M.Pavement,
	palette = {
		canvas = rgb(238, 232, 210),
		canvasStripe = rgb(66, 140, 86),
		iron = rgb(150, 116, 60), -- brass
		lampGlow = rgb(255, 214, 150),
		leaf = rgb(70, 132, 54),
		accent = rgb(90, 200, 110),
	},
	paving = M.Brick,
	pavingColor = rgb(176, 112, 90),
	inlay = M.Slate,
	inlayColor = rgb(90, 110, 84),
	plazaRadius = 64,
	roleLooks = {
		Stripe = { material = M.Fabric, color = rgb(66, 140, 86) },
		Canvas = { material = M.Fabric, color = rgb(238, 232, 210) },
		Iron = { material = M.Metal, color = rgb(150, 116, 60) },
		Fronds = { material = M.SmoothPlastic, color = rgb(70, 140, 56) },
	},
	features = { hedges = true, flowers = true },
})

local GREEN_HARBOR = derive({
	id = "green_harbor",
	archText = "GREEN HARBOR  ·  WORLD 4",
	clockTime = 16.2,
	brightness = 2.9,
	atmosphere = { density = 0.22, offset = 0.2, color = rgb(200, 228, 226), decay = rgb(100, 140, 140), glare = 0.3, haze = 1.1 },
	grade = { saturation = 0.15, contrast = 0.08, tint = rgb(246, 255, 252) },
	terrainColors = {
		[M.Grass] = rgb(84, 140, 70),
		[M.LeafyGrass] = rgb(72, 128, 60),
		[M.Sand] = rgb(226, 212, 172),
		[M.Pavement] = rgb(196, 192, 182),
	},
	pathMaterial = M.Pavement,
	water = { color = rgb(30, 140, 140), transparency = 0.55, reflectance = 0.7 },
	palette = {
		canvas = rgb(240, 240, 232),
		canvasStripe = rgb(46, 146, 140),
		iron = rgb(150, 116, 60),
		lampGlow = rgb(255, 220, 160),
		accent = rgb(90, 200, 170),
	},
	paving = M.Concrete,
	pavingColor = rgb(214, 210, 200),
	inlay = M.Brick,
	inlayColor = rgb(120, 140, 132),
	plazaRadius = 64,
	roleLooks = {
		Stripe = { material = M.Fabric, color = rgb(46, 146, 140) },
		Canvas = { material = M.Fabric, color = rgb(240, 240, 232) },
		Iron = { material = M.Metal, color = rgb(150, 116, 60) },
		Red = { material = M.Concrete, color = rgb(46, 140, 130) },
	},
	features = { hedges = true, extraBoats = true },
})

local BLUE_HEIGHTS = derive({
	id = "blue_heights",
	archText = "BLUE HEIGHTS  ·  WORLD 5",
	clockTime = 14.2,
	brightness = 3.1,
	ambient = rgb(90, 98, 116),
	outdoorAmbient = rgb(130, 144, 170),
	atmosphere = { density = 0.18, offset = 0.25, color = rgb(196, 214, 244), decay = rgb(92, 120, 170), glare = 0.15, haze = 0.7 },
	bloom = { intensity = 0.7, size = 28, threshold = 1.4 },
	grade = { saturation = 0.12, contrast = 0.1, tint = rgb(244, 250, 255) },
	terrainColors = {
		[M.Grass] = rgb(80, 132, 82),
		[M.Pavement] = rgb(120, 132, 150),
	},
	pathMaterial = M.Pavement,
	water = { color = rgb(30, 100, 170), transparency = 0.55, reflectance = 0.8 },
	palette = {
		canvas = rgb(244, 246, 252),
		canvasStripe = rgb(40, 82, 160),
		iron = rgb(70, 80, 100),
		lampGlow = rgb(210, 230, 255),
		stoneLight = rgb(176, 186, 204),
		stone = rgb(130, 140, 160),
		stoneDark = rgb(70, 80, 104),
		accent = rgb(80, 160, 250),
	},
	paving = M.Slate,
	pavingColor = rgb(132, 144, 168),
	inlay = M.Glass,
	inlayColor = rgb(80, 150, 240),
	trimMaterial = M.Glass,
	plazaRadius = 66,
	roleLooks = {
		Stripe = { material = M.Fabric, color = rgb(40, 82, 160) },
		Canvas = { material = M.Fabric, color = rgb(244, 246, 252) },
		Stone = { material = M.Slate, color = rgb(176, 186, 204) },
		Trim = { material = M.Glass, color = rgb(80, 150, 240) },
		Iron = { material = M.Metal, color = rgb(70, 80, 100) },
		Glow = { material = M.Neon, color = rgb(200, 226, 255) },
		Red = { material = M.Concrete, color = rgb(40, 82, 160) },
	},
	features = { hedges = true, accentStrips = true },
})

local PURPLE_GARDENS = derive({
	id = "purple_gardens",
	archText = "PURPLE GARDENS  ·  WORLD 6",
	clockTime = 18.1,
	brightness = 2.4,
	ambient = rgb(104, 88, 120),
	outdoorAmbient = rgb(150, 120, 170),
	atmosphere = { density = 0.3, offset = 0.12, color = rgb(232, 196, 230), decay = rgb(140, 96, 160), glare = 0.5, haze = 1.6 },
	bloom = { intensity = 0.9, size = 30, threshold = 1.3 },
	grade = { saturation = 0.16, contrast = 0.08, tint = rgb(255, 242, 252) },
	sunRays = 0.12,
	terrainColors = {
		[M.Grass] = rgb(76, 122, 70),
		[M.LeafyGrass] = rgb(96, 110, 70),
		[M.Pavement] = rgb(206, 194, 214),
	},
	pathMaterial = M.Pavement,
	water = { color = rgb(80, 90, 160), transparency = 0.5, reflectance = 0.8 },
	palette = {
		canvas = rgb(246, 238, 250),
		canvasStripe = rgb(130, 70, 190),
		iron = rgb(190, 150, 70),
		lampGlow = rgb(255, 196, 236),
		stoneLight = rgb(226, 216, 234),
		stone = rgb(196, 182, 210),
		stoneDark = rgb(130, 100, 160),
		accent = rgb(180, 110, 240),
	},
	paving = M.Marble,
	pavingColor = rgb(226, 216, 234),
	inlay = M.Marble,
	inlayColor = rgb(150, 100, 190),
	trimMaterial = M.Marble,
	plazaRadius = 68,
	roleLooks = {
		Stripe = { material = M.Fabric, color = rgb(130, 70, 190) },
		Canvas = { material = M.Fabric, color = rgb(246, 238, 250) },
		Stone = { material = M.Marble, color = rgb(232, 224, 240) },
		Trim = { material = M.Metal, color = rgb(200, 160, 80) },
		Iron = { material = M.Metal, color = rgb(190, 150, 70) },
		Glow = { material = M.Neon, color = rgb(255, 190, 236) },
		Red = { material = M.Marble, color = rgb(150, 100, 190) },
		Fronds = { material = M.SmoothPlastic, color = rgb(90, 140, 80) },
	},
	features = { hedges = true, flowers = true, colonnade = false },
})

local GOLD_QUARTER = derive({
	id = "gold_quarter",
	archText = "GOLD QUARTER  ·  WORLD 7",
	clockTime = 17.4,
	brightness = 2.8,
	ambient = rgb(112, 100, 84),
	outdoorAmbient = rgb(170, 150, 120),
	atmosphere = { density = 0.26, offset = 0.14, color = rgb(244, 222, 184), decay = rgb(170, 130, 80), glare = 0.6, haze = 1.5 },
	bloom = { intensity = 1.0, size = 32, threshold = 1.25 },
	grade = { saturation = 0.12, contrast = 0.1, tint = rgb(255, 246, 228) },
	sunRays = 0.14,
	terrainColors = {
		[M.Grass] = rgb(70, 112, 60),
		[M.LeafyGrass] = rgb(62, 104, 54),
		[M.Sand] = rgb(236, 226, 200),
		[M.Pavement] = rgb(236, 232, 224),
	},
	pathMaterial = M.Pavement,
	water = { color = rgb(40, 120, 150), transparency = 0.55, reflectance = 0.85 },
	palette = {
		canvas = rgb(250, 248, 242),
		canvasStripe = rgb(212, 172, 72),
		iron = rgb(212, 172, 72),
		lampGlow = rgb(255, 214, 140),
		wood = rgb(240, 236, 228),
		woodDark = rgb(226, 220, 208),
		stoneLight = rgb(244, 242, 236),
		stone = rgb(232, 228, 220),
		stoneDark = rgb(206, 170, 80),
		accent = rgb(230, 190, 60),
	},
	paving = M.Marble,
	pavingColor = rgb(244, 242, 236),
	inlay = M.Foil,
	inlayColor = rgb(214, 174, 70),
	trimMaterial = M.Foil,
	plazaRadius = 70,
	roleLooks = {
		Stripe = { material = M.Fabric, color = rgb(212, 172, 72) },
		Canvas = { material = M.Fabric, color = rgb(250, 248, 242) },
		Stone = { material = M.Marble, color = rgb(244, 242, 236) },
		Trim = { material = M.Foil, color = rgb(214, 174, 70) },
		Iron = { material = M.Foil, color = rgb(214, 174, 70) },
		Metal = { material = M.Foil, color = rgb(214, 174, 70) },
		Wood = { material = M.Marble, color = rgb(240, 236, 228) },
		WoodDark = { material = M.Marble, color = rgb(226, 220, 208) },
		White = { material = M.Marble, color = rgb(244, 242, 236) },
		Red = { material = M.Foil, color = rgb(214, 174, 70) },
		Glow = { material = M.Neon, color = rgb(255, 210, 120) },
	},
	decor = "columns",
	features = { hedges = true, colonnade = true },
})

local DIAMOND_REALM = derive({
	id = "diamond_realm",
	archText = "DIAMOND REALM  ·  WORLD 8",
	clockTime = 20.6,
	brightness = 1.6,
	ambient = rgb(90, 110, 130),
	outdoorAmbient = rgb(110, 140, 170),
	atmosphere = { density = 0.3, offset = 0.2, color = rgb(150, 200, 230), decay = rgb(60, 110, 160), glare = 0.2, haze = 1.6 },
	bloom = { intensity = 1.3, size = 34, threshold = 1.05 },
	grade = { saturation = 0.18, contrast = 0.12, tint = rgb(236, 250, 255) },
	starCount = 5000,
	cloudCover = 0.4,
	cloudColor = rgb(170, 200, 230),
	terrainColors = {
		[M.Grass] = rgb(60, 110, 100),
		[M.LeafyGrass] = rgb(54, 100, 96),
		[M.Sand] = rgb(226, 238, 244),
		[M.Rock] = rgb(150, 176, 196),
		[M.Pavement] = rgb(200, 226, 236),
		[M.Glacier] = rgb(170, 220, 240),
	},
	pathMaterial = M.Glacier,
	water = { color = rgb(40, 170, 200), transparency = 0.6, reflectance = 1 },
	palette = {
		canvas = rgb(240, 250, 255),
		canvasStripe = rgb(90, 210, 230),
		iron = rgb(200, 220, 230),
		lampGlow = rgb(170, 240, 255),
		wood = rgb(220, 236, 244),
		woodDark = rgb(180, 210, 226),
		stoneLight = rgb(220, 240, 248),
		stone = rgb(190, 220, 236),
		stoneDark = rgb(90, 180, 210),
		accent = rgb(90, 210, 230),
	},
	paving = M.Glass,
	pavingColor = rgb(200, 232, 244),
	inlay = M.Neon,
	inlayColor = rgb(90, 210, 230),
	trimMaterial = M.Glass,
	plazaRadius = 72,
	roleLooks = {
		Stripe = { material = M.Glass, color = rgb(90, 210, 230) },
		Canvas = { material = M.Fabric, color = rgb(240, 250, 255) },
		Stone = { material = M.Glass, color = rgb(210, 236, 248) },
		Trim = { material = M.Neon, color = rgb(90, 210, 230) },
		Iron = { material = M.Metal, color = rgb(200, 220, 230) },
		Metal = { material = M.Metal, color = rgb(200, 220, 230) },
		Wood = { material = M.Glass, color = rgb(210, 236, 248) },
		WoodDark = { material = M.Glass, color = rgb(180, 220, 240) },
		White = { material = M.Glass, color = rgb(220, 240, 250) },
		Red = { material = M.Neon, color = rgb(90, 210, 230) },
		Glow = { material = M.Neon, color = rgb(170, 240, 255) },
		Rock = { material = M.Glacier, color = rgb(170, 210, 230) },
	},
	decor = "crystals",
	features = { crystals = true, accentStrips = true },
})

local CELESTIAL_SUMMIT = derive({
	id = "celestial_summit",
	archText = "CELESTIAL SUMMIT  ·  WORLD 9",
	clockTime = 0.5,
	brightness = 1.2,
	ambient = rgb(120, 100, 150),
	outdoorAmbient = rgb(150, 130, 190),
	atmosphere = { density = 0.32, offset = 0.0, color = rgb(190, 150, 230), decay = rgb(110, 70, 170), glare = 0.6, haze = 2.2 },
	bloom = { intensity = 1.5, size = 40, threshold = 0.95 },
	grade = { saturation = 0.22, contrast = 0.12, tint = rgb(248, 236, 255) },
	starCount = 5000,
	cloudCover = 0.75,
	cloudColor = rgb(200, 170, 240),
	floating = true,
	terrainColors = {
		[M.Grass] = rgb(110, 150, 120),
		[M.LeafyGrass] = rgb(140, 120, 170),
		[M.Rock] = rgb(150, 136, 176),
		[M.Pavement] = rgb(244, 236, 250),
		[M.Salt] = rgb(250, 244, 255),
		[M.Sand] = rgb(222, 212, 238), -- cloud-pale shore, not beach tan
	},
	pathMaterial = M.Salt,
	palette = {
		canvas = rgb(252, 248, 255),
		canvasStripe = rgb(210, 170, 250),
		iron = rgb(240, 220, 255),
		lampGlow = rgb(240, 200, 255),
		wood = rgb(246, 240, 252),
		woodDark = rgb(226, 214, 240),
		stoneLight = rgb(250, 246, 255),
		stone = rgb(236, 228, 248),
		stoneDark = rgb(200, 160, 250),
		accent = rgb(255, 215, 255),
		rock = rgb(150, 136, 176),
	},
	paving = M.Marble,
	pavingColor = rgb(250, 246, 255),
	inlay = M.Neon,
	inlayColor = rgb(220, 170, 255),
	trimMaterial = M.Neon,
	plazaRadius = 74,
	roleLooks = {
		Stripe = { material = M.Neon, color = rgb(220, 180, 255) },
		Canvas = { material = M.Fabric, color = rgb(252, 248, 255) },
		Stone = { material = M.Marble, color = rgb(250, 246, 255) },
		Trim = { material = M.Neon, color = rgb(230, 190, 255) },
		Iron = { material = M.Foil, color = rgb(240, 220, 255) },
		Metal = { material = M.Foil, color = rgb(240, 220, 255) },
		Wood = { material = M.Marble, color = rgb(246, 240, 252) },
		WoodDark = { material = M.Marble, color = rgb(226, 214, 240) },
		White = { material = M.Marble, color = rgb(250, 246, 255) },
		Red = { material = M.Neon, color = rgb(220, 170, 255) },
		Glow = { material = M.Neon, color = rgb(255, 220, 255) },
		Rock = { material = M.Slate, color = rgb(150, 136, 176) },
	},
	decor = "orbs",
	features = { monument = true, floatingRocks = true, colonnade = true },
})

local CELESTIAL_APEX = derive({
	id = "celestial_apex",
	archText = "CELESTIAL APEX  ·  WORLD 10",
	clockTime = 23.4,
	brightness = 1.3,
	atmosphere = { density = 0.34, offset = 0.0, color = rgb(250, 200, 230), decay = rgb(170, 90, 160), glare = 0.8, haze = 2.4 },
	bloom = { intensity = 1.7, size = 44, threshold = 0.9 },
	grade = { saturation = 0.24, contrast = 0.14, tint = rgb(255, 240, 250) },
	starCount = 5000,
	cloudCover = 0.8,
	cloudColor = rgb(240, 190, 230),
	floating = true,
	terrainColors = CELESTIAL_SUMMIT.terrainColors,
	pathMaterial = M.Salt,
	palette = {
		canvas = rgb(255, 250, 246),
		canvasStripe = rgb(255, 210, 120),
		iron = rgb(255, 220, 140),
		lampGlow = rgb(255, 220, 180),
		wood = rgb(255, 250, 246),
		woodDark = rgb(240, 230, 226),
		stoneLight = rgb(255, 252, 248),
		stone = rgb(244, 236, 236),
		stoneDark = rgb(255, 200, 110),
		accent = rgb(255, 225, 255),
		rock = rgb(160, 130, 160),
	},
	paving = M.Marble,
	pavingColor = rgb(255, 252, 248),
	inlay = M.Foil,
	inlayColor = rgb(255, 205, 110),
	trimMaterial = M.Neon,
	plazaRadius = 76,
	roleLooks = {
		Stripe = { material = M.Foil, color = rgb(255, 205, 110) },
		Canvas = { material = M.Fabric, color = rgb(255, 250, 246) },
		Stone = { material = M.Marble, color = rgb(255, 252, 248) },
		Trim = { material = M.Foil, color = rgb(255, 205, 110) },
		Iron = { material = M.Foil, color = rgb(255, 210, 120) },
		Metal = { material = M.Foil, color = rgb(255, 210, 120) },
		Wood = { material = M.Marble, color = rgb(255, 250, 246) },
		WoodDark = { material = M.Marble, color = rgb(240, 230, 226) },
		White = { material = M.Marble, color = rgb(255, 252, 248) },
		Red = { material = M.Foil, color = rgb(255, 205, 110) },
		Glow = { material = M.Neon, color = rgb(255, 230, 200) },
		Rock = { material = M.Slate, color = rgb(160, 130, 160) },
	},
	decor = "orbs",
	features = { monument = true, floatingRocks = true, colonnade = true },
})

local WorldStyles = {}

WorldStyles.ById = {
	gray_plaza = GRAY,
	gray_outskirts = GRAY_OUTSKIRTS,
	green_district = GREEN_DISTRICT,
	green_harbor = GREEN_HARBOR,
	blue_heights = BLUE_HEIGHTS,
	purple_gardens = PURPLE_GARDENS,
	gold_quarter = GOLD_QUARTER,
	diamond_realm = DIAMOND_REALM,
	celestial_summit = CELESTIAL_SUMMIT,
	celestial_apex = CELESTIAL_APEX,
} :: { [string]: Style }

function WorldStyles.get(worldId: string): Style
	return WorldStyles.ById[worldId] or GRAY
end

return WorldStyles
