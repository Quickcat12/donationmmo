--!strict
-- One-time XP for finding landmarks around the island. Any BasePart tagged "Discovery"
-- (WorldBuilderService places invisible trigger volumes at each landmark) needs:
--   DiscoveryId (string)  - stable id, stored in the profile; never rename a shipped one
--   DisplayName (string)  - shown in the "Discovered!" banner
--   XpReward    (number)  - one-time payout
-- Found ids persist, so exploring is a finite checklist per world - the journal's
-- Explorer quests and the client's "?" markers both read from the same set.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local RemoteNames = require(Shared.Net.RemoteNames)

local PlayerDataService = require(script.Parent.PlayerDataService)
local XPService = require(script.Parent.XPService)
local QuestService = require(script.Parent.QuestService)

local DISCOVERY_TAG = "Discovery"
local DEFAULT_XP = 150

local DiscoveryService = {}

local function totalDiscoveries(): number
	return #CollectionService:GetTagged(DISCOVERY_TAG)
end

local function countFound(profile: any): number
	local found = 0
	for _, part in CollectionService:GetTagged(DISCOVERY_TAG) do
		local id = part:GetAttribute("DiscoveryId")
		if type(id) == "string" and profile.discoveries[id] then
			found += 1
		end
	end
	return found
end

local function onTouched(part: BasePart, hit: BasePart)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end
	local profile = PlayerDataService.get(player)
	local id = part:GetAttribute("DiscoveryId")
	if not profile or type(id) ~= "string" or profile.discoveries[id] then
		return
	end

	profile.discoveries[id] = true
	local xp = (part:GetAttribute("XpReward") :: number?) or DEFAULT_XP
	XPService.grantXp(player, xp, "discovery")

	local found = countFound(profile)
	Net.get(RemoteNames.Events.DiscoveryFound):FireClient(player, {
		id = id,
		name = part:GetAttribute("DisplayName") or id,
		found = found,
		total = totalDiscoveries(),
	})
	-- "discovery" is a set-style tag (QuestConfig.SetStyleTags): progress is the real
	-- number found, so it can never drift from the profile's own record.
	QuestService.reportProgress(player, "discovery", found)
	QuestService.reportProgress(player, `discovery_{id}`)
end

local function hook(instance: Instance)
	if instance:IsA("BasePart") then
		instance.Touched:Connect(function(hit)
			onTouched(instance, hit)
		end)
	end
end

function DiscoveryService.start()
	for _, part in CollectionService:GetTagged(DISCOVERY_TAG) do
		hook(part)
	end
	CollectionService:GetInstanceAddedSignal(DISCOVERY_TAG):Connect(hook)

	PlayerDataService.DataLoaded:Connect(function(player: Player)
		local profile = PlayerDataService.get(player)
		if not profile then
			return
		end
		local found = {}
		for id in profile.discoveries do
			table.insert(found, id)
		end
		Net.get(RemoteNames.Events.DiscoveriesUpdated):FireClient(player, found)
	end)
end

return DiscoveryService
