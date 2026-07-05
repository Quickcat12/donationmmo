--!strict
-- Tracks each player's most recent obby checkpoint (CollectionService tag
-- "ObbyCheckpoint" - see WorldBuilderService.buildTestObby) and repositions their
-- character there on respawn, instead of always sending them back to the main
-- SpawnLocation. Missing a jump on a long course shouldn't cost all the progress made
-- on it.
--
-- Session-only by design (not persisted) - matches typical obby checkpoint UX, where
-- progress resets between play sessions rather than surviving a rejoin.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local CHECKPOINT_TAG = "ObbyCheckpoint"

local CheckpointService = {}

local lastCheckpoint: { [Player]: CFrame } = {}

local function onCheckpointTouched(part: BasePart, hit: BasePart)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end
	-- A couple of studs above the part's surface, so the player doesn't respawn
	-- half-embedded in the checkpoint itself.
	lastCheckpoint[player] = part.CFrame + Vector3.new(0, 4, 0)
end

local function hookCheckpoint(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	instance.Touched:Connect(function(hit)
		onCheckpointTouched(instance, hit)
	end)
end

local function onCharacterAdded(player: Player, character: Model)
	local checkpoint = lastCheckpoint[player]
	if not checkpoint then
		return
	end
	local rootPart = character:WaitForChild("HumanoidRootPart", 5)
	if rootPart then
		character:PivotTo(checkpoint)
	end
end

function CheckpointService.start()
	for _, part in CollectionService:GetTagged(CHECKPOINT_TAG) do
		hookCheckpoint(part)
	end
	CollectionService:GetInstanceAddedSignal(CHECKPOINT_TAG):Connect(hookCheckpoint)

	Players.PlayerAdded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			onCharacterAdded(player, character)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastCheckpoint[player] = nil
	end)
end

return CheckpointService
