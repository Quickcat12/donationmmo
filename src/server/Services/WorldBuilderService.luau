--!strict
-- Procedurally builds a basic playable plaza directly into Workspace at server start,
-- since Rojo doesn't manage Workspace in this project (no $path is mapped to it in
-- default.project.json) - there's no conflict with hand-placed Studio content.
--
-- This is deliberately simple "programmer art" (blocky parts, flat colors) so the game
-- is actually testable end-to-end. Replacing this with real 3D art/architecture in
-- Studio is still the long-term plan - see the design doc's per-world descriptions.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage").Shared
local RankConfig = require(Shared.Config.RankConfig)
local WorldConfig = require(Shared.Config.WorldConfig)

local STAND_TAG = "DonationStand"
local OBBY_FINISH_TAG = "ObbyFinish"
local CHECKPOINT_TAG = "ObbyCheckpoint"
local TELEPORTER_PROMPT_TAG = "WorldTeleporterPrompt"
local PRESTIGE_TAG = "PrestigeStand"
local STAND_COUNT = 16
local PLAZA_RADIUS = 90

-- Resolves which world this server instance represents, same pattern as
-- XPService.currentWorldMultiplier / WorldPopulationService.currentWorldId - falls back
-- to the first/base world's theme during local testing or before real Place IDs exist
-- (all placeholders are still 0), so every world doesn't just look like flat gray stone.
local currentTheme = WorldConfig.Worlds[1].theme
do
	for _, world in WorldConfig.Worlds do
		if world.placeId ~= 0 and world.placeId == game.PlaceId then
			currentTheme = world.theme
			break
		end
	end
end

-- The whole plaza floats high above the baseplate. Falling off anywhere on the map
-- (plaza or obby) means a long drop - Workspace.FallenPartsDestroyHeight (set in
-- build() below) destroys anyone who falls below WorldBuilderService.KillY. That's a
-- native engine property, not a polling script: when a character's parts get destroyed
-- this way, the Humanoid loses its HumanoidRootPart and transitions to Dead, which
-- fires the normal death/respawn flow exactly like any other death would.
local WORLD_Y = 500

local WorldBuilderService = {}
WorldBuilderService.WorldY = WORLD_Y
WorldBuilderService.KillY = WORLD_Y - 60

local function clearExisting()
	local existing = Workspace:FindFirstChild("GeneratedWorld")
	if existing then
		existing:Destroy()
	end
end

local function setupAtmosphere()
	local existingAtmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if existingAtmosphere then
		existingAtmosphere:Destroy()
	end

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.25
	atmosphere.Color = currentTheme.skyAmbient
	atmosphere.Decay = Color3.fromRGB(92, 102, 120)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting

	Lighting.Brightness = 3
	Lighting.FogEnd = currentTheme.fogEnd
end

