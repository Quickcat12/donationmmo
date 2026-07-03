--!strict
-- Donation amount picker (opened by the server when a player triggers a stand's
-- ProximityPrompt) and incoming-donation toast notifications.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DonationConfig = require(Shared.Config.DonationConfig)
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)
local UICreate = require(Shared.Util.UICreate)
local Theme = require(Shared.Util.Theme)

local player = Players.LocalPlayer

local DonationController = {}

local function getHud(): ScreenGui
	local playerGui = player:WaitForChild("PlayerGui")
	return (playerGui:FindFirstChild("HUD") :: ScreenGui?)
		or (UICreate("ScreenGui", { Name = "HUD", ResetOnSpawn = false, Parent = playerGui }) :: ScreenGui)
end

local function openDonationMenu(receiverUserId: number, receiverName: string)
	local hud = getHud()
	local existing = hud:FindFirstChild("DonationMenu")
	if existing then
		existing:Destroy()
	end

	local requestEvent = Net.get(RemoteNames.Events.RequestDonate)
	local buttonHeight = 42
	local buttonSpacing = 8
	local listHeight = (#DonationConfig.Tiers * (buttonHeight + buttonSpacing))

	local menu = UICreate("Frame", {
		Name = "DonationMenu",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(320, 46 + listHeight + 50),
		BackgroundColor3 = Theme.Panel,
		Parent = hud,
	}, {
		UICreate("UICorner", { CornerRadius = UDim.new(0, 12) }),
		UICreate("TextLabel", {
			Size = UDim2.new(1, -20, 0, 30),
			Position = UDim2.fromOffset(10, 10),
			BackgroundTransparency = 1,
			Text = `Donate to {receiverName}`,
			Font = Theme.Font,
			TextSize = 18,
			TextColor3 = Theme.TextPrimary,
		}),
	})

	local buttonList = UICreate("Frame", {
		Position = UDim2.fromOffset(10, 46),
		Size = UDim2.new(1, -20, 0, listHeight),
		BackgroundTransparency = 1,
		Parent = menu,
	}, {
		UICreate("UIListLayout", {
			Padding = UDim.new(0, buttonSpacing),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	})

	for _, tier in DonationConfig.Tiers do
		local button = UICreate("TextButton", {
			Size = UDim2.new(1, 0, 0, buttonHeight),
			BackgroundColor3 = Theme.PanelLight,
			Text = `{tier.robuxPrice} Robux  (+{tier.donorXp} XP)`,
			Font = Theme.FontRegular,
			TextSize = 16,
			TextColor3 = Theme.TextPrimary,
			AutoButtonColor = true,
			Parent = buttonList,
		}, { UICreate("UICorner", { CornerRadius = UDim.new(0, 8) }) }) :: TextButton

		button.MouseButton1Click:Connect(function()
			requestEvent:FireServer(receiverUserId, tier.productId)
			menu:Destroy()
		end)
	end

	local closeButton = UICreate("TextButton", {
		Name = "CloseButton",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, -40),
		Size = UDim2.fromOffset(120, 32),
		BackgroundColor3 = Theme.Background,
		Text = "Cancel",
		Font = Theme.FontRegular,
		TextSize = 14,
		TextColor3 = Theme.TextSecondary,
		Parent = menu,
	}, { UICreate("UICorner", { CornerRadius = UDim.new(0, 8) }) }) :: TextButton

	closeButton.MouseButton1Click:Connect(function()
		menu:Destroy()
	end)
end

local function showDonationToast(payload: { fromUserId: number, fromName: string, robuxAmount: number })
	local hud = getHud()

	local toast = UICreate("TextLabel", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -20),
		Size = UDim2.fromOffset(300, 50),
		BackgroundColor3 = Theme.Panel,
		Text = `{payload.fromName} donated {payload.robuxAmount} Robux to you!`,
		TextWrapped = true,
		Font = Theme.FontRegular,
		TextSize = 14,
		TextColor3 = Theme.Success,
		Parent = hud,
	}, { UICreate("UICorner", { CornerRadius = UDim.new(0, 8) }) })

	task.delay(4, function()
		local tween =
			TweenService:Create(toast, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		toast:Destroy()
	end)
end

function DonationController.start()
	Net.get(RemoteNames.Events.OpenDonationMenu).OnClientEvent:Connect(openDonationMenu)
	Net.get(RemoteNames.Events.DonationReceived).OnClientEvent:Connect(showDonationToast)
end

return DonationController
