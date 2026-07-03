--!strict
-- Tracks daily quest progress. Other services call QuestService.reportProgress(player,
-- tag) whenever something quest-relevant happens (a donation, an obby finish, etc).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestConfig = require(Shared.Config.QuestConfig)
local PlayerDataSchema = require(Shared.Config.PlayerDataSchema)
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)

local PlayerDataService = require(script.Parent.PlayerDataService)
local XPService = require(script.Parent.XPService)

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
			description = quest.description,
			goalCount = quest.goalCount,
			xpReward = quest.xpReward,
			progress = profile.quests.progress[quest.id] or 0,
			completed = table.find(profile.quests.completedToday, quest.id) ~= nil,
		})
	end
	return snapshot
end

local function pushQuestUpdate(player: Player, profile: PlayerProfile)
	Net.get(RemoteNames.Events.QuestsUpdated):FireClient(player, buildQuestSnapshot(profile))
end

function QuestService.reportProgress(player: Player, tag: string, amount: number?)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end

	resetIfNewDay(profile)

	local quests = QuestConfig.getQuestsByTag(tag)
	if #quests == 0 then
		return
	end

	local changed = false
	for _, quest in quests do
		if table.find(profile.quests.completedToday, quest.id) then
			continue
		end
		local current = profile.quests.progress[quest.id] or 0
		profile.quests.progress[quest.id] = math.min(current + (amount or 1), quest.goalCount)
		changed = true
	end

	if changed then
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