local function buildFloor(parent: Instance)
	-- Outer plaza floor.
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = Vector3.new(2 * PLAZA_RADIUS + 60, 4, 2 * PLAZA_RADIUS + 60)
	floor.CFrame = CFrame.new(0, WORLD_Y - 2, 0)
	floor.Material = currentTheme.groundMaterial
	floor.Color = currentTheme.groundColor
	floor.Parent = parent

	-- Inner arena ring, a lighter material to frame the stand circle.
	local arena = Instance.new("Part")
	arena.Name = "Arena"
	arena.Shape = Enum.PartType.Cylinder
	arena.Anchored = true
	arena.Size = Vector3.new(3, PLAZA_RADIUS * 1.7, PLAZA_RADIUS * 1.7)
	arena.CFrame = CFrame.new(0, WORLD_Y - 0.4, 0) * CFrame.Angles(0, 0, math.rad(90))
	arena.Material = Enum.Material.Marble
	arena.Color = Color3.fromRGB(200, 200, 210)
	arena.Parent = parent

	-- Perimeter pillars for visual framing.
	local pillarCount = 12
	for i = 1, pillarCount do
		local angle = (i / pillarCount) * math.pi * 2
		local x = math.cos(angle) * (PLAZA_RADIUS + 35)
		local z = math.sin(angle) * (PLAZA_RADIUS + 35)

		local pillar = Instance.new("Part")
		pillar.Name = `Pillar_{i}`
		pillar.Anchored = true
		pillar.Shape = Enum.PartType.Cylinder
		pillar.Size = Vector3.new(20, 4, 4)
		pillar.CFrame = CFrame.new(x, WORLD_Y + 10, z) * CFrame.Angles(0, 0, math.rad(90))
		pillar.Material = Enum.Material.Marble
		pillar.Color = Color3.fromRGB(210, 210, 220)
		pillar.Parent = parent

		local cap = Instance.new("Part")
		cap.Name = `PillarCap_{i}`
		cap.Anchored = true
		cap.Shape = Enum.PartType.Ball
		cap.Size = Vector3.new(6, 6, 6)
		cap.CFrame = CFrame.new(x, WORLD_Y + 21, z)
		cap.Material = Enum.Material.Neon
		cap.Color = currentTheme.accentColor
		cap.Parent = parent
	end

	-- Center monument.
	local monumentBase = Instance.new("Part")
	monumentBase.Name = "MonumentBase"
	monumentBase.Anchored = true
	monumentBase.Shape = Enum.PartType.Cylinder
	monumentBase.Size = Vector3.new(6, 14, 14)
	monumentBase.CFrame = CFrame.new(0, WORLD_Y + 3, 0) * CFrame.Angles(0, 0, math.rad(90))
	monumentBase.Material = Enum.Material.Marble
	monumentBase.Color = Color3.fromRGB(215, 215, 225)
	monumentBase.Parent = parent

	local monumentOrb = Instance.new("Part")
	monumentOrb.Name = "MonumentOrb"
	monumentOrb.Anchored = true
	monumentOrb.Shape = Enum.PartType.Ball
	monumentOrb.Size = Vector3.new(10, 10, 10)
	monumentOrb.CFrame = CFrame.new(0, WORLD_Y + 12, 0)
	monumentOrb.Material = Enum.Material.Neon
	monumentOrb.Color = currentTheme.accentColor
	monumentOrb.Parent = parent

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MainSpawn"
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, WORLD_Y + 0.5, PLAZA_RADIUS + 20)
	spawn.Material = Enum.Material.Neon
	spawn.Color = Color3.fromRGB(90, 210, 120)
	spawn.Duration = 0
	spawn.Parent = parent
end

-- A large translucent sphere sitting on the floor forms a dome shield over the plaza.
local function buildDome(parent: Instance)
	local domeRadius = PLAZA_RADIUS + 70

	local dome = Instance.new("Part")
	dome.Name = "Dome"
	dome.Shape = Enum.PartType.Ball
	dome.Anchored = true
	dome.CanCollide = false
	dome.CanQuery = false
	dome.Size = Vector3.new(domeRadius * 2, domeRadius * 2, domeRadius * 2)
	dome.CFrame = CFrame.new(0, WORLD_Y, 0)
	dome.Material = Enum.Material.ForceField
	dome.Color = Color3.fromRGB(120, 190, 255)
	dome.Transparency = 0.55
	dome.Parent = parent
end

