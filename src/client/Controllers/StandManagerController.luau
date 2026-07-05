--!strict
-- "Manage My Stand" panel: lets a player link up to 6 of their own Gamepasses (created by
-- them on creator.roblox.com, any price they want) to their donation stand. The server
-- verifies actual ownership before accepting each one (see DonationService.luau).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)
local UICreate = require(Shared.Util.UICreate)
local Theme = require(Shared.Util.Theme)

local player = Players.LocalPlayer

local MAX_SLOTS = 6

local StandManagerController = {}

local slotLabels: { [number]: TextLabel } = {}
local slotInputs: { [number]: TextBox } = {}

local function getHud(): ScreenGui
	local playerGui = player:WaitForChild("PlayerGui")
	return (playerGui:FindFirstChild("HUD") :: ScreenGui?)
		or (UICreate("ScreenGui", { Name = "HUD", ResetOnSpawn = false, Parent = playerGui }) :: ScreenGui)
end

local function showToast(hud: ScreenGui, text: string, color: Color3)
	local toast = UICreate("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 130),
		Size = UDim2.fromOffset(360, 36),
		BackgroundColor3 = Theme.Panel,
		Text = text,
		TextWrapped = true,
		Font = Theme.FontRegular,
		TextSize = 13,
		TextColor3 = color,
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

local function buildPanel(hud: ScreenGui): Frame
	local panel = UICreate("Frame", {
		Name = "StandManagerPanel",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -90),
		Size = UDim2.fromOffset(340, 400),
		BackgroundColor3 = Theme.Panel,
		Visible = false,
		Parent = hud,
	}, {
		UICreate("UICorner", { CornerRadius = UDim.new(0, 12) }),
		UICreate("TextLabel", {
			Size = UDim2.new(1, -20, 0, 30),
			Position = UDim2.fromOffset(10, 8),
			BackgroundTransparency = 1,
			Text = "Manage My Stand",
			Font = Theme.Font,
			TextSize = 18,
			TextColor3 = Theme.TextPrimary,
		}),
		UICreate("TextLabel", {
			Size = UDim2.new(1, -20, 0, 34),
			Position = UDim2.fromOffset(10, 36),
			BackgroundTransparency = 1,
			Text = "Paste a Gamepass ID you created on creator.roblox.com and own.",
			TextWrapped = true,
			Font = Theme.FontRegular,
			TextSize = 11,
			TextColor3 = Theme.TextSecondary,
		}),
	}) :: Frame

	local scroll = UICreate("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 76),
		Size = UDim2.new(1, -20, 1, -86),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = panel,
	}, {
		UICreate("UIListLayout", { Padding = UDim.new(0, 8) }),
	})

	local setEvent = Net.get(RemoteNames.Events.RequestSetDonationGamepass)

	for slot = 1, MAX_SLOTS do
		local row = UICreate("Frame", {
			Size = UDim2.new(1, 0, 0, 60),
			BackgroundColor3 = Theme.PanelLight,
			Parent = scroll,
		}, {
			UICreate("UICorner", { CornerRadius = UDim.new(0, 8) }),
		})

		local statusLabel = UICreate("TextLabel", {
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -20, 0, 18),
			BackgroundTransparency = 1,
			Text = `Slot {slot}: empty`,
			Font = Theme.FontRegular,
			TextSize = 12,
			TextColor3 = Theme.TextSecondary,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		}) :: TextLabel
		slotLabels[slot] = statusLabel

		local input = UICreate("TextBox", {
			Position = UDim2.fromOffset(10, 26),
			Size = UDim2.fromOffset(180, 26),
			BackgroundColor3 = Theme.Background,
			PlaceholderText = "Gamepass ID",
			Text = "",
			Font = Theme.FontRegular,
			TextSize = 13,
			TextColor3 = Theme.TextPrimary,
			ClearTextOnFocus = false,
			Parent = row,
		}, { UICreate("UICorner", { CornerRadius = UDim.new(0, 6) }) }) :: TextBox
		slotInputs[slot] = input

		local setButton = UICreate("TextButton", {
			Position = UDim2.fromOffset(198, 26),
			Size = UDim2.fromOffset(60, 26),
			BackgroundColor3 = Theme.Accent,
			Text = "Set",
			Font = Theme.FontRegular,
			TextSize = 13,
			TextColor3 = Theme.Background,
			Parent = row,
		}, { UICreate("UICorner", { CornerRadius = UDim.new(0, 6) }) }) :: TextButton

		local clearButton = UICreate("TextButton", {
			Position = UDim2.fromOffset(262, 26),
			Size = UDim2.fromOffset(60, 26),
			BackgroundColor3 = Theme.Background,
			Text = "Clear",
			Font = Theme.FontRegular,
			TextSize = 13,
			TextColor3 = Theme.TextSecondary,
			Parent = row,
		}, { UICreate("UICorner", { CornerRadius = UDim.new(0, 6) }) }) :: TextButton

		setButton.MouseButton1Click:Connect(function()
			local gamepassId = tonumber(input.Text)
			-- The server re-validates everything regardless (see DonationService.luau) -
			-- this is just to drop obviously-malformed input before it's even sent.
			if not gamepassId or gamepassId ~= math.floor(gamepassId) or gamepassId <= 0 or gamepassId > 9_999_999_999 then
				showToast(hud, "Enter a valid numeric Gamepass ID.", Theme.Danger)
				return
			end
			setEvent:FireServer(slot, gamepassId)
		end)

		clearButton.MouseButton1Click:Connect(function()
			setEvent:FireServer(slot, 0)
		end)
	end

	return panel
end

function StandManagerController.start()
	local hud = getHud()
	local panel = buildPanel(hud)

	local toggleButton = UICreate("TextButton", {
		Name = "StandManagerToggle",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -20),
		Size = UDim2.fromOffset(48, 48),
		BackgroundColor3 = Theme.Panel,
		Text = "S",
		Font = Theme.Font,
		TextSize = 18,
		TextColor3 = Theme.TextPrimary,
		Parent = hud,
	}, { UICreate("UICorner", { CornerRadius = UDim.new(1, 0) }) }) :: TextButton

	toggleButton.MouseButton1Click:Connect(function()
		panel.Visible = not panel.Visible
	end)

	Net.get(RemoteNames.Events.SetDonationGamepassResult).OnClientEvent:Connect(function(result)
		local label = slotLabels[result.slot]
		if not label then
			return
		end

		if not result.success then
			showToast(hud, result.reason or "Failed to set Gamepass.", Theme.Danger)
			return
		end

		if result.cleared then
			label.Text = `Slot {result.slot}: empty`
			label.TextColor3 = Theme.TextSecondary
		else
			label.Text = `Slot {result.slot}: {result.name} - {result.price} R$`
			label.TextColor3 = Theme.Success
			local input = slotInputs[result.slot]
			if input then
				input.Text = ""
			end
		end
	end)
end

return StandManagerController
