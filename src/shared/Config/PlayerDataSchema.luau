--!strict

export type DonationGamepass = {
	gamepassId: number, -- a Gamepass the player created and owns on creator.roblox.com
	slot: number, -- display order (1-based)
}

export type StandData = {
	tier: number, -- upgrades as rank increases
	totalReceived: number, -- lifetime Robux received via this stand
	donationGamepasses: { DonationGamepass }, -- player-owned Gamepasses linked to this stand for donations
}

export type CosmeticData = {
	ownedTitles: { string },
	equippedTitle: string?,
	ownedEffects: { string },
	equippedEffect: string?,
}

export type QuestData = {
	progress: { [string]: number }, -- questId -> current progress count
	completedToday: { string }, -- questIds already claimed today
	lastResetUnix: number,
}

export type PlayerProfile = {
	xp: number,
	totalDonatedRobux: number, -- lifetime Robux this player has donated to others
	totalReceivedRobux: number, -- lifetime Robux this player has received from others
	donationCount: number,
	receivedCount: number,
	stand: StandData,
	cosmetics: CosmeticData,
	quests: QuestData,
	settings: {
		showChatTag: boolean,
	},
}

local PlayerDataSchema = {}

PlayerDataSchema.Default = {
	xp = 0,
	totalDonatedRobux = 0,
	totalReceivedRobux = 0,
	donationCount = 0,
	receivedCount = 0,
	stand = {
		tier = 1,
		totalReceived = 0,
		donationGamepasses = {},
	},
	cosmetics = {
		ownedTitles = {},
		equippedTitle = nil,
		ownedEffects = {},
		equippedEffect = nil,
	},
	quests = {
		progress = {},
		completedToday = {},
		lastResetUnix = 0,
	},
	settings = {
		showChatTag = true,
	},
} :: PlayerProfile

PlayerDataSchema.ProfileStoreName = "PlayerData_v1"

return PlayerDataSchema
