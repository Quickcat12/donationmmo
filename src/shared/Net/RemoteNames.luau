--!strict
-- Central registry of remote names. Add new remotes here so both server and client
-- reference the same string constants instead of hand-typed strings.

export type RemoteName =
	"XpChanged"
	| "RankUp"
	| "OpenDonationMenu"
	| "RequestDonate"
	| "DonationReceived"
	| "RequestWorldTravel"
	| "WorldTravelDenied"
	| "QuestsUpdated"
	| "RequestClaimQuest"
	| "LeaderboardUpdated"

local RemoteNames = {
	Events = {
		XpChanged = "XpChanged", -- server -> client, fires whenever a player's XP changes
		RankUp = "RankUp", -- server -> client, fires on rank promotion (for celebration UI)
		OpenDonationMenu = "OpenDonationMenu", -- server -> client, tells the donor's client to open the amount picker for a given receiver
		RequestDonate = "RequestDonate", -- client -> server, player confirms a donation amount at a stand
		DonationReceived = "DonationReceived", -- server -> client, notifies receiver of an incoming donation
		RequestWorldTravel = "RequestWorldTravel", -- client -> server, player requests to teleport to a world
		WorldTravelDenied = "WorldTravelDenied", -- server -> client, travel request rejected (rank too low)
		QuestsUpdated = "QuestsUpdated", -- server -> client, quest list/progress changed
		RequestClaimQuest = "RequestClaimQuest", -- client -> server, player claims a completed quest
		LeaderboardUpdated = "LeaderboardUpdated", -- server -> client, top-N leaderboard snapshot
	} :: { [string]: string },
}

return RemoteNames
