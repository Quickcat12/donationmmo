--!strict
-- Login-streak UI: a persistent flame chip beside the HUD bar ("3 days"), and a popup
-- showing the 7-day reward track whenever today's reward is auto-claimed. Seeing the
-- big day-7 tile two days away is what brings people back on day 6.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)
local UICreate = require(Shared.Util.UICreate)
local Theme = require(Shared.Util.Theme)

local player = Players.LocalPlayer

type StreakPayload = {
	count: number,
	best: number,
	cycleDay: number,
	rewards: { number },
	justClaimed: number?,
}

local DailyStreakController = {}

local FLAME = Color3.fromRGB(255, 150, 60)

local gui: ScreenGui
local chipLabel: TextLabel

local function build()
	gui = UICreate("ScreenGui", {
		Name = "DailyStreak",
		ResetOnSpawn = false,
		DisplayOrder = 15,
		Parent = player:WaitForChild("PlayerGui"),
	}) :: ScreenGui

	-- Lives inside the HUD bar's frame (just left of it) so it scales and moves with it.
	local playerGui = player:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("HUD")
	local bar = hud:WaitForChild("XPBarContainer")
	local chip = UICreate("Frame", {
		Name = "StreakChip",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0, -8, 0, 0),
		Size = UDim2.fromOffset(74, 60),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.08,
		Parent = bar,
	}, {
		UICreate("UICorner", { CornerRadius = UDim.new(0, 12) }),
		UICreate("UIStroke", { Color = FLAME, Transparency = 0.55, Thickness = 1.5 }),
		UICreate("TextLabel", {
			Size = UDim2.new(1, 0, 0, 30),
			Position = UDim2.fromOffset(0, 4),
			BackgroundTransparency = 1,
			Text = "🔥",
			TextSize = 24,
			Font = Theme.Font,
		}),
	})

	chipLabel = UICreate("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 34),
		BackgroundTransparency = 1,
		Text = "0 days",
		Font = Theme.Font,
		TextSize = 13,
		TextColor3 = FLAME,
		Parent = chip,
	}) :: TextLabel
end

local function showPopup(payload: StreakPayload)
	local claimed = payload.justClaimed or 0
	local overlay = UICreate("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(520, 230),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.04,
		Parent = gui,
	}, {
		UICreate("UICorner", { CornerRadius = UDim.new(0, 16) }),
		UICreate("UIStroke", { Color = FLAME, Thickness = 2, Transparency = 0.2 }),
		UICreate("UIScale", { Scale = 0.6 }),
		UICreate("TextLabel", {
			Size = UDim2.new(1, 0, 0, 40),
			Position = UDim2.fromOffset(0, 14),
			BackgroundTransparency = 1,
			Text = `🔥 Day {payload.count} Login Streak`,
			Font = Theme.Font,
			TextSize = 28,
			TextColor3 = FLAME,
		}),
		UICreate("TextLabel", {
			Size = UDim2.new(1, 0, 0, 22),
			Position = UDim2.fromOffset(0, 54),
			BackgroundTransparency = 1,
			Text = `+{claimed} XP collected · come back tomorrow to keep it going`,
			Font = Theme.FontRegular,
			TextSize = 15,
			TextColor3 = Theme.TextPrimary,
		}),
	}) :: Frame

	local track = UICreate("Frame", {
		Position = UDim2.fromOffset(20, 92),
		Size = UDim2.new(1, -40, 0, 100),
		BackgroundTransparency = 1,
		Parent = overlay,
	}, {
		UICreate("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	for day, reward in payload.rewards do
		local isToday = day == payload.cycleDay
		local done = day <= payload.cycleDay
		local isBig = day == #payload.rewards
		UICreate("Frame", {
			Size = UDim2.fromOffset(60, 96),
			LayoutOrder = day,
			BackgroundColor3 = isToday and FLAME or (done and Theme.PanelLight or Theme.Panel),
			Parent = track,
		}, {
			UICreate("UICorner", { CornerRadius = UDim.new(0, 10) }),
			UICreate("UIStroke", {
				Color = isBig and Theme.Accent or Color3.fromRGB(255, 255, 255),
				Transparency = isBig and 0.1 or 0.85,
				Thickness = isBig and 2 or 1,
			}),
			UICreate("TextLabel", {
				Size = UDim2.new(1, 0, 0, 22),
				Position = UDim2.fromOffset(0, 8),
				BackgroundTransparency = 1,
				Text = `Day {day}`,
				Font = Theme.Font,
				TextSize = 13,
				TextColor3 = isToday and Theme.Background or Theme.TextSecondary,
			}),
			UICreate("TextLabel", {
				Size = UDim2.new(1, 0, 0, 26),
				Position = UDim2.fromOffset(0, 34),
				BackgroundTransparency = 1,
				Text = done and not isToday and "✓" or tostring(reward),
				Font = Theme.Font,
				TextSize = isBig and 18 or 16,
				TextColor3 = isToday and Theme.Background or (isBig and Theme.Accent or Theme.TextPrimary),
			}),
			UICreate("TextLabel", {
				Size = UDim2.new(1, 0, 0, 16),
				Position = UDim2.fromOffset(0, 64),
				BackgroundTransparency = 1,
				Text = "XP",
				Font = Theme.FontRegular,
				TextSize = 11,
				TextColor3 = isToday and Theme.Background or Theme.TextSecondary,
			}),
		})
	end

	local scale = overlay:FindFirstChildOfClass("UIScale") :: UIScale
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	local closeButton = UICreate("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 5,
		Parent = overlay,
	}) :: TextButton

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		local shrink = TweenService:Create(scale, TweenInfo.new(0.2), { Scale = 0 })
		shrink:Play()
		shrink.Completed:Wait()
		overlay:Destroy()
	end
	closeButton.MouseButton1Click:Connect(close)
	task.delay(7, close)
end

function DailyStreakController.start()
	build()
	Net.get(RemoteNames.Events.DailyStreakUpdated).OnClientEvent:Connect(function(payload: StreakPayload)
		chipLabel.Text = payload.count == 1 and "1 day" or `{payload.count} days`
		if payload.justClaimed then
			showPopup(payload)
		end
	end)
end

return DailyStreakController
