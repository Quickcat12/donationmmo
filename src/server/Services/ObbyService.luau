--!strict
-- Generic completion tracking for parkour/obby courses. I can't build the physical
-- courses (that's 3D level design, not scriptable), but any finish-line part a builder
-- places just needs:
--   - CollectionService tag "ObbyFinish"
--   - Optional NumberValue attribute "XpReward" (defaults to 300 if unset)
--   - Optional StringValue attribute "CourseId" (defaults to the part's Name; used only
--     for the per-player cooldown so one course can't be spammed for infinite XP)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local XPService = require(script.Parent.XPService)
local QuestService = require(script.Parent.QuestService)

local FINISH_TAG = "ObbyFinish"
local DEFAULT_XP_REWARD = 300
local COOLDOWN_SECONDS = 30

local ObbyService = {}

-- [player] = { [courseId]: lastCompletionUnix }
local cooldowns: { [Player]: { [string]: number } } = {}

local function onFinishTouched(finishPart: BasePart, hit: BasePart)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	local courseId = (finishPart:GetAttribute("CourseId") :: string?) or finishPart.Name
	local playerCooldowns = cooldowns[player]
	if not playerCooldowns then
		playerCooldowns = {}
		cooldowns[player] = playerCooldowns
	end

	local lastCompletion = playerCooldowns[courseId]
	if lastCompletion and os.time() - lastCompletion < COOLDOWN_SECONDS then
		return
	end
	playerCooldowns[courseId] = os.time()

	local xpReward = (finishPart:GetAttribute("XpReward") :: number?) or DEFAULT_XP_REWARD
	XPService.grantXp(player, xpReward, `obby_{courseId}`)
	QuestService.reportProgress(player, "obby_finish")
end

local function hookFinishPart(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	instance.Touched:Connect(function(hit)
		onFinishTouched(instance, hit)
	end)
end

function ObbyService.start()
	for _, part in CollectionService:GetTagged(FINISH_TAG) do
		hookFinishPart(part)
	end
	CollectionService:GetInstanceAddedSignal(FINISH_TAG):Connect(hookFinishPart)

	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
	end)
end

return ObbyService
