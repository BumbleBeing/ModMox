"""Draws the Mod Icon, a cog, in each Rarity's color as 32 x 32 PNGs in ui/sprites/mods/.

    python3 -I tools/sprites/mod_icons.py

Every Mod has the one shape, tools/sprites/mod_icon.txt, with its body in a stand-in ramp,
the palette's greens. This swaps that ramp for a Rarity's tones and writes common.png,
uncommon.png, rare.png, mythic.png and unique.png. Common, Uncommon and Unique are flat. Rare
and Mythic have the sheen of a Magic card's set symbol of that Rarity, a bright band
deepening on either side: gold to bronze for Rare, orange to red for Mythic. Each casts a
faint drop shadow straight down, a pixel deep, which is part of the picture. The Rarity tones
are not in the shared palette (tools/sprites/modmox.gpl), which is why this draws the
pictures itself rather than going through tools/sprites/build.sh. Also writes a review sheet
to tools/sprites/preview/: each at four times its size on a dark ground and on the Satchel's
parchment, then at twice its size and at its own.
"""
import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GRID = os.path.join(ROOT, "tools", "sprites", "mod_icon.txt")
PALETTE = os.path.join(ROOT, "tools", "sprites", "modmox.gpl")
OUT = os.path.join(ROOT, "ui", "sprites", "mods")
SHEET = os.path.join(ROOT, "tools", "sprites", "preview", "mod_icons.png")

SIZE = 32
# One character for each color of the palette, as KEY in build_sprites.lua has them.
KEY = ("0123+56#" + "abcde" + "fghij" + "klmno" + "pqrst" + "uvwxy" + "ABCDE" + "FGHIJ" + "KLMNO"
       + "PQRST" + "UVWXY" + "zZ489" + "!$%&*")
# The stand-in ramp, darkest to lightest.
BODY = "FGHIJ"
# A Mod's Rarities, in order.
RARITIES = ["common", "uncommon", "rare", "mythic", "unique"]
# The five tones of each Rarity that is flat, darkest to lightest. The fourth is the Rarity's
# own color, the one a Potion Icon's plate has (PotionArt.PLATES; a Unique's is light purple).
RAMPS = {
    "common": ["#2e3038", "#4b4f5a", "#6e737e", "#8a8f98", "#b4b9c2"],
    "uncommon": ["#4a5266", "#7c869b", "#a9b2c3", "#d5dbe3", "#ffffff"],
    "unique": ["#3f2a5e", "#6b4c94", "#9a78c4", "#c8a8e6", "#efe0fb"],
}
# The nine tones of each Rarity that has a sheen, darkest to lightest. The seventh is a face
# in the middle of the band, the fourth a face far from it. Rare's seventh is the Rarity's
# own gold; Mythic's are the Mythic set symbol's, bright orange to red.
SHEENS = {
    "rare": ["#4a2c0e", "#744a14", "#9c6a1b", "#bf8824", "#d6a02c", "#e6b437", "#f2c744", "#fbe07e", "#fff6c4"],
    "mythic": ["#4a130f", "#7a2118", "#a02e20", "#bd3a28", "#d05524", "#e06f22", "#f08e22", "#f9b449", "#ffd98a"],
}
# The tone of a face in the middle of a sheen's band, and how far along its nine each tone of
# the body lies from the face where it is.
SHEEN_FACE = 6
SHEEN_STEPS = {"F": -4, "G": -3, "H": -2, "I": 0, "J": 2}
# The band runs from the top left to the bottom right. A face is one tone deeper for each
# SHEEN_WIDTH pixels it lies from the band's middle, SHEEN_DEPTH tones at most.
SHEEN_WIDTH = 3.5
SHEEN_DEPTH = 3
# Where two of the sheen's tones meet they are mixed in a 2 x 2 Bayer dither, as Dither
# Shading's bands are, over this share of a tone's width.
SHEEN_DITHER = 0.5
BAYER = [[0.0, 0.5], [0.75, 0.25]]
# The cog casts a faint drop shadow straight down, as whatever is lit from above does in the
# game: each clear pixel within this many under one of the cog's is SHADOW at SHADOW_ALPHA.
# It is in the picture itself, so it is there wherever the picture is drawn.
SHADOW_DROP = 1
SHADOW = (20, 20, 26)
SHADOW_ALPHA = 0.3
DARK = (34, 28, 28)
PAPER = (233, 220, 188)
PAD = 12
LABEL_HEIGHT = 20


