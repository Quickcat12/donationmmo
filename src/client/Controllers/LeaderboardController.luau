--!strict
-- Toggleable top-10 leaderboards (by XP and by lifetime donations given), refreshed
-- whenever the server broadcasts LeaderboardUpdated.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)
local UICreate = require(Shared.Util.UICreate)
local Theme = require(Shared.Util.Theme)

local player = Players.LocalPlayer

type LeaderboardEntry = { userId: number, name: string, value: number }
type LeaderboardSnapshot = { topXp: { LeaderboardEntry }, topDonations: { LeaderboardEntry } }

local LeaderboardController = {}

local panel: Frame
local xpList: Frame
local donationList: Frame

local function getHud(): ScreenGui
	local playerGui = player:WaitForChild("PlayerGui")
	return (playerGui:FindFirstChild("HUD") :: ScreenGui?)
		or (UICreate("ScreenGui", { Name = "HUD", ResetOnSpawn = false, Parent = playerGui }) :: ScreenGui)
end

local function fillList(list: Frame, entries: { LeaderboardEntry }, suffix: string)
	list:ClearAllChildren()
	local layout = UICreate("UIListLayout", { Padding = UDim.new(0, 4) })
	layout.Parent = list

	for i, entry in entries do
		UICreate("TextLabel", {
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			Text = `{i}. {entry.name} - {entry.value} {suffix}`,
			Font = Theme.FontRegular,
			TextSize = 13,
			TextColor3 = i <= 3 and Theme.Accent or Theme.TextPrimary,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = list,
		})
	end
end

local function renderSnapshot(snapshot: LeaderboardSnapshot)
	fillList(xpList, snapshot.topXp, "XP")
	fillList(donationList, snapshot.topDonations, "R$ donated")
end

local function buildPanel(hud: ScreenGui)
	panel = UICreate("Frame", {
		Name = "LeaderboardPanel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 80),
		Size = UDim2.fromOffset(360, 340),
		BackgroundColor3 = Theme.Panel,
		Visible = false,
		Parent = hud,
	}, {
		UICreate("UICorner", { CornerRadius = UDim.new(0, 12) }),
		UICreate("TextLabel", {
			Size = UDim2.new(1, -20, 0, 30),
			Position = UDim2.fromOffset(10, 8),
			BackgroundTransparency = 1,
			Text = "Top XP",
			Font = Theme.Font,
			TextSize = 16,
			TextColor3 = Theme.TextPrimary,
		}),
		UICreate("TextLabel", {
			Size = UDim2.new(1, -20, 0, 30),
			Position = UDim2.fromOffset(10, 178),
			BackgroundTransparency = 1,
			Text = "Top Donors",
			Font = Theme.Font,
			TextSize = 16,
			TextColor3 = Theme.TextPrimary,
		}),
	}) :: Frame

	xpList = UICreate("Frame", {
		Position = UDim2.fromOffset(10, 42),
		Size = UDim2.new(1, -20, 0, 130),
		BackgroundTransparency = 1,
		Parent = panel,
	}) :: Frame

	donationList = UICreate("Frame", {
		Position = UDim2.fromOffset(10, 212),
		Size = UDim2.new(1, -20, 0, 120),
		BackgroundTransparency = 1,
		Parent = panel,
	}) :: Frame

	local toggleButton = UICreate("TextButton", {
		Name = "LeaderboardToggle",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.fromOffset(48, 48),
		BackgroundColor3 = Theme.Panel,
		Text = "L",
		Font = Theme.Font,
		TextSize = 18,
		TextColor3 = Theme.TextPrimary,
		Parent = hud,
	}, { UICreate("UICorner", { CornerRadius = UDim.new(1, 0) }) }) :: TextButton

	toggleButton.MouseButton1Click:Connect(function()
		panel.Visible = not panel.Visible
	end)
end

function LeaderboardController.start()
	local hud = getHud()
	buildPanel(hud)

	Net.get(RemoteNames.Events.LeaderboardUpdated).OnClientEvent:Connect(renderSnapshot)
end

return LeaderboardController