-- A physical portal near spawn that opens the world-select UI (WorldSelectController)
-- via a ProximityPrompt - a discoverable landmark for "go somewhere else" instead of
-- only a corner toggle button. Two posts, a slowly-spinning glowing disc between them,
-- and a floor pad in front.
local function buildTeleporter(parent: Instance)
	local baseZ = PLAZA_RADIUS + 45
	local postSpacing = 9

	local teleporter = Instance.new("Folder")
	teleporter.Name = "Teleporter"
	teleporter.Parent = parent

	for _, side in { -1, 1 } do
		local post = Instance.new("Part")
		post.Name = `Post_{side}`
		post.Anchored = true
		post.CanCollide = true
		post.Shape = Enum.PartType.Cylinder
		post.Size = Vector3.new(16, 3, 3)
		post.CFrame = CFrame.new(side * postSpacing, WORLD_Y + 8, baseZ) * CFrame.Angles(0, 0, math.rad(90))
		post.Material = Enum.Material.Marble
		post.Color = Color3.fromRGB(90, 70, 140)
		post.Parent = teleporter
	end

	local disc = Instance.new("Part")
	disc.Name = "PortalDisc"
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(1.5, postSpacing * 2 - 2, postSpacing * 2 - 2)
	disc.CFrame = CFrame.new(0, WORLD_Y + 8, baseZ) * CFrame.Angles(0, 0, math.rad(90))
	disc.Material = Enum.Material.Neon
	disc.Color = Color3.fromRGB(140, 100, 230)
	disc.Transparency = 0.25
	disc.Parent = teleporter

	-- A continuous spin can't be done with a single TweenService tween - tweening to a
	-- 360-degree-rotated CFrame is a no-op, since that's mathematically identical to the
	-- start orientation (shortest-path interpolation sees no rotation to perform at all).
	-- A per-frame increment is the standard way to actually get a smooth, endless spin.
	local spinSpeed = math.rad(45) -- radians per second
	task.spawn(function()
		while disc.Parent do
			local dt = RunService.Heartbeat:Wait()
			disc.CFrame = disc.CFrame * CFrame.Angles(spinSpeed * dt, 0, 0)
		end
	end)

	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = Color3.fromRGB(200, 170, 255)
	sparkles.Parent = disc

	local label = Instance.new("BillboardGui")
	label.Name = "Label"
	label.Size = UDim2.fromOffset(260, 40)
	label.StudsOffset = Vector3.new(0, postSpacing + 3, 0)
	label.AlwaysOnTop = true
	label.Parent = disc

	local labelText = Instance.new("TextLabel")
	labelText.Size = UDim2.fromScale(1, 1)
	labelText.BackgroundTransparency = 1
	labelText.Text = "Lobby Teleporter"
	labelText.Font = Enum.Font.GothamBold
	labelText.TextScaled = true
	labelText.TextColor3 = Color3.fromRGB(220, 200, 255)
	labelText.TextStrokeTransparency = 0.4
	labelText.Parent = label

	local pad = Instance.new("Part")
	pad.Name = "TeleporterPad"
	pad.Anchored = true
	pad.CanCollide = true
	pad.Size = Vector3.new(postSpacing * 2, 1, 6)
	pad.CFrame = CFrame.new(0, WORLD_Y + 0.5, baseZ - 4)
	pad.Material = Enum.Material.Marble
	pad.Color = Color3.fromRGB(120, 100, 160)
	pad.Parent = teleporter

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TeleporterPrompt"
	prompt.ActionText = "Explore Worlds"
	prompt.ObjectText = "Lobby Teleporter"
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad

	CollectionService:AddTag(prompt, TELEPORTER_PROMPT_TAG)
end

