--!strict
-- The one server-wide monetization item: a temporary XP multiplier that benefits
-- EVERYONE currently in the server, purchased as a real Developer Product, with a
-- social announcement crediting the buyer. This is a status purchase, not a personal
-- one - see VIPConfig.luau (personal, permanent) and XPShopConfig.luau (personal,
-- one-shot) for the other two monetization tracks.
--
-- Source of truth for name/price/multiplier/duration is scripts/monetization/products.py -
-- that's what actually creates this as a real Developer Product via the Open Cloud API
-- (see scripts/monetization/create_products.py), and writes the resulting productId back
-- into this file. If you change the price/multiplier/duration, edit products.py first,
-- rerun that script, and let it patch this file - don't hand-edit ProductId here.

local ServerBoostConfig = {}

ServerBoostConfig.ProductId = 0 -- filled in by scripts/monetization/create_products.py
ServerBoostConfig.Name = "Server XP Blessing"
ServerBoostConfig.PriceInRobux = 499
ServerBoostConfig.Multiplier = 2.0
ServerBoostConfig.DurationSeconds = 15 * 60

return ServerBoostConfig
