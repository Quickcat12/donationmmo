--!strict
-- Game-owned XP boosts, sold as real Developer Products (revenue goes to the
-- experience/group, unlike donations which are player-to-player via Gamepasses -
-- see DonationService.luau). This is the only place Developer Products are used.
--
-- Source of truth for name/price/xpAmount is scripts/monetization/products.py -
-- that's what actually creates these as real Developer Products via the Open Cloud
-- API (see scripts/monetization/create_products.py), and writes the resulting
-- productId back into this file. If you add/change a tier, edit products.py first,
-- rerun that script, and let it patch this file - don't hand-edit productId here.

export type XPShopItem = {
	productId: number, -- filled in by scripts/monetization/create_products.py
	name: string, -- must exactly match the Developer Product's name on Roblox
	robuxPrice: number,
	xpAmount: number,
}

local XPShopConfig = {}

XPShopConfig.Items = {
	{ productId = 0, name = "Starter XP Pack", robuxPrice = 99, xpAmount = 2500 },
	{ productId = 0, name = "Booster XP Pack", robuxPrice = 249, xpAmount = 6750 },
	{ productId = 0, name = "Surge XP Pack", robuxPrice = 499, xpAmount = 14750 },
	{ productId = 0, name = "Vault XP Pack", robuxPrice = 999, xpAmount = 32000 },
	-- Deliberately capped: the biggest available purchase, at a worse XP-per-Robux
	-- rate than every tier above, so it can't buy a rank outright (Diamond needs
	-- 100,000 XP - see RankConfig.luau). Climbing is meant to be earned, not bought.
	{ productId = 0, name = "Empire XP Pack", robuxPrice = 2500, xpAmount = 50000 },
} :: { XPShopItem }

function XPShopConfig.getItemByProductId(productId: number): XPShopItem?
	for _, item in XPShopConfig.Items do
		if item.productId == productId then
			return item
		end
	end
	return nil
end

return XPShopConfig
