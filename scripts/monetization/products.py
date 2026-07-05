"""Single source of truth for the game-owned monetization items: the XP Shop
Developer Products and the VIP Game Pass. generate_icons.py and
create_products.py both import this so the name/price/description used to
create each item on Roblox always matches what gets written into the Luau
configs.

Pricing curve for the XP Shop: every tier improves on the last one's
XP-per-Robux rate (standard "bulk discount" curve, strictly increasing).

An earlier version tried to make the top tier a deliberately *worse* rate as
an anti-pay-to-rank measure, which was broken: since Developer Products can
be bought repeatedly, a worse top tier is just a worse deal players route
around (e.g. 2x the second-to-top tier beats 1x the "capped" top tier for
less money). A single tier's price can never actually cap total spendable
XP when it's repurchasable - that would need a purchase-frequency limit
enforced in XPShopService.luau, not a pricing trick. This curve does still
keep the single biggest available purchase (one Empire pack) short of
Diamond's 100,000 XP threshold, but someone buying two Empire packs
obviously isn't stopped by that - if a hard cap on buying rank progression
is wanted, it needs to be a real rule in code, not a pricing curve.
"""

XP_SHOP_PRODUCTS = [
    {
        "key": "xp_pack_starter",
        "name": "Starter XP Pack",
        "description": "Instantly grants 2,500 XP.",
        "price_in_robux": 99,
        "xp_amount": 2500,
        "color": (90, 200, 120),  # green - matches Green rank
    },
    {
        "key": "xp_pack_booster",
        "name": "Booster XP Pack",
        "description": "Instantly grants 6,750 XP.",
        "price_in_robux": 249,
        "xp_amount": 6750,
        "color": (60, 140, 230),  # blue - matches Blue rank
    },
    {
        "key": "xp_pack_surge",
        "name": "Surge XP Pack",
        "description": "Instantly grants 14,750 XP.",
        "price_in_robux": 499,
        "xp_amount": 14750,
        "color": (160, 90, 220),  # purple - matches Purple rank
    },
    {
        "key": "xp_pack_vault",
        "name": "Vault XP Pack",
        "description": "Instantly grants 32,000 XP.",
        "price_in_robux": 999,
        "xp_amount": 32000,
        "color": (230, 190, 60),  # gold - matches Gold rank
    },
    {
        "key": "xp_pack_empire",
        "name": "Empire XP Pack",
        "description": "Instantly grants 85,000 XP. The best XP-per-Robux value in the shop.",
        "price_in_robux": 2500,
        "xp_amount": 85000,
        "color": (90, 210, 230),  # diamond - matches Diamond rank
    },
]

# A permanent, game-owned Game Pass (not a donation stand Gamepass - this one
# belongs to the experience itself). Grants a flat +15% XP multiplier from
# every source, stacking multiplicatively with the rank/world multipliers
# already in XPService.grantXp - a one-time purchase that pays off the whole
# time a player plays, rather than a one-shot XP dump like the Developer
# Products above.
VIP_GAMEPASS = {
    "key": "vip_ascendant",
    "name": "VIP Ascendant",
    "description": "Permanently boosts all XP you earn - from donations, obbies, and quests - by 15%. Stacks with your rank and world multipliers.",
    "price_in_robux": 349,
    "xp_multiplier": 1.15,
    "color": (255, 205, 70),
}

# A Developer Product (not player-owned - the experience's) that temporarily boosts XP
# for EVERYONE currently in the server, with a public announcement crediting the buyer.
# A social-status purchase rather than a personal one - see ServerBoostService.luau.
SERVER_BOOST_PRODUCT = {
    "key": "server_boost",
    "name": "Server XP Blessing",
    "description": "Grants everyone in the server 2x XP for 15 minutes, with a server-wide announcement crediting you.",
    "price_in_robux": 499,
    "xp_multiplier": 2.0,
    "duration_seconds": 15 * 60,
    "color": (230, 90, 210),
}
