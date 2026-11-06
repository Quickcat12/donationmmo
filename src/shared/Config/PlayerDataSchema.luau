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

export type StreakData = {
	count: number, -- consecutive UTC days claimed, including today if claimed
	best: number,
	lastClaimDay: number, -- UTC day number (os.time() // 86400) of the last claim, -1 = never
}

export type JournalData = {
	progress: { [string]: number }, -- one-time island quest id -> progress
	claimed: { [string]: boolean },
}

export type PlaytimeData = {
	day: number, -- UTC day the counter below belongs to
	xpToday: number, -- base (pre-multiplier) playtime XP granted today, for the daily cap
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
	streak: StreakData,
	discoveries: { [string]: boolean }, -- landmark id -> found
	obbiesCompleted: { [string]: boolean }, -- course id -> finished at least once
	journal: JournalData,
	playtime: PlaytimeData,
	purchaseHistory: { string }, -- recent Developer Product PurchaseIds, so a retried receipt is never granted twice
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
	streak = {
		count = 0,
		best = 0,
		lastClaimDay = -1,
	},
	discoveries = {},
	obbiesCompleted = {},
	journal = {
		progress = {},
		claimed = {},
	},
	playtime = {
		day = 0,
		xpToday = 0,
	},
	purchaseHistory = {},
} :: PlayerProfile

PlayerDataSchema.ProfileStoreName = "PlayerData_v1"

return PlayerDataSchema
