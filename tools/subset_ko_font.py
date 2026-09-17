#!/usr/bin/env python3
"""Subset OFL Noto Sans CJK KR Bold for the Korean game catalogue."""
from pathlib import Path
import re
import sys
from fontTools import subset

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "assets/fonts/NotoSansCJKkr-Bold-full.otf"
OUTPUT = ROOT / "assets/fonts/NotoSansCJKkr-ko.otf"
CATALOGUE = ROOT / "resources/translations/ko.po"

text = CATALOGUE.read_text(encoding="utf-8")
characters = set(chr(code) for code in range(0x20, 0x7F))
characters.update("，。！？、】【、】【：；…·％＋－／（）『』~★")
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
