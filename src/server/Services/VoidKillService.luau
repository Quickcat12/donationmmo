--!strict
-- The whole map floats high in the air (see WorldBuilderService.WorldY) with no floor
-- underneath - falling off the plaza or missing an obby jump means a long drop. This
-- kills any player who falls below WorldBuilderService.KillY so missing a jump actually
-- has a consequence; Roblox's default respawn then puts them back at the SpawnLocation.

local Players = game:GetService("Players")

local WorldBuilderService = require(script.Parent.WorldBuilderService)

local CHECK_INTERVAL_SECONDS = 0.5

local VoidKillService = {}

local function checkPlayer(player: Player)
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not rootPart or humanoid.Health <= 0 then
		return
	end

	if rootPart.Position.Y < WorldBuilderService.KillY then
		humanoid.Health = 0
	end
end

function VoidKillService.start()
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				checkPlayer(player)
			end
			task.wait(CHECK_INTERVAL_SECONDS)
		end
	end)
end

return VoidKillService