-- A physical "leaderboard" near spawn showing the server's current top lifetime donors
-- (see PrestigeStandService.luau, which keeps these updated) - a psychological focal
-- point players see the moment they spawn in, reinforcing that the richest players are
-- the visible center of attention. Read-only: donations still route to a player's own
-- regular stand regardless of whether they're currently shown here.
local function buildPrestigePedestal(index: number, totalCount: number, parent: Instance)
	local spreadX = 60
	local x = -spreadX / 2 + (index - 1) * (spreadX / (totalCount - 1))
	local z = 40
	-- The center pedestal (index 1, "#1") stands slightly taller, podium-style.
	local height = index == 1 and 6 or 4

	local pedestal = Instance.new("Model")
	pedestal.Name = `PrestigePedestal_{index}`

	local riser = Instance.new("Part")
	riser.Name = "Riser"
	riser.Anchored = true
	riser.CanCollide = true
	riser.Size = Vector3.new(7, height, 7)
	riser.CFrame = CFrame.new(x, WORLD_Y + height / 2, z)
	riser.Material = Enum.Material.Marble
	riser.Color = Color3.fromRGB(215, 215, 225)
	riser.Parent = pedestal

	local rankPlate = Instance.new("Part")
	rankPlate.Name = "RankPlate"
	rankPlate.Anchored = true
	rankPlate.CanCollide = false
	rankPlate.CanQuery = false
	rankPlate.Shape = Enum.PartType.Cylinder
	rankPlate.Size = Vector3.new(0.3, 6, 6)
	rankPlate.CFrame = CFrame.new(x, WORLD_Y + height + 0.15, z) * CFrame.Angles(0, 0, math.rad(90))
	rankPlate.Material = Enum.Material.Neon
	rankPlate.Color = Color3.fromRGB(150, 150, 150)
	rankPlate.Parent = pedestal

	local signPost = Instance.new("Part")
	signPost.Name = "SignPost"
	signPost.Anchored = true
	signPost.CanCollide = false
	signPost.Size = Vector3.new(0.4, 5, 0.4)
	signPost.CFrame = CFrame.new(x, WORLD_Y + height + 2.5, z)
	signPost.Material = Enum.Material.Metal
	signPost.Color = Color3.fromRGB(60, 60, 65)
	signPost.Parent = pedestal

	local sign = Instance.new("BillboardGui")
	sign.Name = "Sign"
	sign.Size = UDim2.fromOffset(180, 90)
	sign.StudsOffset = Vector3.new(0, 3.5, 0)
	sign.AlwaysOnTop = true
	sign.Parent = signPost

	local rankLabel = Instance.new("TextLabel")
	rankLabel.Name = "RankLabel"
	rankLabel.Size = UDim2.new(1, 0, 0, 18)
	rankLabel.BackgroundTransparency = 1
	rankLabel.Text = `#{index}`
	rankLabel.Font = Enum.Font.GothamBold
	rankLabel.TextScaled = true
	rankLabel.TextColor3 = Color3.fromRGB(230, 190, 60)
	rankLabel.Parent = sign

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 26)
	nameLabel.Position = UDim2.new(0, 0, 0, 18)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = "Unclaimed"
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
	nameLabel.Parent = sign

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, 0, 0, 20)
	titleLabel.Position = UDim2.new(0, 0, 0, 44)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = ""
	titleLabel.Font = Enum.Font.Gotham
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
	titleLabel.Parent = sign

	local amountLabel = Instance.new("TextLabel")
	amountLabel.Name = "AmountLabel"
	amountLabel.Size = UDim2.new(1, 0, 0, 20)
	amountLabel.Position = UDim2.new(0, 0, 0, 66)
	amountLabel.BackgroundTransparency = 1
	amountLabel.Text = ""
	amountLabel.Font = Enum.Font.Gotham
	amountLabel.TextScaled = true
	amountLabel.TextColor3 = Color3.fromRGB(150, 220, 160)
	amountLabel.Parent = sign

	pedestal.PrimaryPart = riser
	pedestal.Parent = parent

	CollectionService:AddTag(pedestal, PRESTIGE_TAG)
	pedestal:SetAttribute("Rank", index)
end

local function buildPrestigeShowcase(parent: Instance)
	local count = 5
	for i = 1, count do
		buildPrestigePedestal(i, count, parent)
	end
end

-- A flat glow ring at the base of the podium. Invisible at tier 1, grows more vivid as
-- the owner's rank climbs (see StandService.updateStandVisual) - stands are meant to be a
-- "visual representation of accomplishments", not just a re-tinted box.
local function buildTierRing(lookAt: CFrame, parent: Instance)
	local ring = Instance.new("Part")
	ring.Name = "TierRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Shape = Enum.PartType.Cylinder
	-- Wider than the podium ever grows (max footprint ~9.6 studs at the top tier, see
	-- StandService.updateStandVisual) so it always reads as a ring around the stand.
	ring.Size = Vector3.new(0.4, 13, 13)
	ring.CFrame = lookAt * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90))
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(150, 150, 150)
	ring.Transparency = 1
	ring.Parent = parent
	return ring
end

-- A small roof plate over the sign, hidden until the owner reaches a high enough rank to
-- "unlock" it - larger stands with premium canopies at Gold+ per the design doc.
local function buildCanopy(lookAt: CFrame, parent: Instance)
	local canopy = Instance.new("Part")
	canopy.Name = "Canopy"
	canopy.Anchored = true
	canopy.CanCollide = false
	canopy.CanQuery = false
	canopy.Size = Vector3.new(7, 0.4, 7)
	canopy.CFrame = lookAt * CFrame.new(0, 9.2, -2.5)
	canopy.Material = Enum.Material.SmoothPlastic
	canopy.Color = Color3.fromRGB(150, 150, 150)
	canopy.Transparency = 1
	canopy.Parent = parent
	return canopy
end

