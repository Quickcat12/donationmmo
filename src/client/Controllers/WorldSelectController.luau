--!strict
-- Toggleable panel listing all worlds with lock state based on the player's level.
-- WorldConfig is a shared module, so this reads it directly - no remote round trip
-- needed just to render the list. The actual travel request is still re-validated
-- server-side (see WorldService.luau).
--
-- Every stat shown here is real, computed from data the game already tracks - there's
-- no "screenshot" yet since no world besides the base plaza has been built as a real
-- Place (see WorldConfig.luau), so each card gets a rank-colored gradient banner as its
-- visual identity instead. Swap in a real ImageLabel + screenshot asset id once a
-- world's actual Place exists - see the comment on heroBanner below for where.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RankConfig = require(Shared.Config.RankConfig)
local WorldConfig = require(Shared.Config.WorldConfig)
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)
local UICreate = require(Shared.Util.UICreate)
local Theme = require(Shared.Util.Theme)

local State = require(script.Parent.Parent.State)

local player = Players.LocalPlayer

local WorldSelectController = {}

local panel: Frame? = nil
local populationLabels: { [string]: TextLabel } = {}
local latestPopulation: { [string]: number } = {}

-- Exposed so other controllers (e.g. TeleporterController, for the physical portal in
-- the plaza) can open this panel without needing their own copy of it.
function WorldSelectController.open()
	if panel then
		panel.Visible = true
	end
end

function WorldSelectController.toggle()
	if panel then
		panel.Visible = not panel.Visible
	end
end

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

local function darken(color: Color3, amount: number): Color3
	return Color3.new(color.R * (1 - amount), color.G * (1 - amount), color.B * (1 - amount))
end

local function formatMultiplier(amount: number): string
	return string.format("%.2fx", amount)
end

local function formatPopulationText(count: number?): string
	if count == nil then
		return "—"
	elseif count == 1 then
		return "1 Player"
	end
	return `{count} Players`
end

-- Everything a rank actually, verifiably unlocks - titles (CosmeticService.luau) and
-- stand material tiers (StandService.materialForTier) - not invented flavor text.
local function getUnlocksForRank(rank: RankConfig.RankInfo): { string }
	local unlocks = { `"{rank.title}" title` }

	if rank.order >= 6 then
		table.insert(unlocks, "Neon-tier donation stand")
	elseif rank.order >= 4 then
		table.insert(unlocks, "Marble-tier donation stand")
	elseif rank.order >= 2 then
		table.insert(unlocks, "Metal-tier donation stand")
	end

	if rank.order >= 5 then
		table.insert(unlocks, "Stand canopy")
	end

	return unlocks
end

