--!strict
-- Procedurally builds a basic playable plaza directly into Workspace at server start,
-- since Rojo doesn't manage Workspace in this project (no $path is mapped to it in
-- default.project.json) - there's no conflict with hand-placed Studio content.
--
-- This is deliberately simple "programmer art" (blocky parts, flat colors) so the game
-- is actually testable end-to-end. Replacing this with real 3D art/architecture in
-- Studio is still the long-term plan - see the design doc's per-world descriptions.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local RankConfig = require(game:GetService("ReplicatedStorage").Shared.Config.RankConfig)

local STAND_TAG = "DonationStand"
local OBBY_FINISH_TAG = "ObbyFinish"
local STAND_COUNT = 16
local PLAZA_RADIUS = 90

local WorldBuilderService = {}

local function clearExisting()
	local existing = Workspace:FindFirstChild("GeneratedWorld")
	if existing then
		existing:Destroy()
	end
end

local function buildFloor(parent: Instance)
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = Vector3.new(400, 4, 400)
	floor.CFrame = CFrame.new(0, -2, 0)
	floor.Material = Enum.Material.Concrete
	floor.Color = Color3.fromRGB(120, 120, 125)
	floor.Parent = parent

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MainSpawn"
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, 0.5, PLAZA_RADIUS + 20)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Color = Color3.fromRGB(90, 90, 95)
	spawn.Duration = 0
	spawn.Parent = parent
end

local function buildStand(index: number, parent: Instance)
	local angle = (index / STAND_COUNT) * math.pi * 2
	local x = math.cos(angle) * PLAZA_RADIUS
	local z = math.sin(angle) * PLAZA_RADIUS
	-- Face the center of the plaza.
	local lookAt = CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(0, 0, 0))

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

-- A short, low-effort test obby so ObbyService is actually exercisable in-game. Real
-- level design/obby content is still a builder task.
local function buildTestObby(parent: Instance)
	local obby = Instance.new("Folder")
	obby.Name = "TestObby"
	obby.Parent = parent

	local startX = -PLAZA_RADIUS - 40
	local platformCount = 8

	for i = 0, platformCount do
		local platform = Instance.new("Part")
		platform.Name = `Platform_{i}`
		platform.Anchored = true
		platform.CanCollide = true
		platform.Size = Vector3.new(6, 1, 6)
		platform.CFrame = CFrame.new(startX - i * 10, i % 2 == 0 and 2 or 5, 0)
		platform.Material = Enum.Material.Wood
		platform.Color = Color3.fromRGB(150, 110, 70)
		platform.Parent = obby
	end

	local finish = Instance.new("Part")
	finish.Name = "FinishPad"
	finish.Anchored = true
	finish.CanCollide = true
	finish.Size = Vector3.new(8, 1, 8)
	finish.CFrame = CFrame.new(startX - (platformCount + 1) * 10, 6, 0)
	finish.Material = Enum.Material.Neon
	finish.Color = Color3.fromRGB(90, 210, 120)
	finish.Parent = obby

	CollectionService:AddTag(finish, OBBY_FINISH_TAG)
	finish:SetAttribute("XpReward", 300)
	finish:SetAttribute("CourseId", "test_obby_1")
end

function WorldBuilderService.build()
	clearExisting()

	local root = Instance.new("Folder")
	root.Name = "GeneratedWorld"
	root.Parent = Workspace

	buildFloor(root)
	buildStands(root)
	buildTestObby(root)
end

return WorldBuilderService
