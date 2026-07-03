--!strict
-- Cached copy of the local player's latest server-pushed state, so any controller can
-- read "what's my level right now" without re-fetching. Not authoritative - the server
-- always re-validates anything security-sensitive (donations, world travel).

local Signal = require(game:GetService("ReplicatedStorage").Shared.Util.Signal)

local State = {
	xp = 0,
	level = 1,
	rank = "Gray",
	progress = 0,
}

State.Changed = Signal.new()

function State.update(payload: { xp: number, level: number, rank: string, progress: number })
	State.xp = payload.xp
	State.level = payload.level
	State.rank = payload.rank
	State.progress = payload.progress
	State.Changed:Fire()
end

return State