-- A rank-colored gradient standing in for a real screenshot. Once a world's actual
-- Place is built and screenshotted, replace this Frame with an ImageLabel pointing at
-- the screenshot's asset id - everything else on the card can stay as-is.
local function buildHeroBanner(size: UDim2, rankColor: Color3, displayName: string, cornerRadius: number): Frame
	return UICreate("Frame", {
		Name = "HeroBanner",
		Size = size,
		BackgroundColor3 = rankColor,
		ClipsDescendants = true,
	}, {
		UICreate("UICorner", { CornerRadius = UDim.new(0, cornerRadius) }),
		UICreate("UIGradient", {
			Color = ColorSequence.new(darken(rankColor, 0.35), rankColor),
			Rotation = 60,
		}),
		UICreate("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = string.upper(displayName),
			Font = Enum.Font.GothamBold,
			TextSize = 22,
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeTransparency = 0.3,
			TextScaled = true,
		}, {
			UICreate("UIPadding", {
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
		}),
	}) :: Frame
end

local function buildStatRow(label: string, value: string, valueColor: Color3): Frame
	return UICreate("Frame", {
		Size = UDim2.new(0.5, -4, 0, 32),
		BackgroundTransparency = 1,
	}, {
		UICreate("TextLabel", {
			Name = "Label",
			Size = UDim2.new(1, 0, 0, 14),
			BackgroundTransparency = 1,
			Text = string.upper(label),
			Font = Theme.FontRegular,
			TextSize = 10,
			TextColor3 = Theme.TextSecondary,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		UICreate("TextLabel", {
			Name = "Value",
			Position = UDim2.fromOffset(0, 14),
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			Text = value,
			Font = Theme.Font,
			TextSize = 15,
			TextColor3 = valueColor,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	}) :: Frame
end

-- The big detail view - same real stats as the list card, just bigger and with the full
-- unlocks list, opened from a card's "Preview" button.
local function openPreviewModal(hud: ScreenGui, world: WorldConfig.WorldInfo, rank: RankConfig.RankInfo, rankColor: Color3, unlocked: boolean)
	local existing = hud:FindFirstChild("WorldPreviewModal")
	if existing then
		existing:Destroy()
	end

	local travelEvent = Net.get(RemoteNames.Events.RequestWorldTravel)

	local dimmer = UICreate("TextButton", {
		Name = "WorldPreviewModal",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		Text = "",
		AutoButtonColor = false,
		Parent = hud,
	}) :: TextButton

	local card = UICreate("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 460),
		BackgroundColor3 = Theme.Panel,
		Parent = dimmer,
	}, {
		UICreate("UICorner", { CornerRadius = UDim.new(0, 14) }),
		UICreate("UIStroke", { Color = rankColor, Thickness = 2, Transparency = 0.3 }),
	}) :: Frame

	local hero = buildHeroBanner(UDim2.new(1, 0, 0, 130), rankColor, world.displayName, 14)
	hero.Parent = card

	UICreate("TextLabel", {
		Position = UDim2.fromOffset(16, 138),
		Size = UDim2.new(1, -32, 0, 18),
		BackgroundTransparency = 1,
		Text = `Requires {rank.name} Rank  •  Level {world.requiredLevel}`,
		Font = Theme.Font,
		TextSize = 13,
		TextColor3 = rankColor,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})

	UICreate("TextLabel", {
		Position = UDim2.fromOffset(16, 160),
		Size = UDim2.new(1, -32, 0, 44),
		BackgroundTransparency = 1,
		Text = world.description,
		TextWrapped = true,
		Font = Theme.FontRegular,
		TextSize = 13,
		TextColor3 = Theme.TextSecondary,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})

	local statRow = UICreate("Frame", {
		Position = UDim2.fromOffset(16, 210),
		Size = UDim2.new(1, -32, 0, 32),
		BackgroundTransparency = 1,
		Parent = card,
	}, {
		UICreate("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }),
	})
	buildStatRow("World XP Bonus", formatMultiplier(world.xpMultiplier), Theme.Accent).Parent = statRow
	buildStatRow("Population", formatPopulationText(latestPopulation[world.id]), Theme.TextPrimary).Parent = statRow

	UICreate("TextLabel", {
		Position = UDim2.fromOffset(16, 252),
		Size = UDim2.new(1, -32, 0, 16),
		BackgroundTransparency = 1,
		Text = "UNLOCKS",
		Font = Theme.FontRegular,
		TextSize = 10,
		TextColor3 = Theme.TextSecondary,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})

	local unlocksList = UICreate("Frame", {
		Position = UDim2.fromOffset(16, 270),
		Size = UDim2.new(1, -32, 0, 80),
		BackgroundTransparency = 1,
		Parent = card,
	}, {
		UICreate("UIListLayout", { Padding = UDim.new(0, 4) }),
	})
	for _, unlockText in getUnlocksForRank(rank) do
		UICreate("TextLabel", {
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			Text = `•  {unlockText}`,
			Font = Theme.FontRegular,
			TextSize = 13,
			TextColor3 = Theme.TextPrimary,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = unlocksList,
		})
	end

	local closeButton = UICreate("TextButton", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(120, 34),
		BackgroundColor3 = Theme.Background,
		Text = "Close",
		Font = Theme.FontRegular,
		TextSize = 14,
		TextColor3 = Theme.TextSecondary,
		Parent = card,
	}, { UICreate("UICorner", { CornerRadius = UDim.new(0, 8) }) }) :: TextButton

	local travelButton = UICreate("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(140, 34),
		BackgroundColor3 = unlocked and rankColor or Theme.Background,
		Text = unlocked and "Travel" or `Requires Lvl {world.requiredLevel}`,
		Font = Theme.Font,
		TextSize = 14,
		TextColor3 = unlocked and Theme.Background or Theme.TextSecondary,
		Parent = card,
	}, { UICreate("UICorner", { CornerRadius = UDim.new(0, 8) }) }) :: TextButton

	closeButton.MouseButton1Click:Connect(function()
		dimmer:Destroy()
	end)
	dimmer.MouseButton1Click:Connect(function()
		dimmer:Destroy()
	end)
	travelButton.MouseButton1Click:Connect(function()
		if not unlocked then
			return
		end
		travelEvent:FireServer(world.id)
		dimmer:Destroy()
	end)
end

local function buildPanel(hud: ScreenGui): Frame
	populationLabels = {}

	local panel = UICreate("Frame", {
		Name = "WorldPanel",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -20, 0.5, 0),
		Size = UDim2.fromOffset(360, 520),
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
		UICreate("UIListLayout", { Padding = UDim.new(0, 10) }),
	})

	local travelEvent = Net.get(RemoteNames.Events.RequestWorldTravel)

	for _, world in WorldConfig.Worlds do
		local unlocked = State.level >= world.requiredLevel
		local rank = RankConfig.getRankByName(world.requiredRank) or RankConfig.Ranks[1]
		local rankColor = rank.color

		local card = UICreate("Frame", {
			Size = UDim2.new(1, 0, 0, 190),
			BackgroundColor3 = Theme.PanelLight,
			ClipsDescendants = true,
			Parent = scroll,
		}, {
			UICreate("UICorner", { CornerRadius = UDim.new(0, 10) }),
		}) :: Frame

		local hero = buildHeroBanner(UDim2.new(1, 0, 0, 54), rankColor, world.displayName, 10)
		hero.BackgroundTransparency = unlocked and 0 or 0.35
		hero.Parent = card

		UICreate("TextLabel", {
			Position = UDim2.fromOffset(12, 58),
			Size = UDim2.new(1, -24, 0, 16),
			BackgroundTransparency = 1,
			Text = `Requires {rank.name} Rank  •  Level {world.requiredLevel}`,
			Font = Theme.Font,
			TextSize = 12,
			TextColor3 = unlocked and rankColor or Theme.TextSecondary,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})

		UICreate("TextLabel", {
			Position = UDim2.fromOffset(12, 76),
			Size = UDim2.new(1, -24, 0, 30),
			BackgroundTransparency = 1,
			Text = world.description,
			TextWrapped = true,
			Font = Theme.FontRegular,
			TextSize = 11,
			TextColor3 = Theme.TextSecondary,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})

		local statRow = UICreate("Frame", {
			Position = UDim2.fromOffset(12, 108),
			Size = UDim2.new(1, -24, 0, 30),
			BackgroundTransparency = 1,
			Parent = card,
		}, {
			UICreate("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }),
		})
		buildStatRow("World XP Bonus", formatMultiplier(world.xpMultiplier), Theme.Accent).Parent = statRow

		local populationStat = buildStatRow("Population", formatPopulationText(latestPopulation[world.id]), Theme.TextPrimary)
		populationStat.Parent = statRow
		populationLabels[world.id] = populationStat:FindFirstChild("Value") :: TextLabel

		local previewButton = UICreate("TextButton", {
			Position = UDim2.fromOffset(12, 150),
			Size = UDim2.fromOffset(90, 28),
			BackgroundColor3 = Theme.Background,
			Text = "Preview",
			Font = Theme.FontRegular,
			TextSize = 13,
			TextColor3 = Theme.TextSecondary,
			Parent = card,
		}, { UICreate("UICorner", { CornerRadius = UDim.new(0, 6) }) }) :: TextButton

		local travelButton = UICreate("TextButton", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 150),
			Size = UDim2.fromOffset(90, 28),
			BackgroundColor3 = unlocked and rankColor or Theme.Background,
			Text = unlocked and "Travel" or `Lvl {world.requiredLevel}`,
			Font = Theme.FontRegular,
			TextSize = 13,
			TextColor3 = unlocked and Theme.Background or Theme.TextSecondary,
			Parent = card,
		}, { UICreate("UICorner", { CornerRadius = UDim.new(0, 6) }) }) :: TextButton

		previewButton.MouseButton1Click:Connect(function()
			openPreviewModal(hud, world, rank, rankColor, unlocked)
		end)

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
	panel = buildPanel(hud)

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

	toggleButton.MouseButton1Click:Connect(WorldSelectController.toggle)

	-- Rebuild the panel's lock/unlock state whenever the player's level changes,
	-- preserving whether it was open.
	State.Changed:Connect(function()
		local current = panel :: Frame
		local wasVisible = current.Visible
		current:Destroy()

		local rebuilt = buildPanel(hud)
		rebuilt.Visible = wasVisible
		panel = rebuilt
	end)

	Net.get(RemoteNames.Events.WorldTravelDenied).OnClientEvent:Connect(function(reason: string)
		showToast(reason, Theme.Danger)
	end)

	Net.get(RemoteNames.Events.WorldPopulationUpdated).OnClientEvent:Connect(function(snapshot: { [string]: number })
		latestPopulation = snapshot
		for worldId, label in populationLabels do
			label.Text = formatPopulationText(latestPopulation[worldId])
		end
	end)
end

return WorldSelectController
