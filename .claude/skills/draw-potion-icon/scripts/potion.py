#!/usr/bin/env python3
"""Helpers for drawing a Potion Icon (game ADR 0033) from an empty bottle template.

Run from the repo root, as `python3 -I .claude/skills/draw-potion-icon/scripts/potion.py ...`:

  grid SOURCE
      Print SOURCE as a 32 x 32 grid in the characters of tools/sprites/*.txt. SOURCE is a
      shape (bottle, cone, gourd, jar, square, teardrop, vial), a .png or an .aseprite file.
  fill SHAPE --level ROW --ramp RAMP [--key KEY] [--seed N]
      Print the shape's template with liquid poured in from ROW (0-based) down, shaded the way
      Big Gulp's is. RAMP is a ramp name (red, rust, earth, flesh, gold, olive, green, teal,
      blue, violet, rose, neutral, black) or five palette characters, darkest to lightest.
  check GRID_FILE KEY SHAPE
      Check the drawing named KEY in GRID_FILE against SHAPE's template.
  preview SOURCE [KEY] [--out PNG]
      Draw the review sheet: the icon bare at 8x, then on every Rarity's plate as PotionArt
      draws it, large and small, then beside the Potion Icons already in ui/sprites/potions/.
      SOURCE is a grid file (then KEY names the drawing) or a .png.

The .aseprite templates in tools/sprites/potion_templates/ are the truth: several were touched
up by hand after tools/sprites/potion_templates.txt was written, and bottle has no .png.
Aseprite is found at $ASEPRITE, else ~/Projects/aseprite/build/bin/aseprite.
"""

import argparse
import os
import random
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

SIZE = 32
SHAPES = ["bottle", "cone", "gourd", "jar", "square", "teardrop", "vial"]
TEMPLATES = "tools/sprites/potion_templates"
POTIONS = "ui/sprites/potions"
PALETTE_FILE = "tools/sprites/modmox.gpl"
# One character for each color of modmox.gpl, in its order (as KEY in build_sprites.lua).
KEY = ("0123+56#" "abcde" "fghij" "klmno" "pqrst" "uvwxy" "ABCDE" "FGHIJ" "KLMNO" "PQRST"
       "UVWXY" "zZ489" "!$%&*")
GLASS = "~"
GLASS_TONE = "5"
GLASS_ALPHA = 153
# Darkest to lightest. The liquid takes dark for its shade, mid for its body, light for its
# surface and highlight, lightest for bubbles; darkest is left for the drawer's own use.
RAMPS = {
    "red": "abcde", "rust": "fghij", "earth": "klmno", "flesh": "pqrst", "gold": "uvwxy",
    "olive": "ABCDE", "green": "FGHIJ", "teal": "KLMNO", "blue": "PQRST", "violet": "UVWXY",
    "rose": "zZ489", "neutral": "123+6",
    # A black brew: the palette has nothing darker than its outline, so that is the shade.
    "black": "00UWX",
}
# PotionArt.PLATES, and how PotionArt.plate_style shades and edges a plate.
PLATES = [
    ("Common", (0x8a, 0x8f, 0x98)), ("Uncommon", (0xd5, 0xdb, 0xe3)),
    ("Rare", (0xf2, 0xc7, 0x44)), ("Mythic", (0xa0, 0x52, 0x2d)),
    ("Power Nine", (0x9b, 0xe8, 0x8a)),
]
EDGE = (0x14, 0x17, 0x1c)
EDGE_WIDTH = 2
LIGHTEN = 0.18
DARKEN = 0.2
ROUNDING = 0.08
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
SHEET = (42, 44, 56)
INK = (195, 201, 214)


def fail(message):
    print("ERROR: " + message, file=sys.stderr)
    sys.exit(1)


def palette():
    colors = []
    with open(PALETTE_FILE) as handle:
        for line in handle:
            parts = line.split()
            if len(parts) >= 3 and all(part.isdigit() for part in parts[:3]):
                colors.append(tuple(int(part) for part in parts[:3]))
    if len(colors) != len(KEY):
        fail("%s has %d colors but KEY names %d" % (PALETTE_FILE, len(colors), len(KEY)))
    return colors


