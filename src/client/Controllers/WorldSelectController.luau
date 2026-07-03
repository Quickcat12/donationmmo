--!strict
-- Toggleable panel listing all worlds with lock state based on the player's level.
-- WorldConfig is a shared module, so this reads it directly - no remote round trip
-- needed just to render the list. The actual travel request is still re-validated
-- server-side (see WorldService.luau).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldConfig = require(Shared.Config.WorldConfig)
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)
local UICreate = require(Shared.Util.UICreate)
local Theme = require(Shared.Util.Theme)

local State = require(script.Parent.Parent.State)

local player = Players.LocalPlayer

local WorldSelectController = {}

local function getHud(): ScreenGui
	local playerGui = player:WaitForChild("PlayerGui")
	return (playerGui:FindFirstChild("HUD") :: ScreenGui?)
		or (UICreate("ScreenGui", { Name = "HUD", ResetOnSpawn = false, Parent = playerGui }) :: ScreenGui)
end

local function showToast(text: string, color: Color3)
	local hud = getHud()
	local toast = UICreate("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 80),
		Size = UDim2.fromOffset(400, 40),
		BackgroundColor3 = Theme.Panel,
		Text = text,
		TextWrapped = true,
		Font = Theme.FontRegular,
		TextSize = 14,
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
		Name = "WorldPanel",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -20, 0.5, 0),
		Size = UDim2.fromOffset(320, 480),
		BackgroundColor3 = Theme.Panel,
		Visible = false,
		Parent = hud,
	}, {
		UICreate("UICorner", { CornerRadius = UDim.new(0, 12) }),
		UICreate("TextLabel", {
			Size = UDim2.new(1, -20, 0, 34),
			Position = UDim2.fromOffset(10, 8),
			BackgroundTransparency = 1,
			Text = "Worlds",
			Font = Theme.Font,
			TextSize = 20,
			TextColor3 = Theme.TextPrimary,
		}),
	}) :: Frame

	local scroll = UICreate("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 46),
		Size = UDim2.new(1, -20, 1, -56),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = panel,
	}, {
		UICreate("UIListLayout", { Padding = UDim.new(0, 8) }),
	})

	local travelEvent = Net.get(RemoteNames.Events.RequestWorldTravel)

	for _, world in WorldConfig.Worlds do
		local unlocked = State.level >= world.requiredLevel

		local card = UICreate("Frame", {
			Size = UDim2.new(1, 0, 0, 78),
			BackgroundColor3 = Theme.PanelLight,
			Parent = scroll,
		}, {
			UICreate("UICorner", { CornerRadius = UDim.new(0, 8) }),
			UICreate("TextLabel", {
				Position = UDim2.fromOffset(10, 6),
				Size = UDim2.new(1, -20, 0, 20),
				BackgroundTransparency = 1,
				Text = world.displayName,
				Font = Theme.Font,
				TextSize = 15,
				TextColor3 = unlocked and Theme.TextPrimary or Theme.TextSecondary,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			UICreate("TextLabel", {
				Position = UDim2.fromOffset(10, 24),
				Size = UDim2.new(1, -20, 0, 30),
				BackgroundTransparency = 1,
				Text = world.description,
				TextWrapped = true,
				Font = Theme.FontRegular,
				TextSize = 12,
				TextColor3 = Theme.TextSecondary,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		})

		local travelButton = UICreate("TextButton", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -8, 1, -6),
			Size = UDim2.fromOffset(90, 26),
			BackgroundColor3 = unlocked and Theme.Accent or Theme.Background,
			Text = unlocked and "Travel" or `Lvl {world.requiredLevel}`,
			Font = Theme.FontRegular,
			TextSize = 13,
			TextColor3 = unlocked and Theme.Background or Theme.TextSecondary,
			Parent = card,
		}, { UICreate("UICorner", { CornerRadius = UDim.new(0, 6) }) }) :: TextButton

		travelButton.MouseButton1Click:Connect(function()
			if not unlocked then
				return
			end
			travelEvent:FireServer(world.id)
		end)
	end

	return panel
end

function WorldSelectController.start()
	local hud = getHud()
	local panel = buildPanel(hud)

	local toggleButton = UICreate("TextButton", {
		Name = "WorldToggle",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -20, 0.5, 0),
		Size = UDim2.fromOffset(48, 48),
		BackgroundColor3 = Theme.Panel,
		Text = "W",
		Font = Theme.Font,
		TextSize = 18,
		TextColor3 = Theme.TextPrimary,
		Parent = hud,
	}, { UICreate("UICorner", { CornerRadius = UDim.new(1, 0) }) }) :: TextButton

	toggleButton.MouseButton1Click:Connect(function()
		panel.Visible = not panel.Visible
	end)

	-- Rebuild the panel's lock/unlock state whenever the player's level changes,
	-- preserving whether it was open.
	State.Changed:Connect(function()
		local wasVisible = panel.Visible
		panel:Destroy()
		panel = buildPanel(hud)
		panel.Visible = wasVisible
	end)

	Net.get(RemoteNames.Events.WorldTravelDenied).OnClientEvent:Connect(function(reason: string)
		showToast(reason, Theme.Danger)
	end)
end

return WorldSelectController
