--!strict
-- Loads/saves each player's profile via ProfileService with session-locking so a
-- player can't duplicate progress by rejoining across servers too quickly.

local Players = game:GetService("Players")

local ProfileService = require(script.Parent.Parent.Packages.ProfileService)
local PlayerDataSchema = require(game:GetService("ReplicatedStorage").Shared.Config.PlayerDataSchema)
local Signal = require(game:GetService("ReplicatedStorage").Shared.Util.Signal)

type PlayerProfile = PlayerDataSchema.PlayerProfile

local PlayerDataService = {}

local ProfileStore = ProfileService.GetProfileStore(PlayerDataSchema.ProfileStoreName, PlayerDataSchema.Default)

local profiles: { [Player]: any } = {}

-- Fires (player: Player) once a profile has finished loading and is safe to read.
PlayerDataService.DataLoaded = Signal.new()
-- Fires (player: Player) right before a profile is released (player leaving).
PlayerDataService.DataReleasing = Signal.new()

local function onPlayerAdded(player: Player)
	local profile = ProfileStore:LoadProfileAsync(`Player_{player.UserId}`, "ForceLoad")

	if not profile then
		-- Session couldn't be claimed (e.g. DataStore outage). Kick so the player
		-- doesn't play without their progress saving.
		player:Kick("Failed to load your data. Please rejoin in a moment.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile() -- fills in any fields added to PlayerDataSchema.Default since this profile was created

	profile:ListenToRelease(function()
		PlayerDataService.DataReleasing:Fire(player)
		profiles[player] = nil
		if player.Parent == Players then
			player:Kick("Your data session ended. Please rejoin.")
		end
	end)

	if player.Parent == Players then
		profiles[player] = profile
		PlayerDataService.DataLoaded:Fire(player)
	else
		-- Player left before the profile finished loading.
		profile:Release()
	end
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		profile:Release()
	end
end

function PlayerDataService.get(player: Player): PlayerProfile?
	local profile = profiles[player]
	return profile and profile.Data
end

function PlayerDataService.getProfile(player: Player): any?
	return profiles[player]
end

function PlayerDataService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return PlayerDataService
