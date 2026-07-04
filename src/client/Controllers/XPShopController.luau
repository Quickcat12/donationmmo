--!strict
-- Simple toggleable shop for game-owned XP boosts (real Developer Products, revenue goes
-- to the experience/group - see XPShopService.luau). Distinct from donations, which use
-- player-owned Gamepasses (see DonationController.luau).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local XPShopConfig = require(Shared.Config.XPShopConfig)
local VIPConfig = require(Shared.Config.VIPConfig)
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)
local UICreate = require(Shared.Util.UICreate)
local Theme = require(Shared.Util.Theme)

local player = Players.LocalPlayer

local XPShopController = {}

local function getHud(): ScreenGui
	local playerGui = player:WaitForChild("PlayerGui")
	return (playerGui:FindFirstChild("HUD") :: ScreenGui?)
		or (UICreate("ScreenGui", { Name = "HUD", ResetOnSpawn = false, Parent = playerGui }) :: ScreenGui)
end

local function buildPanel(hud: ScreenGui): Frame
	local buttonHeight = 46
	local spacing = 8
	local listHeight = #XPShopConfig.Items * (buttonHeight + spacing)
	local vipSectionHeight = 74

	local panel = UICreate("Frame", {
		Name = "XPShopPanel",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -90),
		Size = UDim2.fromOffset(280, 50 + listHeight + vipSectionHeight),
		BackgroundColor3 = Theme.Panel,
		Visible = false,
		Parent = hud,
	}, {
		UICreate("UICorner", { CornerRadius = UDim.new(0, 12) }),
		UICreate("TextLabel", {
			Size = UDim2.new(1, -20, 0, 30),
			Position = UDim2.fromOffset(10, 8),
			BackgroundTransparency = 1,
			Text = "XP Shop",
			Font = Theme.Font,
			TextSize = 18,
			TextColor3 = Theme.TextPrimary,
		}),
	}) :: Frame

	local buyEvent = Net.get(RemoteNames.Events.RequestBuyXp)

	local list = UICreate("Frame", {
		Position = UDim2.fromOffset(10, 44),
		Size = UDim2.new(1, -20, 0, listHeight),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		UICreate("UIListLayout", { Padding = UDim.new(0, spacing) }),
	})

	for _, item in XPShopConfig.Items do
		local button = UICreate("TextButton", {
			Size = UDim2.new(1, 0, 0, buttonHeight),
			BackgroundColor3 = Theme.PanelLight,
			Text = `{item.name} - {item.xpAmount} XP - {item.robuxPrice} R$`,
			TextWrapped = true,
			Font = Theme.FontRegular,
			TextSize = 14,
			TextColor3 = Theme.TextPrimary,
			Parent = list,
		}, { UICreate("UICorner", { CornerRadius = UDim.new(0, 8) }) }) :: TextButton

		button.MouseButton1Click:Connect(function()
			buyEvent:FireServer(item.productId)
		end)
	end

	local vipButton = UICreate("TextButton", {
		Name = "VIPButton",
		Position = UDim2.fromOffset(10, 54 + listHeight),
		Size = UDim2.new(1, -20, 0, vipSectionHeight - 10),
		BackgroundColor3 = Theme.Accent,
		Text = `VIP: +{math.floor((VIPConfig.XpMultiplier - 1) * 100)}% XP forever`,
		TextWrapped = true,
		Font = Theme.Font,
		TextSize = 14,
		TextColor3 = Theme.Background,
		Parent = panel,
	}, { UICreate("UICorner", { CornerRadius = UDim.new(0, 8) }) }) :: TextButton

	local function refreshVipButton()
		local owned = player:GetAttribute("VIPOwned") == true
		vipButton.Text = owned and "VIP: Active" or `VIP: +{math.floor((VIPConfig.XpMultiplier - 1) * 100)}% XP forever - {VIPConfig.Name}`
		vipButton.Active = not owned
		vipButton.BackgroundColor3 = owned and Theme.PanelLight or Theme.Accent
		vipButton.TextColor3 = owned and Theme.TextSecondary or Theme.Background
	end

	vipButton.MouseButton1Click:Connect(function()
		if VIPConfig.GamepassId == 0 or player:GetAttribute("VIPOwned") == true then
			return
		end
		MarketplaceService:PromptGamePassPurchase(player, VIPConfig.GamepassId)
	end)

	player:GetAttributeChangedSignal("VIPOwned"):Connect(refreshVipButton)
	refreshVipButton()

	return panel
end

function XPShopController.start()
	local hud = getHud()
	local panel = buildPanel(hud)

	local toggleButton = UICreate("TextButton", {
		Name = "XPShopToggle",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -20),
		Size = UDim2.fromOffset(48, 48),
		BackgroundColor3 = Theme.Panel,
		Text = "XP",
		Font = Theme.Font,
		TextSize = 14,
		TextColor3 = Theme.TextPrimary,
		Parent = hud,
	}, { UICreate("UICorner", { CornerRadius = UDim.new(1, 0) }) }) :: TextButton

	toggleButton.MouseButton1Click:Connect(function()
		panel.Visible = not panel.Visible
	end)
end

return XPShopController
