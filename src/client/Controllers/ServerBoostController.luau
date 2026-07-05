--!strict
-- Announces the server-wide XP boost (see ServerBoostService.luau) with a big banner
-- crediting the buyer, and keeps a small persistent countdown chip on the HUD for as
-- long as it's active so everyone's reminded why their XP gains just doubled.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)
local UICreate = require(Shared.Util.UICreate)
local Theme = require(Shared.Util.Theme)

local player = Players.LocalPlayer

type BoostPayload = { buyerName: string, multiplier: number, durationSeconds: number }

local ServerBoostController = {}

local activeCountdownToken = 0

local function getHud(): ScreenGui
	local playerGui = player:WaitForChild("PlayerGui")
	return (playerGui:FindFirstChild("HUD") :: ScreenGui?)
		or (UICreate("ScreenGui", { Name = "HUD", ResetOnSpawn = false, Parent = playerGui }) :: ScreenGui)
end

local function formatCountdown(secondsLeft: number): string
	local minutes = math.floor(secondsLeft / 60)
	local seconds = secondsLeft % 60
	return string.format("%d:%02d", minutes, seconds)
end

local function showBanner(payload: BoostPayload)
	local hud = getHud()
	local existing = hud:FindFirstChild("ServerBoostBanner")
	if existing then
		existing:Destroy()
	end

	local minutes = math.floor(payload.durationSeconds / 60)
	local banner = UICreate("Frame", {
		Name = "ServerBoostBanner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(520, 110),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 1,
		Parent = hud,
	}, {
		UICreate("UICorner", { CornerRadius = UDim.new(0, 14) }),
		UICreate("UIStroke", { Color = Theme.Accent, Thickness = 3, Transparency = 1 }),
		UICreate("TextLabel", {
			Name = "Title",
			Size = UDim2.new(1, 0, 0, 36),
			Position = UDim2.fromOffset(0, 14),
			BackgroundTransparency = 1,
			Text = `SERVER BLESSED WITH {payload.multiplier}x XP!`,
			Font = Theme.Font,
			TextSize = 26,
			TextColor3 = Theme.Accent,
			TextTransparency = 1,
		}),
		UICreate("TextLabel", {
			Name = "Subtitle",
			Size = UDim2.new(1, 0, 0, 26),
			Position = UDim2.fromOffset(0, 56),
			BackgroundTransparency = 1,
			Text = `{payload.buyerName} bought everyone {minutes} minutes of {payload.multiplier}x XP`,
			Font = Theme.FontRegular,
			TextSize = 15,
			TextColor3 = Theme.TextPrimary,
			TextTransparency = 1,
		}),
	}) :: Frame

	local stroke = banner:FindFirstChildOfClass("UIStroke") :: UIStroke
	local title = banner:FindFirstChild("Title") :: TextLabel
	local subtitle = banner:FindFirstChild("Subtitle") :: TextLabel

	local fadeIn = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(banner, fadeIn, { BackgroundTransparency = 0.1 }):Play()
	TweenService:Create(stroke, fadeIn, { Transparency = 0 }):Play()
	TweenService:Create(title, fadeIn, { TextTransparency = 0 }):Play()
	TweenService:Create(subtitle, fadeIn, { TextTransparency = 0 }):Play()

	task.delay(4.5, function()
		local fadeOut = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(banner, fadeOut, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(stroke, fadeOut, { Transparency = 1 }):Play()
		TweenService:Create(title, fadeOut, { TextTransparency = 1 }):Play()
		local tween = TweenService:Create(subtitle, fadeOut, { TextTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		banner:Destroy()
	end)
end

local function startCountdownChip(multiplier: number, durationSeconds: number)
	local hud = getHud()
	local existing = hud:FindFirstChild("ServerBoostChip")
	if existing then
		existing:Destroy()
	end

	local chip = UICreate("TextLabel", {
		Name = "ServerBoostChip",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.fromOffset(160, 26),
		BackgroundColor3 = Theme.Accent,
		Font = Theme.Font,
		TextSize = 13,
		TextColor3 = Theme.Background,
		Parent = hud,
	}, { UICreate("UICorner", { CornerRadius = UDim.new(1, 0) }) }) :: TextLabel

	activeCountdownToken += 1
	local myToken = activeCountdownToken
	local endsAt = os.clock() + durationSeconds

	task.spawn(function()
		while activeCountdownToken == myToken and chip.Parent do
			local secondsLeft = math.max(0, math.floor(endsAt - os.clock()))
			chip.Text = `{multiplier}x XP - {formatCountdown(secondsLeft)}`
			if secondsLeft <= 0 then
				chip:Destroy()
				break
			end
			task.wait(1)
		end
	end)
end

function ServerBoostController.start()
	Net.get(RemoteNames.Events.ServerBoostActivated).OnClientEvent:Connect(function(payload: BoostPayload)
		showBanner(payload)
		startCountdownChip(payload.multiplier, payload.durationSeconds)
	end)
end

return ServerBoostController
