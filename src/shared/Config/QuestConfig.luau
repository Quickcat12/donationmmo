--!strict

export type QuestInfo = {
	id: string,
	tag: string, -- progress event tag other services call QuestService.reportProgress(player, tag) with
	description: string,
	goalCount: number,
	xpReward: number,
	titleReward: string?, -- journal only: a cosmetic title unlocked on completion
}

local QuestConfig = {}

QuestConfig.DailyQuests = {
	{
		id = "daily_donate_once",
		tag = "donate_sent",
		description = "Donate to another player",
		goalCount = 1,
		xpReward = 500,
	},
	{
		id = "daily_receive_donation",
		tag = "donate_received",
		description = "Receive a donation from another player",
		goalCount = 1,
		xpReward = 400,
	},
	{
		id = "daily_finish_obby_3",
		tag = "obby_finish",
		description = "Complete 3 obby courses",
		goalCount = 3,
		xpReward = 600,
	},
	-- Replaces "visit a different world" until every world's placeId is filled in
	-- (WorldConfig): with travel disabled nobody could finish it, and an impossible
	-- daily teaches players to ignore the quest panel.
	{
		id = "daily_booth_duty",
		tag = "booth_duty",
		description = "Spend 10 minutes at your booth",
		goalCount = 10,
		xpReward = 300,
	},
} :: { QuestInfo }

-- The Island Journal: one-time quests that teach the whole loop in order (set up a
-- booth, donate, receive, explore, play) and pay out the moment they complete - no
-- claim click - so every first step lands with an immediate reward. Progress for "set"
-- style tags (streak_day) is the best value reached, not a running sum.
QuestConfig.Journal = {
	{
		id = "journal_setup_booth",
		tag = "link_gamepass",
		description = "Set up your booth: link a Gamepass",
		goalCount = 1,
		xpReward = 300,
	},
	{
		id = "journal_first_donation",
		tag = "donate_sent",
		description = "Make your first donation",
		goalCount = 1,
		xpReward = 750,
	},
	{
		id = "journal_first_received",
		tag = "donate_received",
		description = "Receive your first donation",
		goalCount = 1,
		xpReward = 500,
	},
	{
		id = "journal_lighthouse",
		tag = "discovery_lighthouse",
		description = "Climb to the top of the lighthouse",
		goalCount = 1,
		xpReward = 250,
	},
	{
		id = "journal_explorer_3",
		tag = "discovery",
		description = "Discover 3 island landmarks",
		goalCount = 3,
		xpReward = 300,
	},
	{
		id = "journal_explorer_all",
		tag = "discovery",
		description = "Discover every landmark on the island",
		goalCount = 8,
		xpReward = 1200,
		titleReward = "Island Explorer",
	},
	{
		id = "journal_obbies_all",
		tag = "obby_unique",
		description = "Finish every islet obby",
		goalCount = 3,
		xpReward = 900,
		titleReward = "Islet Runner",
	},
	{
		id = "journal_booth_30",
		tag = "booth_duty",
		description = "Spend 30 minutes at your booth",
		goalCount = 30,
		xpReward = 600,
	},
	{
		id = "journal_streak_3",
		tag = "streak_day",
		description = "Log in 3 days in a row",
		goalCount = 3,
		xpReward = 500,
	},
	{
		id = "journal_streak_7",
		tag = "streak_day",
		description = "Log in 7 days in a row",
		goalCount = 7,
		xpReward = 1500,
		titleReward = "Devoted",
	},
} :: { QuestInfo }

-- Tags whose progress is "highest value reached" rather than a running count.
QuestConfig.SetStyleTags = {
	streak_day = true,
	discovery = true,
}

function QuestConfig.getJournalByTag(tag: string): { QuestInfo }
	local matches = {}
	for _, quest in QuestConfig.Journal do
		if quest.tag == tag then
			table.insert(matches, quest)
		end
	end
	return matches
end

function QuestConfig.getQuestById(id: string): QuestInfo?
	for _, quest in QuestConfig.DailyQuests do
		if quest.id == id then
			return quest
		end
	end
	return nil
end

function QuestConfig.getQuestsByTag(tag: string): { QuestInfo }
	local matches = {}
	for _, quest in QuestConfig.DailyQuests do
		if quest.tag == tag then
			table.insert(matches, quest)
		end
	end
	return matches
end

return QuestConfig