local function buildStand(index: number, parent: Instance)
	local angle = (index / STAND_COUNT) * math.pi * 2
	local x = math.cos(angle) * PLAZA_RADIUS
	local z = math.sin(angle) * PLAZA_RADIUS
	-- Face the center of the plaza.
	local lookAt = CFrame.lookAt(Vector3.new(x, WORLD_Y, z), Vector3.new(0, WORLD_Y, 0))

	local stand = Instance.new("Model")
	stand.Name = `Stand_{index}`

	buildTierRing(lookAt, stand)

	local podium = Instance.new("Part")
	podium.Name = "Podium"
	podium.Anchored = true
	podium.CanCollide = true
	podium.Size = Vector3.new(6, 3, 6)
	podium.CFrame = lookAt * CFrame.new(0, 1.5, 0)
	podium.Material = Enum.Material.SmoothPlastic
	podium.Color = RankConfig.Ranks[1].color
	podium.Parent = stand

	buildCanopy(lookAt, stand)

	local signPost = Instance.new("Part")
	signPost.Name = "SignPost"
	signPost.Anchored = true
	signPost.CanCollide = false
	signPost.Size = Vector3.new(0.5, 6, 0.5)
	signPost.CFrame = lookAt * CFrame.new(0, 3 + 3, -2.5)
	signPost.Material = Enum.Material.Metal
	signPost.Color = Color3.fromRGB(60, 60, 65)
	signPost.Parent = stand

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sign"
	billboard.Size = UDim2.fromOffset(200, 74)
	billboard.StudsOffset = Vector3.new(0, 1, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = signPost

	local ownerLabel = Instance.new("TextLabel")
	ownerLabel.Name = "OwnerLabel"
	ownerLabel.Size = UDim2.new(1, 0, 0, 40)
	ownerLabel.BackgroundTransparency = 0.4
	ownerLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	ownerLabel.Text = "Empty Stand"
	ownerLabel.Font = Enum.Font.GothamBold
	ownerLabel.TextScaled = true
	ownerLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
	ownerLabel.Parent = billboard

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, 0, 0, 26)
	titleLabel.Position = UDim2.new(0, 0, 0, 42)
	titleLabel.BackgroundTransparency = 0.55
	titleLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	titleLabel.Text = ""
	titleLabel.Font = Enum.Font.Gotham
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = RankConfig.Ranks[1].color
	titleLabel.Parent = billboard

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DonatePrompt"
	prompt.ActionText = "Donate"
	prompt.ObjectText = "Empty Stand"
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = podium

	stand.PrimaryPart = podium
	stand.Parent = parent

	CollectionService:AddTag(stand, STAND_TAG)
end

local function buildStands(parent: Instance)
	for i = 1, STAND_COUNT do
		buildStand(i, parent)
	end
end

