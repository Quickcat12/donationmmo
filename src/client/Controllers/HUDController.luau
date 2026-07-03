--!strict
-- Persistent top-of-screen bar: rank color chip, rank/level text, XP progress bar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RankConfig = require(Shared.Config.RankConfig)
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)
local UICreate = require(Shared.Util.UICreate)
local Theme = require(Shared.Util.Theme)

local State = require(script.Parent.Parent.State)

local player = Players.LocalPlayer

local HUDController = {}

local fillBar: Frame
local rankChip: Frame
local levelLabel: TextLabel
local rankLabel: TextLabel

local function build()
	local screenGui = UICreate("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})

	local container = UICreate("Frame", {
		Name = "XPBarContainer",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(420, 54),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.1,
		Parent = screenGui,
	}, {
		UICreate("UICorner", { CornerRadius = UDim.new(0, 10) }),
	})

	rankChip = UICreate("Frame", {
		Name = "RankChip",
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.fromOffset(38, 38),
		BackgroundColor3 = Theme.Accent,
		Parent = container,
	}, {
		UICreate("UICorner", { CornerRadius = UDim.new(1, 0) }),
	}) :: Frame

	rankLabel = UICreate("TextLabel", {
		Name = "RankLabel",
		Position = UDim2.fromOffset(58, 4),
		Size = UDim2.fromOffset(200, 20),
		BackgroundTransparency = 1,
		Text = "Gray Wanderer",
		Font = Theme.Font,
		TextSize = 16,
		TextColor3 = Theme.TextPrimary,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = container,
	}) :: TextLabel

	levelLabel = UICreate("TextLabel", {
		Name = "LevelLabel",
		Position = UDim2.fromOffset(58, 22),
		Size = UDim2.fromOffset(200, 16),
		BackgroundTransparency = 1,
		Text = "Level 1",
		Font = Theme.FontRegular,
		TextSize = 13,
		TextColor3 = Theme.TextSecondary,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = container,
	}) :: TextLabel

	local barTrack = UICreate("Frame", {
		Name = "BarTrack",
		Position = UDim2.fromOffset(58, 40),
		Size = UDim2.new(0, 352, 0, 8),
		BackgroundColor3 = Theme.Background,
		Parent = container,
	}, {
		UICreate("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})

	fillBar = UICreate("Frame", {
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Theme.Accent,
		Parent = barTrack,
	}, {
		UICreate("UICorner", { CornerRadius = UDim.new(1, 0) }),
	}) :: Frame
end

local function refresh()
	local rank = RankConfig.getRankByName(State.rank)
	if rank then
		rankChip.BackgroundColor3 = rank.color
		rankLabel.Text = rank.title
		rankLabel.TextColor3 = rank.color
	end
	levelLabel.Text = `Level {State.level}`

	TweenService:Create(fillBar, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
		Size = UDim2.new(State.progress, 0, 1, 0),
	}):Play()
end

function HUDController.start()
	build()
	refresh()

	State.Changed:Connect(refresh)

	Net.get(RemoteNames.Events.XpChanged).OnClientEvent:Connect(function(payload)
		State.update(payload)
	end)
end

return HUDController
