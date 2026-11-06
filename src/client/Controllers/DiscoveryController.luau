--!strict
-- Exploration feedback. Undiscovered landmarks carry a floating "?" visible from a
-- distance, which turns the island into a visible checklist; walking into one swaps it
-- for a big "DISCOVERED" banner with the running count (3/8). The server owns the
-- record (DiscoveryService); this only mirrors it.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)
local UICreate = require(Shared.Util.UICreate)
local Theme = require(Shared.Util.Theme)

local player = Players.LocalPlayer

local DISCOVERY_TAG = "Discovery"
local MARKER_NAME = "DiscoveryMarker"
local MARKER_COLOR = Color3.fromRGB(120, 220, 255)

local DiscoveryController = {}

local found: { [string]: boolean } = {}
local gui: ScreenGui

local function refreshMarker(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local id = part:GetAttribute("DiscoveryId")
	local existing = part:FindFirstChild(MARKER_NAME)
	if type(id) ~= "string" or found[id] then
		if existing then
			existing:Destroy()
		end
		return
	end
	if existing then
		return
	end
	UICreate("BillboardGui", {
		Name = MARKER_NAME,
		Size = UDim2.fromOffset(46, 46),
		StudsOffset = Vector3.new(0, 4, 0),
		MaxDistance = 260,
		AlwaysOnTop = false,
		LightInfluence = 0,
		Parent = part,
	}, {
		UICreate("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Background,
			BackgroundTransparency = 0.35,
			Text = "?",
			Font = Theme.Font,
			TextScaled = true,
			TextColor3 = MARKER_COLOR,
		}, {
			UICreate("UICorner", { CornerRadius = UDim.new(1, 0) }),
			UICreate("UIStroke", { Color = MARKER_COLOR, Thickness = 2, Transparency = 0.2 }),
		}),
	})
end

local function refreshAll()
	for _, part in CollectionService:GetTagged(DISCOVERY_TAG) do
		refreshMarker(part)
	end
end

local function showBanner(name: string, foundCount: number, total: number)
	local banner = UICreate("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(480, 96),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 1,
		Parent = gui,
	}) :: Frame

	local header = UICreate("TextLabel", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Text = "LANDMARK DISCOVERED",
		Font = Theme.Font,
		TextSize = 16,
		TextColor3 = MARKER_COLOR,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = banner,
	}) :: TextLabel
	local title = UICreate("TextLabel", {
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromOffset(0, 22),
		BackgroundTransparency = 1,
		Text = name,
		Font = Theme.Font,
		TextSize = 38,
		TextColor3 = Theme.TextPrimary,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = banner,
	}) :: TextLabel
	local count = UICreate("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 68),
		BackgroundTransparency = 1,
		Text = `{foundCount} / {total} landmarks found`,
		Font = Theme.FontRegular,
		TextSize = 15,
		TextColor3 = Theme.TextSecondary,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = banner,
	}) :: TextLabel

	local labels = { header, title, count }
	for _, label in labels do
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 0, TextStrokeTransparency = 0.5 }):Play()
	end
	task.delay(3.5, function()
		for _, label in labels do
			TweenService:Create(label, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
		task.wait(0.7)
		banner:Destroy()
	end)
end

function DiscoveryController.start()
	gui = UICreate("ScreenGui", {
		Name = "Discovery",
		ResetOnSpawn = false,
		DisplayOrder = 12,
		Parent = player:WaitForChild("PlayerGui"),
	}) :: ScreenGui

	Net.get(RemoteNames.Events.DiscoveriesUpdated).OnClientEvent:Connect(function(ids: { string })
		found = {}
		for _, id in ids do
			found[id] = true
		end
		refreshAll()
	end)

	Net.get(RemoteNames.Events.DiscoveryFound).OnClientEvent:Connect(function(payload)
		found[payload.id] = true
		refreshAll()
		showBanner(payload.name, payload.found, payload.total)
	end)

	CollectionService:GetInstanceAddedSignal(DISCOVERY_TAG):Connect(refreshMarker)
	refreshAll()
end

return DiscoveryController
