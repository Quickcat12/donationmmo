--!strict
-- Tuning for the "always earning something" layer: login streaks, playtime/booth-duty
-- XP and landmark discovery. Kept together so the whole free-XP budget can be judged in
-- one place: it has to be enough that a free player always feels progress, but small
-- next to donating, or the richer-worlds promise (people up there paid to get there)
-- stops being true.

local RewardConfig = {}

-- Daily login streak: day N of each 7-day cycle pays StreakRewards[N]. Every completed
-- week adds StreakWeekBonus to the whole next cycle (capped), so a long streak is worth
-- protecting - missing a day resets to day 1.
RewardConfig.StreakRewards = { 150, 250, 400, 600, 800, 1000, 2000 }
RewardConfig.StreakWeekBonus = 0.25
RewardConfig.StreakMaxWeekBonus = 1.0

function RewardConfig.getStreakReward(streakCount: number): number
	local cycleDay = ((streakCount - 1) % #RewardConfig.StreakRewards) + 1
	local weeksDone = (streakCount - 1) // #RewardConfig.StreakRewards
	local bonus = math.min(weeksDone * RewardConfig.StreakWeekBonus, RewardConfig.StreakMaxWeekBonus)
	return math.floor(RewardConfig.StreakRewards[cycleDay] * (1 + bonus))
end

-- Playtime XP: paid every PlaytimeIntervalSeconds. Standing at your own booth pays
-- ~2.5x more - booths with their owners present get far more donations, so the reward
-- nudges players to stay where donors can find them. The daily cap (pre-multiplier)
-- stops idling from becoming a ladder of its own: ~2 hours of booth duty a day.
RewardConfig.PlaytimeIntervalSeconds = 180
RewardConfig.PlaytimeXp = 10
RewardConfig.BoothDutyXp = 25
RewardConfig.BoothDutyRadius = 18
RewardConfig.PlaytimeDailyCap = 1000

return RewardConfig
