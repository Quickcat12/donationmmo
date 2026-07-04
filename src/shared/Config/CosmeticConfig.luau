--!strict
-- Tuning for the identity/prestige layer: overhead nameplates, chat tags, and server-wide
-- join announcements. See CosmeticService.luau (server) and ChatTagController /
-- JoinAnnouncementController / TitlesController (client).

local CosmeticConfig = {}

-- Minimum RankConfig `order` before a player's arrival gets a server-wide announcement
-- toast. Gray (order 1) still joins normally - Roblox's own player list already covers
-- that - the splash is reserved for ranks meant to turn heads.
CosmeticConfig.AnnounceMinRankOrder = 2

-- How far away (studs) a player's overhead rank nameplate is still rendered.
CosmeticConfig.OverheadMaxDistance = 120

return CosmeticConfig
