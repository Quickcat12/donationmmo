--!strict

export type QuestInfo = {
	id: string,
	tag: string, -- progress event tag other services call QuestService.reportProgress(player, tag) with
	description: string,
	goalCount: number,
	xpReward: number,
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
	{
		id = "daily_visit_world",
		tag = "world_travel",
		description = "Visit a different world",
		goalCount = 1,
		xpReward = 250,
	},
} :: { QuestInfo }

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
