#!/usr/bin/env python3
"""Fonts and fitted sizes for the Kinu Tumble store set, in every language.

    python3 scripts/kinu_fonts.py

Run it after changing src/lib/kinutumble-copy.json. It does two things:

1. Subsets each CJK face down to the characters the copy actually uses, into
   public/fonts/kinu-<lang>.*. The export inlines every face into every render,
   so a 17 MB Korean font is not an option; a subset is a few dozen kilobytes.
   Faces are the game's own, so the store matches the app: M PLUS Rounded 1c
   (ja), Noto Sans CJK KR (ko), jf-openhuninn (zh_TW). The game only ships
   subsets of the last two, which lack most characters; full sources dropped in
   fonts-src/ are used when present.

2. Measures every headline, caption and byline in its real face and writes the
   largest size that fits to src/lib/kinutumble-fit.json, capped at the English
   design sizes. The builder reads that, so no line ever wraps.
"""
from __future__ import annotations
from pathlib import Path
import json
import sys
from fontTools import subset
from fontTools.ttLib import TTFont
from PIL import ImageFont

STUDIO = Path(__file__).resolve().parents[1]
GAME = STUDIO.parent
COPY = STUDIO / "src/lib/kinutumble-copy.json"
FIT = STUDIO / "src/lib/kinutumble-fit.json"
W = 1242

# lang: (preferred full source, fallback shipped with the game, output file)
FACES = {
    "ja": (GAME / "assets/fonts/MPLUSRounded1c-Bold.ttf", None, "kinu-ja.ttf"),
    "ko": (STUDIO / "fonts-src/NotoSansCJKkr-Bold.otf", GAME / "assets/fonts/NotoSansCJKkr-ko.otf", "kinu-ko.otf"),
    "zh_TW": (STUDIO / "fonts-src/jf-openhuninn-2.1.ttf", GAME / "assets/fonts/jf-openhuninn-zh_TW.ttf", "kinu-zh.ttf"),
}

# Mirrors the text layers in src/lib/kinutumble.ts: width (% of canvas),
# design size, tracking (px). CJK is set with no negative tracking.
LAYERS = {
    "headline": (96, 186, {"en": -2, "cjk": 0}),
    "caption": (84, 54, {"en": -0.4, "cjk": 0}),
    "byline": (88, 58, {"en": -0.3, "cjk": 0}),
}
# Browsers lay text out a touch wider than PIL measures it.
SAFETY = .97


def source(lang: str) -> Path:
    full, fallback, _ = FACES[lang]
    if full.exists():
        return full
    if fallback and fallback.exists():
        return fallback
    sys.exit(f"{lang}: no font found at {full}")


def subset_face(lang: str, text: str) -> Path:
    src = source(lang)
    out = STUDIO / "public/fonts" / FACES[lang][2]
    characters = set(chr(code) for code in range(0x20, 0x7F)) | set("，。！？、…·：；（）「」『』—") | set(text)
    characters.discard("\n")
    cmap = TTFont(str(src)).getBestCmap()
    missing = sorted(ch for ch in set(text) - {"\n", " "} if ord(ch) not in cmap)
    options = subset.Options()
    options.name_IDs = ["*"]
    options.layout_features = ["*"]
    font = subset.load_font(str(src), options)
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(text="".join(characters))
    subsetter.subset(font)
    subset.save_font(font, str(out), options)
    note = f"  MISSING {len(missing)}: {''.join(missing)}" if missing else ""
    print(f"{lang}: {src.name} -> {out.name} ({out.stat().st_size // 1024} KB){note}")
    return out


def measure(font_path: Path, text: str, size: int, width_pct: float, tracking: float, weight: int | None) -> int:
    probe = ImageFont.truetype(str(font_path), 100)
    if weight:
        probe.set_variation_by_axes([weight])
    lines = [line for line in text.split("\n") if line.strip()]
    target = width_pct / 100 * W * SAFETY
    best = size
    while best > 20:
        widest = max(probe.getlength(line) / 100 * best + tracking * (len(line) - 1) for line in lines)
        if widest <= target:
            return best
        best -= 1
    return best


def main() -> None:
    copy = json.loads(COPY.read_text(encoding="utf-8"))
    fit = {}
    for lang, screens in copy.items():
        if lang.startswith("_"):
            continue
        cjk = lang != "en"
        text = "".join(head + body for head, body in screens)
        face = subset_face(lang, text) if cjk else STUDIO / "public/fonts/Nunito.ttf"
        track = "cjk" if cjk else "en"
        sizes = {"headline": [], "caption": [], "byline": 0}
        for index, (head, body) in enumerate(screens):
            width, size, tracking = LAYERS["headline"]
            sizes["headline"].append(measure(face, head, size, width, tracking[track], None if cjk else 900))
            kind = "byline" if index == 0 else "caption"
            width, size, tracking = LAYERS[kind]
            fitted = measure(face, body, size, width, tracking[track], None if cjk else (800 if kind == "byline" else 900))
            if kind == "byline":
                sizes["byline"] = fitted
                sizes["caption"].append(0)
            else:
                sizes["caption"].append(fitted)
        fit[lang] = sizes
        print(f"   {lang} headlines {sizes['headline']} captions {sizes['caption']} byline {sizes['byline']}")
    FIT.write_text(json.dumps(fit, indent=1) + "\n", encoding="utf-8")
    print(f"wrote {FIT.relative_to(STUDIO)}")


if __name__ == "__main__":
    main()
