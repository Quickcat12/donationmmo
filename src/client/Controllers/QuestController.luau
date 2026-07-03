--!strict
-- Toggleable daily quest tracker. Rebuilds its list every time the server pushes a
-- QuestsUpdated snapshot (on join, on progress, and after claiming).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)
local UICreate = require(Shared.Util.UICreate)
local Theme = require(Shared.Util.Theme)

local player = Players.LocalPlayer

type QuestSnapshotEntry = {
	id: string,
	description: string,
	goalCount: number,
	xpReward: number,
	progress: number,
	completed: boolean,
}

local QuestController = {}

local panel: Frame
local scroll: ScrollingFrame

local function getHud(): ScreenGui
	local playerGui = player:WaitForChild("PlayerGui")
	return (playerGui:FindFirstChild("HUD") :: ScreenGui?)
		or (UICreate("ScreenGui", { Name = "HUD", ResetOnSpawn = false, Parent = playerGui }) :: ScreenGui)
end

local function renderQuests(quests: { QuestSnapshotEntry })
	scroll:ClearAllChildren()

	local claimEvent = Net.get(RemoteNames.Events.RequestClaimQuest)

	local layout = UICreate("UIListLayout", { Padding = UDim.new(0, 8) })
	layout.Parent = scroll

	for _, quest in quests do
		local progressFraction = math.clamp(quest.progress / quest.goalCount, 0, 1)
		local canClaim = quest.progress >= quest.goalCount and not quest.completed

		local card = UICreate("Frame", {
			Size = UDim2.new(1, 0, 0, 70),
			BackgroundColor3 = Theme.PanelLight,
			Parent = scroll,
		}, {
			UICreate("UICorner", { CornerRadius = UDim.new(0, 8) }),
			UICreate("TextLabel", {
				Position = UDim2.fromOffset(10, 6),
				Size = UDim2.new(1, -20, 0, 18),
				BackgroundTransparency = 1,
				Text = quest.description,
				Font = Theme.FontRegular,
				TextSize = 13,
				TextColor3 = Theme.TextPrimary,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			UICreate("Frame", {
				Position = UDim2.fromOffset(10, 30),
				Size = UDim2.new(1, -110, 0, 8),
				BackgroundColor3 = Theme.Background,
			}, {
				UICreate("UICorner", { CornerRadius = UDim.new(1, 0) }),
				UICreate("Frame", {
					Size = UDim2.new(progressFraction, 0, 1, 0),
					BackgroundColor3 = quest.completed and Theme.Success or Theme.Accent,
				}, { UICreate("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
			}),
			UICreate("TextLabel", {
				Position = UDim2.fromOffset(10, 44),
				Size = UDim2.new(1, -110, 0, 16),
				BackgroundTransparency = 1,
				Text = `{quest.progress}/{quest.goalCount}  •  +{quest.xpReward} XP`,
				Font = Theme.FontRegular,
				TextSize = 11,
				TextColor3 = Theme.TextSecondary,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		})

		local claimButton = UICreate("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(84, 32),
			BackgroundColor3 = quest.completed and Theme.Background
				or (canClaim and Theme.Accent or Theme.Background),
			Text = quest.completed and "Done" or "Claim",
			Font = Theme.FontRegular,
			TextSize = 13,
			TextColor3 = quest.completed and Theme.TextSecondary
				or (canClaim and Theme.Background or Theme.TextSecondary),
			Active = canClaim,
			Parent = card,
		}, { UICreate("UICorner", { CornerRadius = UDim.new(0, 6) }) }) :: TextButton

		claimButton.MouseButton1Click:Connect(function()
			if not canClaim then
				return
			end
			claimEvent:FireServer(quest.id)
		end)
	end
end

local function buildPanel(hud: ScreenGui)
	panel = UICreate("Frame", {
		Name = "QuestPanel",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 20, 0.5, 0),
		Size = UDim2.fromOffset(320, 420),
		BackgroundColor3 = Theme.Panel,
		Visible = false,
		Parent = hud,
	}, {
		UICreate("UICorner", { CornerRadius = UDim.new(0, 12) }),
		UICreate("TextLabel", {
			Size = UDim2.new(1, -20, 0, 34),
			Position = UDim2.fromOffset(10, 8),
			BackgroundTransparency = 1,
			Text = "Daily Quests",
			Font = Theme.Font,
			TextSize = 20,
			TextColor3 = Theme.TextPrimary,
		}),
	}) :: Frame

	scroll = UICreate("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 46),
		Size = UDim2.new(1, -20, 1, -56),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = panel,
	}) :: ScrollingFrame

	local toggleButton = UICreate("TextButton", {
		Name = "QuestToggle",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 20, 0.5, 0),
		Size = UDim2.fromOffset(48, 48),
		BackgroundColor3 = Theme.Panel,
		Text = "Q",
		Font = Theme.Font,
		TextSize = 18,
		TextColor3 = Theme.TextPrimary,
		Parent = hud,
	}, { UICreate("UICorner", { CornerRadius = UDim.new(1, 0) }) }) :: TextButton

	toggleButton.MouseButton1Click:Connect(function()
		panel.Visible = not panel.Visible
	end)
end

function QuestController.start()
	local hud = getHud()
	buildPanel(hud)

	Net.get(RemoteNames.Events.QuestsUpdated).OnClientEvent:Connect(renderQuests)
end

return QuestController