COLORS = palette()
TONE = {KEY[index]: color for index, color in enumerate(COLORS)}
NAMES = {}
with open(PALETTE_FILE) as _handle:
    _index = 0
    for _line in _handle:
        _parts = _line.split()
        if len(_parts) >= 3 and all(part.isdigit() for part in _parts[:3]):
            NAMES[KEY[_index]] = " ".join(_parts[3:])
            _index += 1


def aseprite():
    return os.environ.get("ASEPRITE") or os.path.expanduser("~/Projects/aseprite/build/bin/aseprite")


def image_of(path):
    """The RGBA image of a .png, or of an .aseprite file exported through Aseprite."""
    if path.endswith(".aseprite"):
        with tempfile.TemporaryDirectory() as folder:
            out = os.path.join(folder, "export.png")
            result = subprocess.run([aseprite(), "-b", path, "--save-as", out],
                                    capture_output=True, text=True)
            if result.returncode != 0 or not os.path.exists(out):
                fail("Aseprite could not export %s: %s" % (path, result.stdout + result.stderr))
            return Image.open(out).convert("RGBA")
    return Image.open(path).convert("RGBA")


def grid_of_image(image):
    if image.size != (SIZE, SIZE):
        fail("the image is %dx%d, not %dx%d" % (image.size + (SIZE, SIZE)))
    lookup = {color: KEY[index] for index, color in enumerate(COLORS)}
    rows = []
    for y in range(SIZE):
        row = ""
        for x in range(SIZE):
            r, g, b, a = image.getpixel((x, y))
            if a == 0:
                row += "."
            elif a < 255:
                row += GLASS if (r, g, b) == TONE[GLASS_TONE] else "?"
            else:
                row += lookup.get((r, g, b), "?")
        rows.append(row)
    return rows


def template_path(shape):
    if shape not in SHAPES:
        fail("no shape '%s'; the shapes are %s" % (shape, ", ".join(SHAPES)))
    for extension in (".aseprite", ".png"):
        path = os.path.join(TEMPLATES, shape + extension)
        if os.path.exists(path):
            return path
    fail("no template for %s in %s" % (shape, TEMPLATES))


def template(shape):
    return grid_of_image(image_of(template_path(shape)))


def read_blocks(path):
    blocks, current = {}, None
    with open(path) as handle:
        for line in handle:
            line = line.rstrip()
            if line.startswith("="):
                current = line[1:].strip()
                blocks[current] = []
            elif line and not line.startswith(";") and not line.startswith("@"):
                if current is None:
                    fail("%s has a row before any '= name' line" % path)
                blocks[current].append(line)
    return blocks


def drawing(source, key):
    """The grid and key of SOURCE: a .png, an .aseprite file or a grid file."""
    if source.endswith(".png") or source.endswith(".aseprite"):
        return grid_of_image(image_of(source)), key or os.path.splitext(os.path.basename(source))[0]
    blocks = read_blocks(source)
    if key is None:
        if len(blocks) != 1:
            fail("%s holds %d drawings; name one" % (source, len(blocks)))
        key = next(iter(blocks))
    if key not in blocks:
        fail("%s has no '= %s'" % (source, key))
    return blocks[key], key


def image_of_grid(rows):
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, character in enumerate(row):
            if character == GLASS:
                image.putpixel((x, y), TONE[GLASS_TONE] + (GLASS_ALPHA,))
            elif character in TONE:
                image.putpixel((x, y), TONE[character] + (255,))
    return image


def regions(rows):
    """The template's parts: the first row of glass under the neck band, the cells outside the
    bottle's outline, and the cells inside it."""
    glass_top = 1 + max((y for y, row in enumerate(rows) if "6" in row), default=-1)
    outside, stack = set(), []
    for x in range(SIZE):
        stack += [(x, 0), (x, SIZE - 1)]
    for y in range(SIZE):
        stack += [(0, y), (SIZE - 1, y)]
    while stack:
        x, y = stack.pop()
        if not (0 <= x < SIZE and 0 <= y < SIZE) or (x, y) in outside or rows[y][x] == "0":
            continue
        outside.add((x, y))
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    inside = {(x, y) for y in range(SIZE) for x in range(SIZE)
              if (x, y) not in outside and rows[y][x] != "0"}
    return glass_top, outside, inside


