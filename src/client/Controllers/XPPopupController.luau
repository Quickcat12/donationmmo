--!strict
-- "+120 XP · Donation x1.60" popups for every XP gain, plus a toast stack for server
-- notices (journal completions, title unlocks). Every action in the game pays XP; this
-- is what makes each payment felt. The multiplier is shown whenever it's above 1, so a
-- player sees their rank, VIP or a server blessing paying off in the moment.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)
local UICreate = require(Shared.Util.UICreate)
local Theme = require(Shared.Util.Theme)

local Dock = require(script.Parent.Parent.Dock)

local player = Players.LocalPlayer

local XPPopupController = {}

local SOURCE_LABELS: { [string]: string } = {
	donation_sent = "Donation",
	donation_received = "Donation received",
	xp_shop = "XP Shop",
	booth_duty = "Booth duty",
	playtime = "Playtime",
	daily_streak = "Daily streak",
	discovery = "Landmark",
}

local PREFIX_LABELS: { { string } } = {
	{ "obby_", "Obby" },
	{ "quest_", "Daily quest" },
	{ "journal_", "Journal" },
}

local function labelForSource(source: string): string
	local direct = SOURCE_LABELS[source]
	if direct then
		return direct
	end
	for _, pair in PREFIX_LABELS do
		if string.sub(source, 1, #pair[1]) == pair[1] then
			return pair[2]
		end
	end
	return "XP"
end

local popupLayer: Frame
local toastStack: Frame
local popSound: Sound
local activePopups = 0

local function build()
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = UICreate("ScreenGui", {
		Name = "RewardFeedback",
		ResetOnSpawn = false,
		DisplayOrder = 20,
		Parent = playerGui,
	})

	popupLayer = UICreate("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 104),
		Size = UDim2.fromOffset(360, 160),
		BackgroundTransparency = 1,
		Parent = gui,
	}) :: Frame

	toastStack = UICreate("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(460, 220),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UICreate("UIListLayout", {
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}) :: Frame

	Dock.autoScale(popupLayer)
	Dock.autoScale(toastStack)

	popSound = Instance.new("Sound")
	popSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	popSound.Volume = 0.25
	popSound.Parent = SoundService
end

local function showPopup(amount: number, source: string, multiplier: number?)
	local label = labelForSource(source)
	local multText = ""
	if multiplier and multiplier > 1.005 then
		multText = string.format("  x%.2f", multiplier)
	end

	-- Big grants (donations, quests) get a larger popup than ambient playtime ticks.
	local big = amount >= 500
	local slot = activePopups % 4
	activePopups += 1

	local popup = UICreate("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 40 + slot * 26),
		Size = UDim2.fromOffset(360, big and 34 or 24),
		BackgroundTransparency = 1,
		Text = `+{amount} XP  ·  {label}{multText}`,
		Font = Theme.Font,
		TextSize = big and 26 or 18,
		TextColor3 = big and Theme.Accent or Color3.fromRGB(235, 235, 240),
		TextStrokeTransparency = 0.35,
		TextTransparency = 1,
		Parent = popupLayer,
	}) :: TextLabel

	TweenService:Create(popup, TweenInfo.new(0.15), { TextTransparency = 0 }):Play()
	local rise = TweenService:Create(popup, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = popup.Position - UDim2.fromOffset(0, 40),
	})
	rise:Play()
	task.delay(1.1, function()
		local fade = TweenService:Create(popup, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		popup:Destroy()
		activePopups = math.max(0, activePopups - 1)
	end)

	popSound.PlaybackSpeed = big and 0.9 or 1.15
	popSound:Play()
end

function XPPopupController.toast(text: string, color: Color3?)
	local accent = color or Theme.Accent
	local card = UICreate("TextLabel", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.1,
		Text = text,
		TextWrapped = true,
		Font = Theme.Font,
		TextSize = 15,
		TextColor3 = accent,
		Parent = toastStack,
	}, {
		UICreate("UICorner", { CornerRadius = UDim.new(0, 10) }),
		UICreate("UIStroke", { Color = accent, Transparency = 0.5, Thickness = 1.5 }),
	}) :: TextLabel

	task.delay(5, function()
		local fade = TweenService:Create(card, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		card:Destroy()
	end)
end

function XPPopupController.start()
	build()

	Net.get(RemoteNames.Events.XpChanged).OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.gained) == "number" and payload.gained > 0 then
			showPopup(payload.gained, tostring(payload.source), payload.multiplier)
		end
	end)

	Net.get(RemoteNames.Events.Notify).OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.text) == "string" then
			XPPopupController.toast(payload.text, payload.color)
		end
	end)
end

return XPPopupController
