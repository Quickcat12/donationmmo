--!strict
-- Game-owned XP boosts, sold as real Developer Products (revenue goes to the
-- experience/group, unlike donations which are player-to-player via Gamepasses -
-- see DonationService.luau). This is the only place Developer Products are used.

export type XPShopItem = {
	productId: number, -- fill in with the real Developer Product ID once created
	robuxPrice: number,
	xpAmount: number,
}

local XPShopConfig = {}

XPShopConfig.Items = {
	{ productId = 0, robuxPrice = 99, xpAmount = 2500 },
	{ productId = 0, robuxPrice = 199, xpAmount = 6000 },
	{ productId = 0, robuxPrice = 499, xpAmount = 17500 },
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
