--!strict
-- Daily login streak. Claimed automatically on join (and at UTC midnight for players who
-- are online through it), with an escalating 7-day reward track. A visible streak that
-- resets when you miss a day is one of the strongest "come back tomorrow" hooks there
-- is, and every claim also feeds the journal's streak quests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RewardConfig = require(Shared.Config.RewardConfig)
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)

local PlayerDataService = require(script.Parent.PlayerDataService)
local XPService = require(script.Parent.XPService)
local QuestService = require(script.Parent.QuestService)

local DailyRewardService = {}

local MIDNIGHT_CHECK_SECONDS = 60

local function today(): number
	return os.time() // 86400
end

local function pushState(player: Player, profile: any, justClaimed: number?)
	local upcoming = {}
	-- The next 7 rewards starting from the current cycle's day 1, so the client can
	-- draw the full week track with today's tile highlighted.
	local count = math.max(profile.streak.count, 1)
	local cycleStart = count - ((count - 1) % #RewardConfig.StreakRewards)
	for i = 0, #RewardConfig.StreakRewards - 1 do
		table.insert(upcoming, RewardConfig.getStreakReward(cycleStart + i))
	end
	Net.get(RemoteNames.Events.DailyStreakUpdated):FireClient(player, {
		count = profile.streak.count,
		best = profile.streak.best,
		cycleDay = ((count - 1) % #RewardConfig.StreakRewards) + 1,
		rewards = upcoming,
		justClaimed = justClaimed,
	})
end

local function tryClaim(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end

	local day = today()
	local streak = profile.streak
	if streak.lastClaimDay == day then
		pushState(player, profile, nil)
		return
	end

	streak.count = if streak.lastClaimDay == day - 1 then streak.count + 1 else 1
	streak.best = math.max(streak.best, streak.count)
	streak.lastClaimDay = day

	local reward = RewardConfig.getStreakReward(streak.count)
	XPService.grantXp(player, reward, "daily_streak")
	QuestService.reportProgress(player, "streak_day", streak.count)
	pushState(player, profile, reward)
end

function DailyRewardService.start()
	PlayerDataService.DataLoaded:Connect(function(player: Player)
		-- Short delay so the client's UI is built before the streak popup arrives.
		task.delay(3, tryClaim, player)
	end)

	task.spawn(function()
		local lastDay = today()
		while true do
			task.wait(MIDNIGHT_CHECK_SECONDS)
			local day = today()
			if day ~= lastDay then
				lastDay = day
				for _, player in Players:GetPlayers() do
					task.spawn(tryClaim, player)
				end
			end
		end
	end)
end

return DailyRewardService