def rgb(text):
    return tuple(int(text[i:i + 2], 16) for i in (1, 3, 5))


def palette_tones():
    """The shared palette's colors by their character in a grid."""
    colors = []
    for line in open(PALETTE):
        parts = line.split()
        if len(parts) >= 3 and parts[0].isdigit():
            colors.append(tuple(int(part) for part in parts[:3]))
    assert len(colors) == len(KEY), "the palette and KEY disagree"
    return dict(zip(KEY, colors))


def read_grid():
    """The picture's 32 rows."""
    rows = [line.rstrip() for line in open(GRID)]
    rows = [row for row in rows if row and row[0] not in ";@="]
    assert len(rows) == SIZE and all(len(row) == SIZE for row in rows), "the grid is not 32 x 32"
    return rows


def sheen_tone(tones, character, x, y):
    """The one of a sheen's [param tones] for the body tone [param character] at pixel
    ([param x], [param y])."""
    from_band = abs(x - y) / math.sqrt(2) / SHEEN_WIDTH
    from_band += (BAYER[y % 2][x % 2] - 0.375) * SHEEN_DITHER
    face = SHEEN_FACE - max(0, min(SHEEN_DEPTH, int(from_band)))
    return rgb(tones[max(0, min(len(tones) - 1, face + SHEEN_STEPS[character]))])


def is_shadowed(rows, x, y):
    """Whether the clear pixel ([param x], [param y]) lies in the cog's drop shadow."""
    return any(y - drop >= 0 and rows[y - drop][x] != "." for drop in range(1, SHADOW_DROP + 1))


def draw(rows, rarity, fixed):
    """The picture with its body in the colors of [param rarity], over its drop shadow."""
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, character in enumerate(row):
            if character == ".":
                if is_shadowed(rows, x, y):
                    image.putpixel((x, y), SHADOW + (round(255 * SHADOW_ALPHA),))
                continue
            if character not in BODY:
                color = fixed[character]
            elif rarity in SHEENS:
                color = sheen_tone(SHEENS[rarity], character, x, y)
            else:
                color = rgb(RAMPS[rarity][BODY.index(character)])
            image.putpixel((x, y), color + (255,))
    return image


def band(pictures, scale, ground, width):
    """A strip [param width] wide of [param pictures] at [param scale] times their size on
    [param ground]."""
    side = SIZE * scale
    strip = Image.new("RGBA", (width, side + PAD * 2), ground + (255,))
    for index, picture in enumerate(pictures):
        strip.alpha_composite(picture.resize((side, side), Image.NEAREST), (PAD + index * (side + PAD), PAD))
    return strip


def main():
    fixed = palette_tones()
    rows = read_grid()
    os.makedirs(OUT, exist_ok=True)
    pictures = []
    for rarity in RARITIES:
        pictures.append(draw(rows, rarity, fixed))
        pictures[-1].save(os.path.join(OUT, rarity + ".png"))
    width = PAD + (SIZE * 4 + PAD) * len(pictures)
    bands = [band(pictures, scale, ground, width) for scale in (4, 2, 1) for ground in (DARK, PAPER)]
    sheet = Image.new("RGBA", (width, LABEL_HEIGHT + sum(strip.height for strip in bands)), DARK + (255,))
    pen = ImageDraw.Draw(sheet)
    for index, rarity in enumerate(RARITIES):
        pen.text((PAD + index * (SIZE * 4 + PAD) + 4, 5), rarity.capitalize(), fill=(240, 230, 210, 255))
    y = LABEL_HEIGHT
    for strip in bands:
        sheet.alpha_composite(strip, (0, y))
        y += strip.height
    sheet.save(SHEET)
    print("OK: %d pictures in %s, sheet at %s" % (len(pictures), os.path.relpath(OUT, ROOT), os.path.relpath(SHEET, ROOT)))


if __name__ == "__main__":
    main()
