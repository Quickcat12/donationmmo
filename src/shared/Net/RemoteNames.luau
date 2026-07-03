--!strict
-- Central registry of remote names. Add new remotes here so both server and client
-- reference the same string constants instead of hand-typed strings.

export type RemoteName =
	"XpChanged"
	| "RankUp"
	| "OpenDonationMenu"
	| "ReportGamepassDonation"
	| "DonationReceived"
	| "RequestSetDonationGamepass"
	| "SetDonationGamepassResult"
	| "RequestBuyXp"
	| "RequestWorldTravel"
	| "WorldTravelDenied"
	| "QuestsUpdated"
	| "RequestClaimQuest"
	| "LeaderboardUpdated"

local RemoteNames = {
	Events = {
		XpChanged = "XpChanged", -- server -> client, fires whenever a player's XP changes
		RankUp = "RankUp", -- server -> client, fires on rank promotion (for celebration UI)
		OpenDonationMenu = "OpenDonationMenu", -- server -> client, tells the donor's client to open the gamepass picker for a given stand owner
		ReportGamepassDonation = "ReportGamepassDonation", -- client -> server, "I just bought this gamepass from this receiver" (server re-verifies via UserOwnsGamePassAsync before granting anything)
		DonationReceived = "DonationReceived", -- server -> client, notifies receiver of an incoming donation
		RequestSetDonationGamepass = "RequestSetDonationGamepass", -- client -> server, player links one of their own Gamepasses to their stand
		SetDonationGamepassResult = "SetDonationGamepassResult", -- server -> client, success/failure feedback for the above
		RequestBuyXp = "RequestBuyXp", -- client -> server, player wants to prompt purchase of a game-owned XP shop Developer Product
		RequestWorldTravel = "RequestWorldTravel", -- client -> server, player requests to teleport to a world
		WorldTravelDenied = "WorldTravelDenied", -- server -> client, travel request rejected (rank too low)
		QuestsUpdated = "QuestsUpdated", -- server -> client, quest list/progress changed
		RequestClaimQuest = "RequestClaimQuest", -- client -> server, player claims a completed quest
		LeaderboardUpdated = "LeaderboardUpdated", -- server -> client, top-N leaderboard snapshot
	} :: { [string]: string },
}

return RemoteNames
