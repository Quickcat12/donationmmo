--!strict
-- Toggleable panel of owned prestige titles ("Gray Wanderer", "Diamond Luminary", ...),
-- unlocked automatically on rank-up (see CosmeticService.luau). Players can re-equip an
-- older title if they'd rather show that one, and can hide their chat tag entirely.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RankConfig = require(Shared.Config.RankConfig)
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)
local UICreate = require(Shared.Util.UICreate)
local Theme = require(Shared.Util.Theme)

local player = Players.LocalPlayer

type CosmeticsPayload = { ownedTitles: { string }, equippedTitle: string?, showChatTag: boolean }

local TitlesController = {}

local scroll: ScrollingFrame
local chatTagButton: TextButton

local function getHud(): ScreenGui
	local playerGui = player:WaitForChild("PlayerGui")
	return (playerGui:FindFirstChild("HUD") :: ScreenGui?)
		or (UICreate("ScreenGui", { Name = "HUD", ResetOnSpawn = false, Parent = playerGui }) :: ScreenGui)
end

local function colorForTitle(title: string): Color3
	for _, rank in RankConfig.Ranks do
		if rank.title == title then
			return rank.color
		end
	end
	return Theme.TextPrimary
end

local function renderCosmetics(payload: CosmeticsPayload)
	scroll:ClearAllChildren()

	local layout = UICreate("UIListLayout", { Padding = UDim.new(0, 8) })
	layout.Parent = scroll

	local equipEvent = Net.get(RemoteNames.Events.RequestEquipTitle)

	for _, title in payload.ownedTitles do
		local isEquipped = title == payload.equippedTitle
		local color = colorForTitle(title)

		local row = UICreate("Frame", {
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = Theme.PanelLight,
			Parent = scroll,
		}, {
			UICreate("UICorner", { CornerRadius = UDim.new(0, 8) }),
			UICreate("TextLabel", {
				Position = UDim2.fromOffset(10, 0),
				Size = UDim2.new(1, -100, 1, 0),
				BackgroundTransparency = 1,
				Text = title,
				Font = Theme.Font,
				TextSize = 14,
				TextColor3 = color,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		})

		local equipButton = UICreate("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(80, 30),
			BackgroundColor3 = isEquipped and Theme.Background or Theme.Accent,
			Text = isEquipped and "Equipped" or "Equip",
			Font = Theme.FontRegular,
			TextSize = 12,
			TextColor3 = isEquipped and Theme.TextSecondary or Theme.Background,
			Active = not isEquipped,
			Parent = row,
		}, { UICreate("UICorner", { CornerRadius = UDim.new(0, 6) }) }) :: TextButton

		equipButton.MouseButton1Click:Connect(function()
			if isEquipped then
				return
			end
			equipEvent:FireServer(title)
		end)
	end

	chatTagButton.Text = payload.showChatTag and "Hide Chat Tag" or "Show Chat Tag"
end

local function buildPanel(hud: ScreenGui): Frame
	local panel = UICreate("Frame", {
		Name = "TitlesPanel",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 20, 0, 90),
		Size = UDim2.fromOffset(300, 360),
		BackgroundColor3 = Theme.Panel,
		Visible = false,
		Parent = hud,
	}, {
		UICreate("UICorner", { CornerRadius = UDim.new(0, 12) }),
		UICreate("TextLabel", {
			Size = UDim2.new(1, -20, 0, 30),
			Position = UDim2.fromOffset(10, 8),
			BackgroundTransparency = 1,
			Text = "Titles",
			Font = Theme.Font,
			TextSize = 18,
			TextColor3 = Theme.TextPrimary,
		}),
	}) :: Frame

	scroll = UICreate("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 42),
		Size = UDim2.new(1, -20, 1, -100),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = panel,
	}) :: ScrollingFrame

	chatTagButton = UICreate("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -20, 0, 34),
		BackgroundColor3 = Theme.PanelLight,
		Text = "Hide Chat Tag",
		Font = Theme.FontRegular,
		TextSize = 13,
		TextColor3 = Theme.TextPrimary,
		Parent = panel,
	}, { UICreate("UICorner", { CornerRadius = UDim.new(0, 8) }) }) :: TextButton

	chatTagButton.MouseButton1Click:Connect(function()
		Net.get(RemoteNames.Events.RequestToggleChatTag):FireServer()
	end)

	return panel
end

function TitlesController.start()
	local hud = getHud()
	local panel = buildPanel(hud)

	local toggleButton = UICreate("TextButton", {
		Name = "TitlesToggle",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 20, 0, 20),
		Size = UDim2.fromOffset(48, 48),
		BackgroundColor3 = Theme.Panel,
		Text = "T",
		Font = Theme.Font,
		TextSize = 18,
		TextColor3 = Theme.TextPrimary,
		Parent = hud,
	}, { UICreate("UICorner", { CornerRadius = UDim.new(1, 0) }) }) :: TextButton

	toggleButton.MouseButton1Click:Connect(function()
		panel.Visible = not panel.Visible
	end)

	Net.get(RemoteNames.Events.CosmeticsUpdated).OnClientEvent:Connect(renderCosmetics)
end

return TitlesController
