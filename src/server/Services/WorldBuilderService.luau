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
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local RankConfig = require(game:GetService("ReplicatedStorage").Shared.Config.RankConfig)

local STAND_TAG = "DonationStand"
local OBBY_FINISH_TAG = "ObbyFinish"
local STAND_COUNT = 16
local PLAZA_RADIUS = 90

-- The whole plaza floats high above the baseplate. Falling off anywhere on the map
-- (plaza or obby) means a long drop - VoidKillService.luau kills players who fall below
-- WorldBuilderService.KillY.
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
	atmosphere.Color = Color3.fromRGB(199, 199, 214)
	atmosphere.Decay = Color3.fromRGB(92, 102, 120)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting

	Lighting.Brightness = 3
	Lighting.FogEnd = 100000
end

local function buildFloor(parent: Instance)
	-- Outer plaza floor.
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = Vector3.new(2 * PLAZA_RADIUS + 60, 4, 2 * PLAZA_RADIUS + 60)
	floor.CFrame = CFrame.new(0, WORLD_Y - 2, 0)
	floor.Material = Enum.Material.Slate
	floor.Color = Color3.fromRGB(100, 100, 108)
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
		cap.Color = RankConfig.Ranks[1].color
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
	monumentOrb.Color = Color3.fromRGB(255, 205, 70)
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

local function buildStand(index: number, parent: Instance)
	local angle = (index / STAND_COUNT) * math.pi * 2
	local x = math.cos(angle) * PLAZA_RADIUS
	local z = math.sin(angle) * PLAZA_RADIUS
	-- Face the center of the plaza.
	local lookAt = CFrame.lookAt(Vector3.new(x, WORLD_Y, z), Vector3.new(0, WORLD_Y, 0))

	local stand = Instance.new("Model")
	stand.Name = `Stand_{index}`

	local podium = Instance.new("Part")
	podium.Name = "Podium"
	podium.Anchored = true
	podium.CanCollide = true
	podium.Size = Vector3.new(6, 3, 6)
	podium.CFrame = lookAt * CFrame.new(0, 1.5, 0)
	podium.Material = Enum.Material.SmoothPlastic
	podium.Color = RankConfig.Ranks[1].color
	podium.Parent = stand

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
	billboard.Size = UDim2.fromOffset(200, 60)
	billboard.StudsOffset = Vector3.new(0, 1, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = signPost

	local ownerLabel = Instance.new("TextLabel")
	ownerLabel.Name = "OwnerLabel"
	ownerLabel.Size = UDim2.fromScale(1, 1)
	ownerLabel.BackgroundTransparency = 0.4
	ownerLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	ownerLabel.Text = "Empty Stand"
	ownerLabel.Font = Enum.Font.GothamBold
	ownerLabel.TextScaled = true
	ownerLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
	ownerLabel.Parent = billboard

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
-- a couple of moving platforms, and a long drop to the void below (VoidKillService kills
-- anyone who falls, so missing a jump actually costs something). Real level design is
-- still a builder task - this just makes the mechanic testable.
local function buildTestObby(parent: Instance)
	local obby = Instance.new("Folder")
	obby.Name = "TestObby"
	obby.Parent = parent

	local startX = -PLAZA_RADIUS - 40
	local platformCount = 12
	local heights = { 0, 3, 1, 5, 2, 6, 1, 4, 7, 2, 5, 3 }
	local xOffsets = { 0, 3, -3, 4, -2, 3, -4, 2, -3, 4, -2, 0 }

	local movingPlatformIndices = { [5] = true, [9] = true }

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
		platform.Material = Enum.Material.Wood
		platform.Color = Color3.fromRGB(150, 110, 70)
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

function WorldBuilderService.build()
	clearExisting()
	setupAtmosphere()

	local root = Instance.new("Folder")
	root.Name = "GeneratedWorld"
	root.Parent = Workspace

	buildFloor(root)
	buildDome(root)
	buildStands(root)
	buildTestObby(root)
end

return WorldBuilderService