def ramp_of(text):
    ramp = RAMPS.get(text, text)
    if len(ramp) != 5 or any(character not in TONE for character in ramp):
        fail("a ramp is a name (%s) or five palette characters" % ", ".join(RAMPS))
    return ramp


def command_grid(arguments):
    source = arguments.source
    rows = template(source) if source in SHAPES else drawing(source, None)[0]
    print("= " + (source if source in SHAPES else os.path.splitext(os.path.basename(source))[0]))
    print("\n".join(rows))


def command_fill(arguments):
    rows = [list(row) for row in template(arguments.shape)]
    darkest, dark, mid, light, lightest = ramp_of(arguments.ramp)
    glass_top, _outside, inside = regions(["".join(row) for row in rows])
    clear = {(x, y) for (x, y) in inside if y >= glass_top and rows[y][x] in ".#"}
    level = arguments.level
    # Where the liquid covers the glass's shine, its highlight streak carries the shine on.
    shine = {(x, y) for (x, y) in clear if y > level and rows[y][x] == "#"}
    liquid_rows = sorted({y for (_x, y) in clear if y >= level})
    if not liquid_rows:
        fail("there is no glass at or below row %d" % level)
    spans = {y: sorted(x for (x, row_y) in clear if row_y == y) for y in liquid_rows}
    widest = max(len(span) for span in spans.values())
    shade_cap = 3 if widest >= 14 else 2 if widest >= 8 else 1
    bottom = set(liquid_rows[-2:]) if len(liquid_rows) >= 5 else set(liquid_rows[-1:])
    body = {}
    for y in liquid_rows:
        for x in spans[y]:
            rows[y][x] = mid
    for y in liquid_rows:
        span = spans[y]
        if y in bottom:
            for x in span:
                rows[y][x] = dark
            continue
        if y == level:
            for x in span:
                rows[y][x] = light
            continue
        shade = max(1, shade_cap - (widest - len(span)) // 2)
        for x in span[-shade:]:
            rows[y][x] = dark
        inset = 2 if len(span) >= 12 else 1
        if shine:
            for x in span:
                if (x, y) in shine and rows[y][x] == mid:
                    rows[y][x] = light
        elif level + 2 <= y <= level + 5 and len(span) > inset + shade + 1:
            rows[y][span[0] + inset] = light
        for x in span:
            if rows[y][x] == mid:
                body[(x, y)] = True
    # Bubbles: single pixels of the lightest step, never touching each other or the light.
    generator = random.Random(arguments.seed)
    candidates = sorted(body)
    generator.shuffle(candidates)
    wanted = 3 if len(candidates) >= 40 else 2 if len(candidates) >= 12 else 1
    bubbles = []
    for (x, y) in candidates:
        if len(bubbles) == wanted:
            break
        neighbors = [(x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)]
        if any(rows[ny][nx] in (light, lightest) for (nx, ny) in neighbors if 0 <= nx < SIZE and 0 <= ny < SIZE):
            continue
        if any(rows[ny][nx] in (dark, GLASS, "0") for (nx, ny) in neighbors if 0 <= nx < SIZE and 0 <= ny < SIZE):
            continue
        # Scattered, not strung along a line: a row of its own and three pixels from the rest.
        if any(by == y or max(abs(bx - x), abs(by - y)) < 3 for (bx, by) in bubbles):
            continue
        rows[y][x] = lightest
        bubbles.append((x, y))
    _ = darkest
    # The size line lets build.sh build the draft file on its own (it assumes 16 without it).
    print("@ size %d" % SIZE)
    print("= " + (arguments.key or arguments.shape))
    print("\n".join("".join(row) for row in rows))


def command_check(arguments):
    rows, key = drawing(arguments.grid_file, arguments.key)
    errors, warnings = [], []
    if len(rows) != SIZE or any(len(row) != SIZE for row in rows):
        fail("%s must be %d rows of %d characters (it has %d rows, widths %s)"
             % (key, SIZE, SIZE, len(rows), sorted({len(row) for row in rows})))
    for y, row in enumerate(rows):
        for x, character in enumerate(row):
            if character not in TONE and character not in (".", GLASS):
                errors.append("(%d, %d) is '%s', which is no palette color" % (x, y, character))
    base = template(arguments.shape)
    glass_top, outside, inside = regions(base)
    changed = [(x, y) for y in range(SIZE) for x in range(SIZE) if rows[y][x] != base[y][x]]
    if not changed:
        errors.append("the drawing is the empty template")
    outline_glass = [(x, y) for (x, y) in changed if base[y][x] == "0" and y >= glass_top]
    outline_neck = [(x, y) for (x, y) in changed if base[y][x] == "0" and y < glass_top]
    cork = [(x, y) for (x, y) in changed if (x, y) in inside and y < glass_top]
    lining = [(x, y) for (x, y) in changed if base[y][x] == GLASS]
    extras = [(x, y) for (x, y) in changed if (x, y) in outside]
    border = [(x, y) for y in range(SIZE) for x in range(SIZE)
              if (x in (0, SIZE - 1) or y in (0, SIZE - 1)) and rows[y][x] != "."]
    liquid = [(x, y) for (x, y) in changed if (x, y) in inside and y >= glass_top and base[y][x] != GLASS]
    if outline_glass:
        warnings.append("%d pixels of the glass's outline changed, at %s: the silhouette is the "
                        "template's, so only something in front of the glass may cover it"
                        % (len(outline_glass), outline_glass[:8]))
    if lining:
        warnings.append("%d pixels of the see-through lining changed, at %s: liquid stays inside "
                        "the lining; only a label or a thing in front of the glass covers it"
                        % (len(lining), lining[:8]))
    if border:
        warnings.append("%d pixels touch the canvas's edge, at %s: keep a pixel clear all round"
                        % (len(border), border[:8]))
    print("%s against the %s template" % (key, arguments.shape))
    print("  inside the glass: %d pixels changed" % len(liquid))
    print("  cork and neck: %d pixels changed, %d of their outline" % (len(cork), len(outline_neck)))
    if extras:
        xs = [x for (x, _y) in extras]
        ys = [y for (_x, y) in extras]
        print("  outside the bottle: %d pixels, in x %d-%d, y %d-%d"
              % (len(extras), min(xs), max(xs), min(ys), max(ys)))
    else:
        print("  outside the bottle: none")
    used = {}
    for row in rows:
        for character in row:
            if character in TONE:
                used[character] = used.get(character, 0) + 1
    print("  colors: " + ", ".join("%s %s (%d)" % (character, NAMES[character], count)
                                    for character, count in sorted(used.items(), key=lambda item: -item[1])))
    for warning in warnings:
        print("WARN: " + warning)
    for error in errors:
        print("ERROR: " + error)
    if errors:
        sys.exit(1)
    print("OK")


def lightened(color, amount):
    return tuple(round(channel + (255 - channel) * amount) for channel in color)


def darkened(color, amount):
    return tuple(round(channel * (1 - amount)) for channel in color)


def plate(side, color, block):
    """A plate as PotionArt draws it: Dither Shading from a lighter top to a darker foot, in
    blocks of one art pixel, edged in near-black with rounded corners."""
    top, foot = lightened(color, LIGHTEN), darkened(color, DARKEN)
    image = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    radius = max(EDGE_WIDTH, round(side * ROUNDING))
    mask = Image.new("L", (side, side), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, side - 1, side - 1], radius=radius, fill=255)
    fill = Image.new("RGBA", (side, side))
    cells = max(1, side // block)
    for cy in range(cells):
        share = cy / max(1, cells - 1)
        for cx in range(cells):
            threshold = (BAYER[cy % 4][cx % 4] + 0.5) / 16
            tone = foot if share > threshold else top
            fill.paste(tone + (255,), (cx * block, cy * block, (cx + 1) * block, (cy + 1) * block))
    image.paste(fill, (0, 0), mask)
    edge = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle([0, 0, side - 1, side - 1], radius=radius,
                                           outline=EDGE + (255,), width=EDGE_WIDTH)
    image.alpha_composite(edge)
    return image


def on_plate(icon, scale, color, large):
    side = (SIZE + 2) * scale if large else SIZE * scale
    picture = plate(side, color, scale)
    offset = scale if large else 0
    picture.alpha_composite(icon.resize((SIZE * scale, SIZE * scale), Image.NEAREST), (offset, offset))
    return picture


def bare(icon, scale):
    side = SIZE * scale
    picture = Image.new("RGBA", (side, side))
    for y in range(SIZE):
        for x in range(SIZE):
            shade = (70, 72, 84) if (x + y) % 2 else (58, 60, 72)
            picture.paste(shade + (255,), (x * scale, y * scale, (x + 1) * scale, (y + 1) * scale))
    picture.alpha_composite(icon.resize((side, side), Image.NEAREST))
    lines = ImageDraw.Draw(picture)
    for step in range(0, SIZE + 1, 8):
        lines.line([(step * scale, 0), (step * scale, side)], fill=(255, 255, 255, 40))
        lines.line([(0, step * scale), (side, step * scale)], fill=(255, 255, 255, 40))
    return picture


def command_preview(arguments):
    rows, key = drawing(arguments.source, arguments.key)
    icon = image_of_grid(rows)
    others = sorted(name[:-4] for name in os.listdir(POTIONS) if name.endswith(".png") and name[:-4] != key)
    font = ImageFont.load_default()
    pad = 12
    width = pad + 5 * (34 * 4 + pad)
    height = 1000
    sheet = Image.new("RGBA", (width, height), SHEET + (255,))
    draw = ImageDraw.Draw(sheet)
    y = pad
    draw.text((pad, y), "%s: bare at 8x, and in the Inspector at 6x on the Rare plate" % key, fill=INK, font=font)
    y += 16
    sheet.alpha_composite(bare(icon, 8), (pad, y))
    sheet.alpha_composite(on_plate(icon, 6, PLATES[2][1], True), (pad + 256 + pad * 2, y))
    y += 256 + pad
    draw.text((pad, y), "Inspector at 4x: " + ", ".join(name for name, _color in PLATES), fill=INK, font=font)
    y += 16
    for index, (_name, color) in enumerate(PLATES):
        sheet.alpha_composite(on_plate(icon, 4, color, True), (pad + index * (136 + pad), y))
    y += 136 + pad
    draw.text((pad, y), "Window entries at 2x and 1x", fill=INK, font=font)
    y += 16
    x = pad
    for _name, color in PLATES:
        sheet.alpha_composite(on_plate(icon, 2, color, False), (x, y))
        x += 64 + pad
    for _name, color in PLATES:
        sheet.alpha_composite(on_plate(icon, 1, color, False), (x, y + 16))
        x += 32 + 6
    y += 64 + pad
    draw.text((pad, y), "Beside the others (%s), at 2x" % ", ".join(others), fill=INK, font=font)
    y += 16
    x = pad
    for name in others + [key]:
        other = icon if name == key else Image.open(os.path.join(POTIONS, name + ".png")).convert("RGBA")
        sheet.alpha_composite(on_plate(other, 2, PLATES[0][1], False), (x, y))
        x += 64 + pad
        if x + 64 > width:
            x = pad
            y += 64 + pad
    y += 64 + pad
    sheet = sheet.crop((0, 0, width, y))
    out = arguments.out or os.path.join("tools/sprites/preview", key + "_potion_review.png")
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    sheet.save(out)
    print(out)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    grid = commands.add_parser("grid")
    grid.add_argument("source")
    grid.set_defaults(run=command_grid)
    fill = commands.add_parser("fill")
    fill.add_argument("shape", choices=SHAPES)
    fill.add_argument("--level", type=int, required=True)
    fill.add_argument("--ramp", required=True)
    fill.add_argument("--key")
    fill.add_argument("--seed", type=int, default=1)
    fill.set_defaults(run=command_fill)
    check = commands.add_parser("check")
    check.add_argument("grid_file")
    check.add_argument("key")
    check.add_argument("shape", choices=SHAPES)
    check.set_defaults(run=command_check)
    preview = commands.add_parser("preview")
    preview.add_argument("source")
    preview.add_argument("key", nargs="?")
    preview.add_argument("--out")
    preview.set_defaults(run=command_preview)
    arguments = parser.parse_args()
    arguments.run(arguments)


if __name__ == "__main__":
    main()
