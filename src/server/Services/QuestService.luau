--!strict
-- Tracks quest progress for both quest kinds in QuestConfig:
--   - Daily quests reset every UTC day and are claimed with a button, so players come
--     back to the panel (and see what else is close to done).
--   - The Island Journal is one-time and pays out the instant it completes, so every
--     first step of the loop (booth set up, first donation, first landmark) lands with
--     an immediate reward instead of a chore.
-- Other services call QuestService.reportProgress(player, tag) whenever something
-- quest-relevant happens; they never need to know which quests listen to that tag.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestConfig = require(Shared.Config.QuestConfig)
local PlayerDataSchema = require(Shared.Config.PlayerDataSchema)
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)
local Theme = require(Shared.Util.Theme)

local PlayerDataService = require(script.Parent.PlayerDataService)
local XPService = require(script.Parent.XPService)
local CosmeticService = require(script.Parent.CosmeticService)

type PlayerProfile = PlayerDataSchema.PlayerProfile

local QuestService = {}

local function currentDayNumber(): number
	return math.floor(os.time() / 86400)
end

local function resetIfNewDay(profile: PlayerProfile)
	local lastDay = math.floor(profile.quests.lastResetUnix / 86400)
	if currentDayNumber() ~= lastDay then
		profile.quests.progress = {}
		profile.quests.completedToday = {}
		profile.quests.lastResetUnix = os.time()
	end
end

local function buildQuestSnapshot(profile: PlayerProfile)
	local snapshot = {}
	for _, quest in QuestConfig.DailyQuests do
		table.insert(snapshot, {
			id = quest.id,
			kind = "daily",
			description = quest.description,
			goalCount = quest.goalCount,
			xpReward = quest.xpReward,
			progress = profile.quests.progress[quest.id] or 0,
			completed = table.find(profile.quests.completedToday, quest.id) ~= nil,
		})
	end
	for _, quest in QuestConfig.Journal do
		table.insert(snapshot, {
			id = quest.id,
			kind = "journal",
			description = quest.description,
			goalCount = quest.goalCount,
			xpReward = quest.xpReward,
			titleReward = quest.titleReward,
			progress = profile.journal.progress[quest.id] or 0,
			completed = profile.journal.claimed[quest.id] == true,
		})
	end
	return snapshot
end

local function pushQuestUpdate(player: Player, profile: PlayerProfile)
	Net.get(RemoteNames.Events.QuestsUpdated):FireClient(player, buildQuestSnapshot(profile))
end

local function notify(player: Player, text: string, color: Color3?)
	Net.get(RemoteNames.Events.Notify):FireClient(player, { text = text, color = color or Theme.Accent })
end

local function completeJournalEntry(player: Player, profile: PlayerProfile, quest: QuestConfig.QuestInfo)
	profile.journal.claimed[quest.id] = true
	XPService.grantXp(player, quest.xpReward, `journal_{quest.id}`)
	local suffix = ""
	if quest.titleReward then
		CosmeticService.grantTitle(player, quest.titleReward)
		suffix = ` · Title unlocked: {quest.titleReward}`
	end
	notify(player, `Journal complete: {quest.description}{suffix}`, Theme.Success)
end

local function advanceJournal(player: Player, profile: PlayerProfile, tag: string, amount: number): boolean
	local changed = false
	local setStyle = QuestConfig.SetStyleTags[tag] == true
	for _, quest in QuestConfig.getJournalByTag(tag) do
		if profile.journal.claimed[quest.id] then
			continue
		end
		local current = profile.journal.progress[quest.id] or 0
		local nextValue = if setStyle then math.max(current, amount) else current + amount
		nextValue = math.min(nextValue, quest.goalCount)
		if nextValue ~= current then
			profile.journal.progress[quest.id] = nextValue
			changed = true
		end
		if nextValue >= quest.goalCount then
			completeJournalEntry(player, profile, quest)
			changed = true
		end
	end
	return changed
end

local function advanceDailies(profile: PlayerProfile, tag: string, amount: number): boolean
	local changed = false
	for _, quest in QuestConfig.getQuestsByTag(tag) do
		if table.find(profile.quests.completedToday, quest.id) then
			continue
		end
		local current = profile.quests.progress[quest.id] or 0
		local nextValue = math.min(current + amount, quest.goalCount)
		if nextValue ~= current then
			profile.quests.progress[quest.id] = nextValue
			changed = true
		end
	end
	return changed
end

-- `amount` is an increment for normal tags, or the absolute value reached for tags in
-- QuestConfig.SetStyleTags (e.g. the current login streak).
function QuestService.reportProgress(player: Player, tag: string, amount: number?)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end

	resetIfNewDay(profile)

	local value = amount or 1
	local dailyChanged = advanceDailies(profile, tag, value)
	local journalChanged = advanceJournal(player, profile, tag, value)

	if dailyChanged or journalChanged then
		pushQuestUpdate(player, profile)
	end
end

local function onRequestClaimQuest(player: Player, questId: unknown)
	if type(questId) ~= "string" then
		return
	end

	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end

	resetIfNewDay(profile)

	local quest = QuestConfig.getQuestById(questId)
	if not quest then
		return
	end

	if table.find(profile.quests.completedToday, questId) then
		return -- already claimed
	end

	local progress = profile.quests.progress[questId] or 0
	if progress < quest.goalCount then
		return -- not finished yet
	end

	table.insert(profile.quests.completedToday, questId)
	XPService.grantXp(player, quest.xpReward, `quest_{questId}`)
	pushQuestUpdate(player, profile)
end

function QuestService.start()
	PlayerDataService.DataLoaded:Connect(function(player: Player)
		local profile = PlayerDataService.get(player)
		if profile then
			resetIfNewDay(profile)
			pushQuestUpdate(player, profile)
		end
	end)

	Net.get(RemoteNames.Events.RequestClaimQuest).OnServerEvent:Connect(onRequestClaimQuest)
end

return QuestService
