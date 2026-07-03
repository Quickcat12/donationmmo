--!strict

export type DonationTier = {
	productId: number, -- fill in with the real Developer Product ID (Studio > Monetization > Developer Products)
	robuxPrice: number, -- must match the price you set on the Developer Product itself
	donorXp: number, -- XP granted to the donor for choosing this tier
}

local DonationConfig = {}

-- IMPORTANT: productId = 0 is a placeholder. Create one Developer Product per tier in
-- Studio (Monetization > Developer Products), set its price to match robuxPrice, then
-- paste the real product ID here.
DonationConfig.Tiers = {
	{ productId = 0, robuxPrice = 25, donorXp = 250 },
	{ productId = 0, robuxPrice = 50, donorXp = 550 },
	{ productId = 0, robuxPrice = 100, donorXp = 1200 },
	{ productId = 0, robuxPrice = 250, donorXp = 3250 },
	{ productId = 0, robuxPrice = 500, donorXp = 7000 },
	{ productId = 0, robuxPrice = 1000, donorXp = 15000 },
} :: { DonationTier }

-- XP granted to the RECEIVER of a donation, as a fraction of the donor's XP reward.
DonationConfig.ReceiverXpShare = 0.35

function DonationConfig.getTierByProductId(productId: number): DonationTier?
	for _, tier in DonationConfig.Tiers do
		if tier.productId == productId then
			return tier
		end
	end
	return nil
end

return DonationConfig
