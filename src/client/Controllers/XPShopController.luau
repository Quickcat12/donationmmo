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

local function formatXp(amount: number): string
	if amount >= 1000 then
		return `{amount // 1000}K`
	end
	return tostring(amount)
end

-- Adds thousands separators, e.g. 14750 -> "14,750".
local function commaFormat(amount: number): string
	local text = tostring(amount)
	local formatted, _ = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	while formatted ~= text do
		text = formatted
		formatted, _ = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	end
	return formatted
end

local function buildPanel(hud: ScreenGui): Frame
	local buttonHeight = 58
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
			Text = "",
			AutoButtonColor = true,
			Parent = list,
		}, {
			UICreate("UICorner", { CornerRadius = UDim.new(0, 8) }),
			UICreate("UIStroke", {
				Color = item.accentColor,
				Thickness = item.bestValue and 2 or 1,
				Transparency = item.bestValue and 0.15 or 0.75,
			}),
			-- A colored "coin" chip standing in for the item's real icon (uploaded once
			-- create_products.py actually creates it on Roblox - see generate_icons.py).
			UICreate("Frame", {
				Name = "Chip",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 8, 0.5, 0),
				Size = UDim2.fromOffset(42, 42),
				BackgroundColor3 = item.accentColor,
			}, {
				UICreate("UICorner", { CornerRadius = UDim.new(1, 0) }),
				UICreate("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = formatXp(item.xpAmount),
					Font = Theme.Font,
					TextScaled = true,
					TextColor3 = Theme.Background,
				}),
			}),
			UICreate("TextLabel", {
				Position = UDim2.fromOffset(58, 6),
				Size = UDim2.new(1, -68, 0, 20),
				BackgroundTransparency = 1,
				Text = item.name,
				Font = Theme.Font,
				TextSize = 14,
				TextColor3 = Theme.TextPrimary,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			UICreate("TextLabel", {
				Position = UDim2.fromOffset(58, 26),
				Size = UDim2.new(1, -68, 0, 26),
				BackgroundTransparency = 1,
				Text = `{commaFormat(item.xpAmount)} XP  •  {item.robuxPrice} R$`,
				Font = Theme.FontRegular,
				TextSize = 13,
				TextColor3 = Theme.TextSecondary,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		}) :: TextButton

		if item.bestValue then
			UICreate("TextLabel", {
				Name = "BestValueBadge",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -6, 0, 6),
				Size = UDim2.fromOffset(74, 16),
				BackgroundColor3 = item.accentColor,
				Text = "BEST VALUE",
				Font = Theme.Font,
				TextSize = 9,
				TextColor3 = Theme.Background,
				Parent = button,
			}, { UICreate("UICorner", { CornerRadius = UDim.new(0, 4) }) })
		end

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
