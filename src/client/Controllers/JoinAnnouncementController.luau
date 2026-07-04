--!strict
-- Server-wide banner whenever a high-enough rank joins the server - the design doc's
-- "[DIAMOND] TyHurd has joined the server" moment. Stacks multiple announcements if they
-- arrive close together instead of overwriting each other.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)
local UICreate = require(Shared.Util.UICreate)
local Theme = require(Shared.Util.Theme)

local player = Players.LocalPlayer

type JoinAnnouncement = { userId: number, name: string, rankName: string, rankColor: Color3, title: string }

local JoinAnnouncementController = {}

local function getHud(): ScreenGui
	local playerGui = player:WaitForChild("PlayerGui")
	return (playerGui:FindFirstChild("HUD") :: ScreenGui?)
		or (UICreate("ScreenGui", { Name = "HUD", ResetOnSpawn = false, Parent = playerGui }) :: ScreenGui)
end

local function getStack(hud: ScreenGui): Frame
	local existing = hud:FindFirstChild("JoinAnnouncementStack") :: Frame?
	if existing then
		return existing
	end

	return UICreate("Frame", {
		Name = "JoinAnnouncementStack",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 76),
		Size = UDim2.fromOffset(420, 300),
		BackgroundTransparency = 1,
		Parent = hud,
	}, {
		UICreate("UIListLayout", {
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}) :: Frame
end

local function showAnnouncement(payload: JoinAnnouncement)
	if payload.userId == player.UserId then
		return -- don't announce yourself to yourself
	end

	local hud = getHud()
	local stack = getStack(hud)

	local card = UICreate("TextLabel", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 1,
		Text = `[{string.upper(payload.rankName)}] {payload.name} has joined the server`,
		TextWrapped = true,
		Font = Theme.Font,
		TextSize = 14,
		TextColor3 = payload.rankColor,
		TextTransparency = 1,
		Parent = stack,
	}, { UICreate("UIStroke", { Color = payload.rankColor, Thickness = 1, Transparency = 1 }) }) :: TextLabel

	local stroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke

	local fadeIn = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(card, fadeIn, { TextTransparency = 0, BackgroundTransparency = 0.15 }):Play()
	TweenService:Create(stroke, fadeIn, { Transparency = 0.3 }):Play()

	task.delay(4.5, function()
		local fadeOut = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(card, fadeOut, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		local strokeTween = TweenService:Create(stroke, fadeOut, { Transparency = 1 })
		strokeTween:Play()
		strokeTween.Completed:Wait()
		card:Destroy()
	end)
end

function JoinAnnouncementController.start()
	Net.get(RemoteNames.Events.PlayerJoinedAnnouncement).OnClientEvent:Connect(showAnnouncement)
end

return JoinAnnouncementController
