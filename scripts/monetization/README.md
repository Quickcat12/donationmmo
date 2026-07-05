# Monetization setup scripts

Creates the real, live Developer Products (XP Shop + the server-wide XP Blessing) and
the one Game Pass (VIP) for this experience via Roblox's Open Cloud API, generates
their store icons, and patches the resulting IDs into `src/shared/Config/XPShopConfig.luau`,
`src/shared/Config/VIPConfig.luau`, and `src/shared/Config/ServerBoostConfig.luau`.

**This is not run automatically and can't be run from a sandboxed session** - Roblox's
API isn't reachable from there. Run it yourself, once, from a machine with normal
internet access.

Donation stands are unaffected by this - those use each player's own Gamepasses
(see `src/server/Services/DonationService.luau`), which players create and link
themselves. Nothing here touches that.

## 1. Get an Open Cloud API key with the right scopes

1. Go to `create.roblox.com/credentials` and create (or edit) an API key.
2. Grant it access to this experience, with the **Developer Products** and
   **Game Passes** permissions (read + write). These are a newer permission
   category (added December 2025) - if your existing key predates that, it
   probably doesn't have them yet and you'll get a 403 until you add them.

## 2. Find your Universe ID

This is **not necessarily the same number** as the Place ID in your Studio/dashboard
URL. In Studio: **Game Settings > Basic Info** shows "Experience ID" - that's the
Universe ID you want.

If you're not sure, don't worry - the script fetches and prints the experience's name
before creating anything, so you can confirm it resolved the right one before typing
"yes".

## 3. Run it

```bash
pip install rblxopencloud

export ROBLOX_API_KEY="..."
export ROBLOX_UNIVERSE_ID="..."

python3 create_products.py
```

It will print what it's about to create and ask you to type `yes` before making any
live changes. Re-running it later is safe - anything whose name already exists on the
experience is skipped, not duplicated.

## 4. Review and commit

The script edits three files in place:
- `src/shared/Config/XPShopConfig.luau` (5 Developer Product IDs)
- `src/shared/Config/VIPConfig.luau` (1 Game Pass ID)
- `src/shared/Config/ServerBoostConfig.luau` (1 Developer Product ID)

Review the diff, then commit and push it like normal. New items can take a few
minutes on Roblox's side before they're actually purchasable in-experience.

## Adding or changing a tier later

Edit `products.py` (the shared source of truth for name/price/description/XP or
multiplier), regenerate icons if you changed a tier's color or amount:

```bash
pip install Pillow
python3 generate_icons.py
```

then rerun `create_products.py`. Existing items are matched and skipped by exact
name, so **renaming an existing tier in `products.py` creates a new item instead of
updating the old one** - if you want to just reprice an existing tier, use Studio's
monetization page (or extend this script with `update_developer_product`/
`update_game_pass`, which `rblxopencloud` also supports) rather than renaming it here.
