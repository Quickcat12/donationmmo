"""Single source of truth for the game-owned monetization items: the XP Shop
Developer Products and the VIP Game Pass. generate_icons.py and
create_products.py both import this so the name/price/description used to
create each item on Roblox always matches what gets written into the Luau
configs.

Pricing curve for the XP Shop: tiers 1-4 each improve on the last tier's
XP-per-Robux rate (standard "bulk discount" curve). The 5th/max tier is a
deliberate exception - it's capped at 2,500 Robux and given a *worse* rate
than every tier below it. That's intentional: this game's whole premise is
that climbing ranks is earned (via donations/social status), not bought, so
the single biggest available purchase should not be able to vault someone
straight to a top rank. 50,000 XP is enough to be worth buying, but nowhere
near "buy your way to Diamond in one purchase" (Diamond needs 100,000 XP -
see RankConfig.luau).
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
        "description": "Instantly grants 50,000 XP. The biggest pack available, capped deliberately so it can't buy a rank outright.",
        "price_in_robux": 2500,
        "xp_amount": 50000,
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
