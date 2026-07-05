--!strict
-- A flashy, server-wide banner whenever someone makes a big donation (see
-- DonationService.BIG_DONATION_THRESHOLD_ROBUX). Donations are otherwise a private
-- moment between two players - this is the social-proof amplifier that makes everyone
-- else in the server want to match or beat it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)
local UICreate = require(Shared.Util.UICreate)
local Theme = require(Shared.Util.Theme)

local player = Players.LocalPlayer

type BigDonationPayload = { donorName: string, receiverName: string, robuxAmount: number }

local BigDonationController = {}

local function getHud(): ScreenGui
	local playerGui = player:WaitForChild("PlayerGui")
	return (playerGui:FindFirstChild("HUD") :: ScreenGui?)
		or (UICreate("ScreenGui", { Name = "HUD", ResetOnSpawn = false, Parent = playerGui }) :: ScreenGui)
end

local function showBanner(payload: BigDonationPayload)
	local hud = getHud()
	local existing = hud:FindFirstChild("BigDonationBanner")
	if existing then
		existing:Destroy()
	end

	local banner = UICreate("Frame", {
		Name = "BigDonationBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 130),
		Size = UDim2.fromOffset(460, 56),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 1,
		Parent = hud,
	}, {
		UICreate("UICorner", { CornerRadius = UDim.new(0, 12) }),
		UICreate("UIStroke", { Color = Theme.Accent, Thickness = 2, Transparency = 1 }),
		UICreate("TextLabel", {
			Name = "Text",
			Size = UDim2.new(1, -20, 1, 0),
			Position = UDim2.fromOffset(10, 0),
			BackgroundTransparency = 1,
			Text = `{payload.donorName} donated {payload.robuxAmount} Robux to {payload.receiverName}!`,
			TextWrapped = true,
			Font = Theme.Font,
			TextSize = 16,
			TextColor3 = Theme.Accent,
			TextTransparency = 1,
		}),
	}) :: Frame

	local stroke = banner:FindFirstChildOfClass("UIStroke") :: UIStroke
	local text = banner:FindFirstChild("Text") :: TextLabel

	local fadeIn = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(banner, fadeIn, { BackgroundTransparency = 0.1 }):Play()
	TweenService:Create(stroke, fadeIn, { Transparency = 0.2 }):Play()
	TweenService:Create(text, fadeIn, { TextTransparency = 0 }):Play()

	task.delay(4.5, function()
		local fadeOut = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(banner, fadeOut, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(stroke, fadeOut, { Transparency = 1 }):Play()
		local textTween = TweenService:Create(text, fadeOut, { TextTransparency = 1 })
		textTween:Play()
		textTween.Completed:Wait()
		banner:Destroy()
	end)
end

function BigDonationController.start()
	Net.get(RemoteNames.Events.BigDonationAnnouncement).OnClientEvent:Connect(showBanner)
end

return BigDonationController
