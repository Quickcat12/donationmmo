--!strict
-- Full-screen celebration banner shown whenever the server confirms a rank promotion.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RankConfig = require(Shared.Config.RankConfig)
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)
local UICreate = require(Shared.Util.UICreate)
local Theme = require(Shared.Util.Theme)

local player = Players.LocalPlayer

local RankUpController = {}

-- Built-in Sparkles instance - no custom asset uploads needed - for the "instant dopamine"
-- moment of a rank promotion.
local function burstSparkles(color: Color3)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = color
	sparkles.Parent = rootPart
	Debris:AddItem(sparkles, 2.5)
end

local function showBanner(payload: { oldRank: string, newRank: string, title: string })
	local rank = RankConfig.getRankByName(payload.newRank)
	local color = rank and rank.color or Theme.Accent

	local screenGui = player:WaitForChild("PlayerGui"):FindFirstChild("HUD")
		or UICreate("ScreenGui", { Name = "HUD", ResetOnSpawn = false, Parent = player:WaitForChild("PlayerGui") })

	local banner = UICreate("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.35),
		Size = UDim2.fromOffset(500, 120),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 1,
		Parent = screenGui,
	}, {
		UICreate("UICorner", { CornerRadius = UDim.new(0, 14) }),
		UICreate("UIStroke", { Color = color, Thickness = 3, Transparency = 1 }),
		UICreate("TextLabel", {
			Name = "Title",
			Size = UDim2.new(1, 0, 0, 40),
			Position = UDim2.fromOffset(0, 16),
			BackgroundTransparency = 1,
			Text = "RANK UP!",
			Font = Theme.Font,
			TextSize = 28,
			TextColor3 = color,
			TextTransparency = 1,
		}),
		UICreate("TextLabel", {
			Name = "Subtitle",
			Size = UDim2.new(1, 0, 0, 30),
			Position = UDim2.fromOffset(0, 60),
			BackgroundTransparency = 1,
			Text = `You are now {payload.title}`,
			Font = Theme.FontRegular,
			TextSize = 18,
			TextColor3 = Theme.TextPrimary,
			TextTransparency = 1,
		}),
	})

	local stroke = banner:FindFirstChildOfClass("UIStroke") :: UIStroke
	local title = banner:FindFirstChild("Title") :: TextLabel
	local subtitle = banner:FindFirstChild("Subtitle") :: TextLabel

	local fadeIn = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(banner, fadeIn, { BackgroundTransparency = 0.1 }):Play()
	TweenService:Create(stroke, fadeIn, { Transparency = 0 }):Play()
	TweenService:Create(title, fadeIn, { TextTransparency = 0 }):Play()
	TweenService:Create(subtitle, fadeIn, { TextTransparency = 0 }):Play()

	burstSparkles(color)

	task.delay(3.5, function()
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

function RankUpController.start()
	Net.get(RemoteNames.Events.RankUp).OnClientEvent:Connect(showBanner)
end

return RankUpController
