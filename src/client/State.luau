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
	multiplier = 1, -- combined multiplier a donation would get right now
	xpToNext = nil :: number?, -- XP left to the next rank; nil at the top rank
}

State.Changed = Signal.new()

function State.update(payload: { [string]: any })
	State.xp = payload.xp
	State.level = payload.level
	State.rank = payload.rank
	State.progress = payload.progress
	State.xpToNext = payload.xpToNext
	-- `multiplier` in a payload is that one grant's; the HUD shows what a donation
	-- would earn right now, which changes with rank, VIP and server blessings.
	if type(payload.donationMultiplier) == "number" then
		State.multiplier = payload.donationMultiplier
	end
	State.Changed:Fire()
end

return State
