--!strict
-- Small, steady XP for being in the server, and more of it for standing at your own
-- booth ("booth duty"). Donation lobbies live on owners being present at their booths -
-- donors give to people, not empty stands - so the reward pushes players to the exact
-- spot where the core loop happens. Daily-capped in RewardConfig so idling can never
-- outpace actually donating or receiving.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RewardConfig = require(Shared.Config.RewardConfig)
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)

local PlayerDataService = require(script.Parent.PlayerDataService)
local XPService = require(script.Parent.XPService)
local QuestService = require(script.Parent.QuestService)
local StandService = require(script.Parent.StandService)

local PlaytimeService = {}

local POLL_SECONDS = 5

-- Seconds of booth duty / general playtime accumulated toward the next payout.
local elapsed: { [Player]: number } = {}
local boothSeconds: { [Player]: number } = {}

local function isOnBoothDuty(player: Player): boolean
	local stand = StandService.getStand(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local podium = stand and stand:FindFirstChild("Podium") :: BasePart?
	if not root or not podium then
		return false
	end
	return (root.Position - podium.Position).Magnitude <= RewardConfig.BoothDutyRadius
end

local function payout(player: Player, profile: any, onDuty: boolean)
	local day = os.time() // 86400
	if profile.playtime.day ~= day then
		profile.playtime.day = day
		profile.playtime.xpToday = 0
	end
	local base = onDuty and RewardConfig.BoothDutyXp or RewardConfig.PlaytimeXp
	local remaining = RewardConfig.PlaytimeDailyCap - profile.playtime.xpToday
	local amount = math.min(base, remaining)
	if amount <= 0 then
		return
	end
	profile.playtime.xpToday += amount
	XPService.grantXp(player, amount, onDuty and "booth_duty" or "playtime")
end

local function tick(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end

	local onDuty = isOnBoothDuty(player)
	elapsed[player] = (elapsed[player] or 0) + POLL_SECONDS

	-- Booth-duty minutes count toward quests separately from the XP payout, so the
	-- "10 minutes at your booth" daily still progresses after the XP cap is reached.
	if onDuty then
		boothSeconds[player] = (boothSeconds[player] or 0) + POLL_SECONDS
		if boothSeconds[player] >= 60 then
			boothSeconds[player] -= 60
			QuestService.reportProgress(player, "booth_duty", 1)
		end
	end

	if elapsed[player] >= RewardConfig.PlaytimeIntervalSeconds then
		elapsed[player] = 0
		payout(player, profile, onDuty)
	end

	Net.get(RemoteNames.Events.SessionRewardTick):FireClient(player, {
		secondsLeft = RewardConfig.PlaytimeIntervalSeconds - elapsed[player],
		onDuty = onDuty,
		capped = profile.playtime.day == os.time() // 86400
			and profile.playtime.xpToday >= RewardConfig.PlaytimeDailyCap,
	})
end

function PlaytimeService.start()
	Players.PlayerRemoving:Connect(function(player: Player)
		elapsed[player] = nil
		boothSeconds[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(POLL_SECONDS)
			for _, player in Players:GetPlayers() do
				task.spawn(tick, player)
			end
		end
	end)
end

return PlaytimeService
