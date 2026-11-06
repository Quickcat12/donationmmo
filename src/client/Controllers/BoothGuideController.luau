--!strict
-- Walks a player to their own booth: a "YOUR BOOTH" marker over it and a guide beam
-- from the character until they arrive. A new player who never finds their booth never
-- receives a donation and never earns booth-duty XP, so this is onboarding for the
-- whole receiving side of the loop. The marker stays (subtly) so they can find it again.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UICreate = require(Shared.Util.UICreate)
local Theme = require(Shared.Util.Theme)

local player = Players.LocalPlayer

local STAND_TAG = "DonationStand"
local ARRIVE_DISTANCE = 14

local BoothGuideController = {}

local currentStand: Model? = nil
local marker: BillboardGui? = nil
local beam: Beam? = nil
local arrived = false

local function clearGuide()
	if beam then
		beam:Destroy()
		beam = nil
	end
	for _, name in { "BoothGuideA0", "BoothGuideA1" } do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local a = root and root:FindFirstChild(name)
		if a then
			a:Destroy()
		end
		local podium = currentStand and currentStand:FindFirstChild("Podium")
		local b = podium and podium:FindFirstChild(name)
		if b then
			b:Destroy()
		end
	end
end

local function attachBeam()
	clearGuide()
	if arrived or not currentStand then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local podium = currentStand:FindFirstChild("Podium")
	if not root or not podium then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "BoothGuideA0"
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "BoothGuideA1"
	a1.Position = Vector3.new(0, 2, 0)
	a1.Parent = podium
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Color = ColorSequence.new(Theme.Accent)
	b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.6) })
	b.Width0 = 0.6
	b.Width1 = 0.6
	b.FaceCamera = true
	b.LightEmission = 1
	b.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	b.TextureMode = Enum.TextureMode.Static
	b.TextureLength = 3
	b.TextureSpeed = 1.5
	b.Parent = root
	beam = b
end

local function setMarker(stand: Model?)
	if marker then
		marker:Destroy()
		marker = nil
	end
	if not stand then
		return
	end
	local podium = stand:FindFirstChild("Podium")
	if not podium then
		return
	end
	marker = UICreate("BillboardGui", {
		Name = "YourBoothMarker",
		Size = UDim2.fromOffset(150, 36),
		StudsOffset = Vector3.new(0, 15.5, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Parent = podium,
	}, {
		UICreate("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Accent,
			Text = "YOUR BOOTH",
			Font = Theme.Font,
			TextScaled = true,
			TextColor3 = Theme.Background,
		}, {
			UICreate("UICorner", { CornerRadius = UDim.new(1, 0) }),
			UICreate("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }),
		}),
	}) :: BillboardGui
end

local function findMyStand(): Model?
	for _, stand in CollectionService:GetTagged(STAND_TAG) do
		if stand:IsA("Model") and stand:GetAttribute("OwnerUserId") == player.UserId then
			return stand
		end
	end
	return nil
end

local function refresh()
	local stand = findMyStand()
	if stand == currentStand then
		return
	end
	clearGuide()
	currentStand = stand
	arrived = false
	setMarker(stand)
	attachBeam()
end

local function watchStand(stand: Instance)
	stand:GetAttributeChangedSignal("OwnerUserId"):Connect(refresh)
end

function BoothGuideController.start()
	for _, stand in CollectionService:GetTagged(STAND_TAG) do
		watchStand(stand)
	end
	CollectionService:GetInstanceAddedSignal(STAND_TAG):Connect(function(stand)
		watchStand(stand)
		refresh()
	end)
	player.CharacterAdded:Connect(function()
		task.wait(1)
		attachBeam()
	end)
	refresh()

	RunService.Heartbeat:Connect(function()
		if arrived or not currentStand then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local podium = currentStand:FindFirstChild("Podium") :: BasePart?
		if root and podium and (root.Position - podium.Position).Magnitude < ARRIVE_DISTANCE then
			arrived = true
			clearGuide()
			if marker then
				local label = marker:FindFirstChildOfClass("TextLabel")
				if label then
					label.BackgroundTransparency = 0.5
				end
				marker.AlwaysOnTop = false
			end
		end
	end)
end

return BoothGuideController
