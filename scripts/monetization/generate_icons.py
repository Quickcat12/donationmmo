#!/usr/bin/env python3
"""Generates 512x512 store icons for the XP Shop Developer Products and the VIP
Game Pass defined in products.py. Pure offline image generation (Pillow) - no
Roblox API calls, no network access needed.

Run this once whenever a tier in products.py changes its color/label. Output
goes to scripts/monetization/icons/<key>.png, which create_products.py then
uploads as each item's icon.

Usage:
    pip install Pillow
    python3 generate_icons.py
"""

import math
import os

from PIL import Image, ImageDraw, ImageFont

from products import VIP_GAMEPASS, XP_SHOP_PRODUCTS

SIZE = 512
FONT_PATHS = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
]
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "icons")


def load_font(size: int) -> ImageFont.FreeTypeFont:
    for path in FONT_PATHS:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def lighten(color: tuple, amount: float) -> tuple:
    return tuple(min(255, int(c + (255 - c) * amount)) for c in color)


def darken(color: tuple, amount: float) -> tuple:
    return tuple(max(0, int(c * (1 - amount))) for c in color)


def radial_background(color: tuple) -> Image.Image:
    """A soft radial gradient badge background - darker at the corners, a
    lighter glow near the top-left, so every icon reads as a glossy medallion
    rather than a flat color swatch."""
    img = Image.new("RGB", (SIZE, SIZE), darken(color, 0.35))
    draw = ImageDraw.Draw(img)
    center = (SIZE * 0.38, SIZE * 0.32)
    max_dist = math.hypot(SIZE, SIZE)
    for y in range(SIZE):
        for x in range(0, SIZE, 2):
            dist = math.hypot(x - center[0], y - center[1]) / max_dist
            t = min(1.0, dist * 1.6)
            pixel = tuple(
                int(lighten(color, 0.35)[i] * (1 - t) + darken(color, 0.35)[i] * t)
                for i in range(3)
            )
            draw.point((x, y), fill=pixel)
            draw.point((x + 1, y), fill=pixel)
    return img


def rounded_mask(radius: int) -> Image.Image:
    mask = Image.new("L", (SIZE, SIZE), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([0, 0, SIZE - 1, SIZE - 1], radius=radius, fill=255)
    return mask


def draw_centered_text(draw: ImageDraw.ImageDraw, text: str, y: float, font, fill, stroke=None):
    bbox = draw.textbbox((0, 0), text, font=font)
    width = bbox[2] - bbox[0]
    x = (SIZE - width) / 2
    if stroke:
        draw.text((x, y), text, font=font, fill=fill, stroke_width=6, stroke_fill=stroke)
    else:
        draw.text((x, y), text, font=font, fill=fill)


def build_xp_icon(key: str, xp_amount: int, color: tuple):
    img = radial_background(color)
    draw = ImageDraw.Draw(img)

    # Ring border to read as a "coin"/medallion at small sizes.
    border = 18
    draw.ellipse(
        [border, border, SIZE - border, SIZE - border],
        outline=lighten(color, 0.7),
        width=10,
    )

    amount_text = f"{xp_amount:,}" if xp_amount < 1000 else f"{xp_amount // 1000}K"
    draw_centered_text(draw, amount_text, SIZE * 0.30, load_font(120), (255, 255, 255), stroke=darken(color, 0.6))
    draw_centered_text(draw, "XP", SIZE * 0.58, load_font(90), lighten(color, 0.85), stroke=darken(color, 0.6))

    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    mask = rounded_mask(64)
    img.putalpha(mask)
    return img


def build_vip_icon(color: tuple):
    img = radial_background(color)
    draw = ImageDraw.Draw(img)

    border = 18
    draw.ellipse(
        [border, border, SIZE - border, SIZE - border],
        outline=lighten(color, 0.8),
        width=10,
    )

    # Simple crown silhouette.
    cx, cy = SIZE / 2, SIZE * 0.36
    crown_width, crown_height = SIZE * 0.42, SIZE * 0.22
    left = cx - crown_width / 2
    right = cx + crown_width / 2
    base_y = cy + crown_height / 2
    top_y = cy - crown_height / 2
    points = [
        (left, base_y),
        (left, cy),
        (left + crown_width * 0.2, cy + crown_height * 0.15),
        (cx - crown_width * 0.2, top_y),
        (cx, cy + crown_height * 0.1),
        (cx + crown_width * 0.2, top_y),
        (right - crown_width * 0.2, cy + crown_height * 0.15),
        (right, cy),
        (right, base_y),
    ]
    draw.polygon(points, fill=lighten(color, 0.85), outline=darken(color, 0.6))
    for gx in (left + crown_width * 0.02, cx, right - crown_width * 0.02):
        draw.ellipse([gx - 10, top_y - 14, gx + 10, top_y + 6], fill=(255, 255, 255))

    draw_centered_text(draw, "VIP", SIZE * 0.62, load_font(110), (255, 255, 255), stroke=darken(color, 0.6))

    mask = rounded_mask(64)
    img.putalpha(mask)
    return img


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    for item in XP_SHOP_PRODUCTS:
        icon = build_xp_icon(item["key"], item["xp_amount"], item["color"])
        path = os.path.join(OUTPUT_DIR, f"{item['key']}.png")
        icon.save(path)
        print(f"wrote {path}")

    vip_icon = build_vip_icon(VIP_GAMEPASS["color"])
    vip_path = os.path.join(OUTPUT_DIR, f"{VIP_GAMEPASS['key']}.png")
    vip_icon.save(vip_path)
    print(f"wrote {vip_path}")


if __name__ == "__main__":
    main()
