#!/usr/bin/env python3
"""Creates the XP Shop Developer Products and the VIP Game Pass for real on Roblox via
Open Cloud, using the `rblxopencloud` library, then patches the resulting IDs straight
into src/shared/Config/XPShopConfig.luau and src/shared/Config/VIPConfig.luau.

This makes REAL, LIVE changes to your experience's monetization - it is not a dry run.
It is idempotent though: re-running it will skip any item whose name already exists on
the experience (matched by exact name), so it's safe to re-run after adding a new tier
to products.py.

Setup (run this from a machine with normal internet access - Roblox's API is not
reachable from the sandboxed session that wrote this script):
    pip install rblxopencloud

    export ROBLOX_API_KEY="your Open Cloud API key from create.roblox.com/credentials"
    export ROBLOX_UNIVERSE_ID="your experience's Universe ID"

    (Studio: Game Settings > Basic Info shows "Experience ID" - that's the Universe ID.
    It is NOT necessarily the same number as the Place ID in your dashboard URL - if
    you're not sure, this script prints the experience name it resolves before doing
    anything, so you can confirm it's the right one.)

    The API key needs the "Developer Products" and "Game Passes" Open Cloud
    permissions (read + write) for this experience - grant them when creating/editing
    the key at create.roblox.com/credentials.

Usage:
    python3 create_products.py
"""

import os
import re
import sys

try:
    from rblxopencloud import Experience
except ImportError:
    print("Missing dependency. Run: pip install rblxopencloud", file=sys.stderr)
    sys.exit(1)

from products import VIP_GAMEPASS, XP_SHOP_PRODUCTS

SCRIPT_DIR = os.path.dirname(__file__)
ICONS_DIR = os.path.join(SCRIPT_DIR, "icons")
REPO_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
XP_SHOP_CONFIG_PATH = os.path.join(REPO_ROOT, "src", "shared", "Config", "XPShopConfig.luau")
VIP_CONFIG_PATH = os.path.join(REPO_ROOT, "src", "shared", "Config", "VIPConfig.luau")


def patch_xp_shop_config(name_to_id: dict):
    with open(XP_SHOP_CONFIG_PATH, "r") as f:
        content = f.read()

    for name, product_id in name_to_id.items():
        pattern = re.compile(
            r'(\{ productId = )\d+(, name = "' + re.escape(name) + r'".*?\})'
        )
        new_content, count = pattern.subn(rf"\g<1>{product_id}\g<2>", content)
        if count == 0:
            print(f"  WARNING: could not find a line for \"{name}\" in {XP_SHOP_CONFIG_PATH} - patch it by hand.")
            continue
        content = new_content

    with open(XP_SHOP_CONFIG_PATH, "w") as f:
        f.write(content)
    print(f"Patched {XP_SHOP_CONFIG_PATH}")


def patch_vip_config(gamepass_id: int):
    with open(VIP_CONFIG_PATH, "r") as f:
        content = f.read()

    new_content, count = re.subn(
        r"VIPConfig\.GamepassId = \d+", f"VIPConfig.GamepassId = {gamepass_id}", content
    )
    if count == 0:
        print(f"  WARNING: could not find VIPConfig.GamepassId in {VIP_CONFIG_PATH} - patch it by hand.")
        return
    with open(VIP_CONFIG_PATH, "w") as f:
        f.write(new_content)
    print(f"Patched {VIP_CONFIG_PATH}")


def main():
    api_key = os.environ.get("ROBLOX_API_KEY")
    universe_id = os.environ.get("ROBLOX_UNIVERSE_ID")

    if not api_key or not universe_id:
        print("Set ROBLOX_API_KEY and ROBLOX_UNIVERSE_ID environment variables first.", file=sys.stderr)
        sys.exit(1)

    experience = Experience(int(universe_id), api_key)

    print("Fetching experience info to confirm this is the right universe...")
    experience.fetch_info()
    print(f"  Name: {experience.name}")
    print(f"  Description: {(experience.description or '')[:120]}")
    print()

    print("This will create, on the experience above:")
    for item in XP_SHOP_PRODUCTS:
        print(f"  - Developer Product \"{item['name']}\": {item['price_in_robux']} R$ -> {item['xp_amount']} XP")
    print(f"  - Game Pass \"{VIP_GAMEPASS['name']}\": {VIP_GAMEPASS['price_in_robux']} R$ -> +{int((VIP_GAMEPASS['xp_multiplier'] - 1) * 100)}% XP forever")
    print("Any item whose name already exists on this experience will be skipped, not duplicated.")
    print()

    confirmation = input('Type "yes" to proceed: ').strip().lower()
    if confirmation != "yes":
        print("Aborted, nothing was created.")
        return

    existing_products = {p.name: p.id for p in experience.list_developer_products()}
    existing_passes = {p.name: p.id for p in experience.list_game_passes()}

    xp_shop_ids = {}
    for item in XP_SHOP_PRODUCTS:
        if item["name"] in existing_products:
            product_id = existing_products[item["name"]]
            print(f"Already exists: \"{item['name']}\" (id {product_id}) - skipping creation.")
            xp_shop_ids[item["name"]] = product_id
            continue

        icon_path = os.path.join(ICONS_DIR, f"{item['key']}.png")
        with open(icon_path, "rb") as icon_file:
            product = experience.create_developer_product(
                name=item["name"],
                description=item["description"],
                price_in_robux=item["price_in_robux"],
                icon_file=icon_file,
            )
        print(f"Created \"{item['name']}\" -> id {product.id}")
        xp_shop_ids[item["name"]] = product.id

    if VIP_GAMEPASS["name"] in existing_passes:
        vip_id = existing_passes[VIP_GAMEPASS["name"]]
        print(f"Already exists: \"{VIP_GAMEPASS['name']}\" (id {vip_id}) - skipping creation.")
    else:
        icon_path = os.path.join(ICONS_DIR, f"{VIP_GAMEPASS['key']}.png")
        with open(icon_path, "rb") as icon_file:
            gamepass = experience.create_game_pass(
                name=VIP_GAMEPASS["name"],
                description=VIP_GAMEPASS["description"],
                price_in_robux=VIP_GAMEPASS["price_in_robux"],
                icon_file=icon_file,
            )
        vip_id = gamepass.id
        print(f"Created \"{VIP_GAMEPASS['name']}\" -> id {vip_id}")

    print()
    patch_xp_shop_config(xp_shop_ids)
    patch_vip_config(vip_id)

    print()
    print("Done. Review the diff in src/shared/Config/XPShopConfig.luau and VIPConfig.luau, then commit it.")
    print("New Developer Products/Game Passes can take a few minutes to become purchasable in-experience.")


if __name__ == "__main__":
    main()
