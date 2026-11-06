--!strict
-- Persistent top-of-screen bar. It leads with the rank (color + title) and the distance
-- to the NEXT color ("760 XP to Green"), not the raw level: players identify by class,
-- and keeping the next class in view at all times is the aspiration loop. The pill on the
-- right shows what a donation is worth right now, so the climb's payoff (bigger
-- multipliers) is always visible. Below it, the booth-duty timer tells players exactly
-- what standing at their booth earns.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RankConfig = require(Shared.Config.RankConfig)
local RewardConfig = require(Shared.Config.RewardConfig)
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)
local UICreate = require(Shared.Util.UICreate)
local Theme = require(Shared.Util.Theme)

local State = require(script.Parent.Parent.State)

local player = Players.LocalPlayer

local HUDController = {}

local fillBar: Frame
local rankChip: Frame
local chipLetter: TextLabel
local levelLabel: TextLabel
local rankLabel: TextLabel
local multiplierLabel: TextLabel
local dutyLabel: TextLabel

local function formatNumber(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

local function build()
	local screenGui = UICreate("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})

	local container = UICreate("Frame", {
		Name = "XPBarContainer",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(460, 60),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.08,
		Parent = screenGui,
	}, {
		UICreate("UICorner", { CornerRadius = UDim.new(0, 12) }),
		UICreate("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Transparency = 0.88, Thickness = 1 }),
	})

	rankChip = UICreate("Frame", {
		Name = "RankChip",
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = Theme.Accent,
		Parent = container,
	}, {
		UICreate("UICorner", { CornerRadius = UDim.new(1, 0) }),
		UICreate("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Transparency = 0.6, Thickness = 2 }),
	}) :: Frame

	chipLetter = UICreate("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "G",
		Font = Theme.Font,
		TextSize = 20,
		TextColor3 = Color3.fromRGB(20, 20, 25),
		Parent = rankChip,
	}) :: TextLabel

	rankLabel = UICreate("TextLabel", {
		Name = "RankLabel",
		Position = UDim2.fromOffset(60, 6),
		Size = UDim2.fromOffset(250, 20),
		BackgroundTransparency = 1,
		Text = "Gray Wanderer",
		Font = Theme.Font,
		TextSize = 17,
		TextColor3 = Theme.TextPrimary,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = container,
	}) :: TextLabel

	levelLabel = UICreate("TextLabel", {
		Name = "LevelLabel",
		Position = UDim2.fromOffset(60, 25),
		Size = UDim2.fromOffset(250, 16),
		BackgroundTransparency = 1,
		Text = "",
		Font = Theme.FontRegular,
		TextSize = 13,
		TextColor3 = Theme.TextSecondary,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = container,
	}) :: TextLabel

	multiplierLabel = UICreate("TextLabel", {
		Name = "Multiplier",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(120, 22),
		BackgroundColor3 = Theme.Background,
		Text = "Donation XP x1.00",
		Font = Theme.Font,
		TextSize = 12,
		TextColor3 = Theme.Accent,
		Parent = container,
	}, { UICreate("UICorner", { CornerRadius = UDim.new(1, 0) }) }) :: TextLabel

	local barTrack = UICreate("Frame", {
		Name = "BarTrack",
		Position = UDim2.fromOffset(60, 44),
		Size = UDim2.new(1, -70, 0, 8),
		BackgroundColor3 = Theme.Background,
		Parent = container,
	}, {
		UICreate("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})

	fillBar = UICreate("Frame", {
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Theme.Accent,
		Parent = barTrack,
	}, {
		UICreate("UICorner", { CornerRadius = UDim.new(1, 0) }),
		UICreate("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 200, 200)),
		}),
	}) :: Frame

	dutyLabel = UICreate("TextLabel", {
		Name = "BoothDuty",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 76),
		Size = UDim2.fromOffset(330, 22),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.25,
		Text = "",
		Font = Theme.FontRegular,
		TextSize = 12,
		TextColor3 = Theme.TextSecondary,
		Visible = false,
		Parent = screenGui,
	}, { UICreate("UICorner", { CornerRadius = UDim.new(1, 0) }) }) :: TextLabel
end

local function refresh()
	local rank = RankConfig.getRankByName(State.rank)
	if rank then
		rankChip.BackgroundColor3 = rank.color
		chipLetter.Text = string.sub(rank.name, 1, 1)
		rankLabel.Text = rank.title
		rankLabel.TextColor3 = rank.color
		fillBar.BackgroundColor3 = rank.color

		local nextRank = RankConfig.getNextRank(rank)
		if nextRank and State.xpToNext then
			levelLabel.Text = `Lv {State.level}  ·  {formatNumber(State.xpToNext)} XP to {nextRank.name}`
		else
			levelLabel.Text = `Lv {State.level}  ·  The ladder keeps climbing`
		end
	end
	multiplierLabel.Text = string.format("Donation XP x%.2f", State.multiplier)

	TweenService:Create(fillBar, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
		Size = UDim2.new(State.progress, 0, 1, 0),
	}):Play()
end

local function onSessionTick(payload: { secondsLeft: number, onDuty: boolean, capped: boolean })
	dutyLabel.Visible = true
	if payload.capped then
		dutyLabel.Text = "Daily playtime XP collected · come back tomorrow"
		dutyLabel.TextColor3 = Theme.TextSecondary
		return
	end
	local secs = math.max(0, math.floor(payload.secondsLeft))
	local clock = string.format("%d:%02d", secs // 60, secs % 60)
	if payload.onDuty then
		dutyLabel.Text = `Booth duty: +{RewardConfig.BoothDutyXp} XP in {clock}`
		dutyLabel.TextColor3 = Theme.Success
	else
		dutyLabel.Text = `+{RewardConfig.PlaytimeXp} XP in {clock} · stand at your booth for +{RewardConfig.BoothDutyXp}`
		dutyLabel.TextColor3 = Theme.TextSecondary
	end
end

function HUDController.start()
	build()
	refresh()

	State.Changed:Connect(refresh)

	Net.get(RemoteNames.Events.XpChanged).OnClientEvent:Connect(function(payload)
		State.update(payload)
	end)
	Net.get(RemoteNames.Events.SessionRewardTick).OnClientEvent:Connect(onSessionTick)
end

return HUDController
