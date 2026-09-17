#!/usr/bin/env python3
"""Bakes the room captures into labelled scrapbook cards for the Kinu Tumble set.

    python3 scripts/room_cards.py            # English, Nunito
    python3 scripts/room_cards.py ja ko zh_TW

Photos come from public/screenshots/room-<id>.png (tools/capture_play.gd,
mode=scene; the HUD is cropped away, so one set of photos serves every
language). Names come from the game's own translation catalogues so the cards
match what players see in the shop. English writes to public/kinutumble/cards/,
other languages to public/kinutumble/cards/<lang>/.
"""
from pathlib import Path
import re
import sys
from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw, ImageFont

STUDIO = Path(__file__).resolve().parents[1]
GAME = STUDIO.parent
ROOMS = [
    ("shop", "Tofu Shop"), ("night", "Night Market"), ("winter", "Winter"),
    ("sakura_street", "Sakura Street"), ("bamboo_grove", "Bamboo Grove"),
    ("autumn_temple", "Autumn Temple"), ("onsen", "Onsen"),
    ("festival", "Summer Festival"), ("moon_viewing", "Moon Viewing"),
    ("neon_alley", "Neon Rooftop"),
]
# The game's own face for each language; Nunito carries no CJK.
FONTS = {
    "en": STUDIO / "public/fonts/Nunito.ttf",
    "ja": GAME / "assets/fonts/MPLUSRounded1c-Bold.ttf",
    "ko": GAME / "assets/fonts/NotoSansCJKkr-ko.otf",
    "zh_TW": GAME / "assets/fonts/jf-openhuninn-zh_TW.ttf",
}
INK = (42, 23, 20, 255)
CREAM = (255, 251, 232, 255)
S = 2  # supersample, then scale down for clean edges


def catalogue(lang: str) -> dict:
    if lang == "en":
        return {}
    text = (GAME / f"resources/translations/{lang}.po").read_text(encoding="utf-8")
    return dict(re.findall(r'msgid "((?:[^"\\]|\\.)*)"\nmsgstr "((?:[^"\\]|\\.)*)"', text))


def label_font(lang: str, name: str, max_width: float) -> ImageFont.FreeTypeFont:
    path = FONTS[lang]
    cmap = TTFont(str(path)).getBestCmap()
    missing = [ch for ch in name if ch != " " and ord(ch) not in cmap]
    if missing:
        sys.exit(f"{lang}: {path.name} has no glyph for {''.join(missing)} in {name!r}")
    size = 46 * S
    while True:
        font = ImageFont.truetype(str(path), size)
        if lang == "en":
            font.set_variation_by_axes([900])
        if ImageDraw.Draw(Image.new("L", (1, 1))).textlength(name, font=font) <= max_width or size <= 28 * S:
            return font
        size -= 2 * S


def card(room: str, name: str, lang: str, out: Path) -> None:
    src = Image.open(STUDIO / f"public/screenshots/room-{room}.png").convert("RGBA")
    w, h = src.size
    # The scene between the HUD and the swipe strip.
    crop = src.crop((0, int(h * .22), w, int(h * .64)))
    pw = 520 * S
    ph = int(pw * crop.height / crop.width)
    photo = crop.resize((pw, ph), Image.LANCZOS)
    pad, label, line = 22 * S, 78 * S, 9 * S
    cw, ch = pw + pad * 2, ph + pad + label
    image = Image.new("RGBA", (cw + line * 2, ch + line * 2), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((0, 0, image.width - 1, image.height - 1), radius=38 * S, fill=INK)
    draw.rounded_rectangle((line, line, line + cw - 1, line + ch - 1), radius=30 * S, fill=CREAM)
    mask = Image.new("L", (pw, ph), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, pw - 1, ph - 1), radius=20 * S, fill=255)
    image.paste(photo, (line + pad, line + pad), mask)
    draw.rounded_rectangle((line + pad, line + pad, line + pad + pw - 1, line + pad + ph - 1), radius=20 * S, outline=INK, width=5 * S)
    font = label_font(lang, name, pw - 40 * S)
    left, top, right, bottom = draw.textbbox((0, 0), name, font=font)
    draw.text((line + cw / 2 - (left + right) / 2, line + pad + ph + label / 2 - (top + bottom) / 2), name, font=font, fill=INK)
    image.resize((image.width // S, image.height // S), Image.LANCZOS).save(out)


def main() -> None:
    for lang in sys.argv[1:] or ["en"]:
        names = catalogue(lang)
        folder = STUDIO / "public/kinutumble/cards" / ("" if lang == "en" else lang)
        folder.mkdir(parents=True, exist_ok=True)
        for room, english in ROOMS:
            name = english if lang == "en" else names.get(english)
            if not name:
                sys.exit(f"{lang}: no translation for {english!r}")
            card(room, name, lang, folder / f"room-{room}.png")
        print(f"{lang}: {len(ROOMS)} cards in {folder.relative_to(STUDIO)}")


if __name__ == "__main__":
    main()
