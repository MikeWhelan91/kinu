#!/usr/bin/env python3
"""Subset jf open 粉圓 for the Traditional Chinese game catalogue.

Install the OFL font from the upstream release first, then run this script
from the project root.  It intentionally includes ASCII for dynamic scores.
"""
from pathlib import Path
import re
import sys
from fontTools import subset

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "assets/fonts/jf-openhuninn-full.ttf"
OUTPUT = ROOT / "assets/fonts/jf-openhuninn-zh_TW.ttf"
CATALOGUE = ROOT / "resources/translations/zh_TW.po"

text = CATALOGUE.read_text(encoding="utf-8")
characters = set(chr(code) for code in range(0x20, 0x7F))
characters.update("，。！？、】【、】【：；、…・％＋－／（）「」『』～★")
for value in re.findall(r'^msgstr "(.*)"$', text, re.MULTILINE):
	characters.update(value.replace("\\n", "\n").replace('\\"', '"'))

options = subset.Options()
options.name_IDs = ["*"]
options.name_legacy = True
font = subset.load_font(str(SOURCE), options)
subsetter = subset.Subsetter(options=options)
subsetter.populate(text="".join(characters))
subsetter.subset(font)
subset.save_font(font, str(OUTPUT), options)