-- Harder test obby: smaller platforms, bigger gaps, zigzag left/right as well as up/down,
-- a couple of moving platforms, and a long drop to the void below (Workspace.
-- FallenPartsDestroyHeight, set at the bottom of build(), kills anyone who falls, so
-- missing a jump actually costs something). Real level design is still a builder task -
-- this just makes the mechanic testable.
local function buildTestObby(parent: Instance)
	local obby = Instance.new("Folder")
	obby.Name = "TestObby"
	obby.Parent = parent

	local startX = -PLAZA_RADIUS - 40
	local platformCount = 12
	local heights = { 0, 3, 1, 5, 2, 6, 1, 4, 7, 2, 5, 3 }
	local xOffsets = { 0, 3, -3, 4, -2, 3, -4, 2, -3, 4, -2, 0 }

	local movingPlatformIndices = { [5] = true, [9] = true }
	-- Missing a jump on a 12-platform course and getting sent all the way back to the
	-- main spawn is punishing - these two act as mid-course checkpoints instead (see
	-- CheckpointService.luau), so a death only costs the progress since the last one.
	local checkpointIndices = { [4] = true, [8] = true }

	for i = 0, platformCount do
		local platform = Instance.new("Part")
		platform.Name = `Platform_{i}`
		platform.Anchored = true
		platform.CanCollide = true
		platform.Size = Vector3.new(4, 1, 4)

		local height = heights[(i % #heights) + 1]
		local xOffset = xOffsets[(i % #xOffsets) + 1]
		local basePosition = Vector3.new(startX - i * 13, WORLD_Y + height, xOffset)
		platform.CFrame = CFrame.new(basePosition)
		platform.Material = currentTheme.obbyMaterial
		platform.Color = currentTheme.obbyColor
		platform.Parent = obby

		if movingPlatformIndices[i] then
			platform.Color = Color3.fromRGB(200, 90, 90)
			platform.Material = Enum.Material.Neon
			local targetPosition = basePosition + Vector3.new(0, 0, 14)
			local tween = TweenService:Create(
				platform,
				TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ CFrame = CFrame.new(targetPosition) }
			)
			tween:Play()
		elseif checkpointIndices[i] then
			platform.Material = Enum.Material.Neon
			platform.Color = Color3.fromRGB(90, 200, 230)
			CollectionService:AddTag(platform, CHECKPOINT_TAG)
		end
	end

	local finish = Instance.new("Part")
	finish.Name = "FinishPad"
	finish.Anchored = true
	finish.CanCollide = true
	finish.Size = Vector3.new(8, 1, 8)
	finish.CFrame = CFrame.new(startX - (platformCount + 1) * 13, WORLD_Y + 8, 0)
	finish.Material = Enum.Material.Neon
	finish.Color = Color3.fromRGB(90, 210, 120)
	finish.Parent = obby

	CollectionService:AddTag(finish, OBBY_FINISH_TAG)
	finish:SetAttribute("XpReward", 300)
	finish:SetAttribute("CourseId", "test_obby_1")
end

-- Short, low-XP courses meant to be replayed constantly between donations (the design
-- doc's "various short obbies for very short amounts of xp each"). ObbyService is fully
-- data-driven off the ObbyFinish tag + CourseId/XpReward attributes, so each course here
-- just needs a unique name/position - no server code changes needed to add more.
local function buildQuickObby(parent: Instance, courseId: string, direction: Vector3, heights: { number }, xpReward: number)
	local obby = Instance.new("Folder")
	obby.Name = courseId
	obby.Parent = parent

	local startOffset = PLAZA_RADIUS + 30
	local spacing = 9

	for i, height in heights do
		local platform = Instance.new("Part")
		platform.Name = `Platform_{i}`
		platform.Anchored = true
		platform.CanCollide = true
		platform.Size = Vector3.new(4, 1, 4)
		platform.CFrame = CFrame.new(direction * (startOffset + (i - 1) * spacing) + Vector3.new(0, WORLD_Y + height, 0))
		platform.Material = currentTheme.obbyMaterial
		platform.Color = currentTheme.obbyColor
		platform.Parent = obby
	end

	local finish = Instance.new("Part")
	finish.Name = "FinishPad"
	finish.Anchored = true
	finish.CanCollide = true
	finish.Size = Vector3.new(6, 1, 6)
	finish.CFrame = CFrame.new(direction * (startOffset + #heights * spacing) + Vector3.new(0, WORLD_Y + heights[#heights], 0))
	finish.Material = Enum.Material.Neon
	finish.Color = Color3.fromRGB(90, 210, 120)
	finish.Parent = obby

	CollectionService:AddTag(finish, OBBY_FINISH_TAG)
	finish:SetAttribute("XpReward", xpReward)
	finish:SetAttribute("CourseId", courseId)
end

function WorldBuilderService.build()
	clearExisting()
	setupAtmosphere()

	local root = Instance.new("Folder")
	root.Name = "GeneratedWorld"
	root.Parent = Workspace

	buildFloor(root)
	buildDome(root)
	buildTeleporter(root)
	buildPrestigeShowcase(root)
	buildStands(root)
	buildTestObby(root)
	-- Diagonal directions (45°/-45°) deliberately avoid the perimeter pillars, which sit
	-- on a 30°-spaced grid (see buildFloor) - a straight +X/+Z path would run through one.
	buildQuickObby(root, "quick_obby_1", Vector3.new(1, 0, 1).Unit, { 0, 2, 1, 3 }, 80)
	buildQuickObby(root, "quick_obby_2", Vector3.new(1, 0, -1).Unit, { 0, 2, 4, 3, 5, 4 }, 130)

	-- Destroys (and, for characters, kills) anything that falls below this height -
	-- a native engine feature, cheaper and simpler than a polling script that checks
	-- every player's position on a timer.
	Workspace.FallenPartsDestroyHeight = WorldBuilderService.KillY
end

return WorldBuilderService
