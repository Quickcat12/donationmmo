--!strict
-- The one game-owned Game Pass (distinct from the player-owned donation Gamepasses in
-- DonationService.luau): a permanent +xpMultiplier boost to all XP a player earns,
-- stacking multiplicatively with their rank/world multipliers in XPService.grantXp.
--
-- Source of truth for name/price/multiplier is scripts/monetization/products.py -
-- that's what actually creates this as a real Game Pass via the Open Cloud API (see
-- scripts/monetization/create_products.py), and writes the resulting gamepassId back
-- into this file. If you change the price or multiplier, edit products.py first,
-- rerun that script, and let it patch this file - don't hand-edit gamepassId here.

local VIPConfig = {}

VIPConfig.GamepassId = 0 -- filled in by scripts/monetization/create_products.py
VIPConfig.Name = "VIP Ascendant"
VIPConfig.XpMultiplier = 1.15

return VIPConfig
