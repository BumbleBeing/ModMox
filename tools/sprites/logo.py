"""Draws the ModMox Logo's frames, one under another in ui/sprites/menu/logo.png.

    python3 -I tools/sprites/logo.py

The word is six blocky characters, each drawn on 32 x 32, its two o's the Mod Icon's cog:
Rare's first, turning clockwise, and Mythic's second, turning against it, each a quarter turn
over the loop of FRAMES frames at FRAMES_PER_SECOND (three seconds). The cog has eight teeth,
so a quarter turn brings it back to where it started and the loop has no seam.

The characters are set evenly and close, by their drawn edges rather than their cells, a cog's
edges being those of every frame together so that no tooth ever touches a letter. Each sits
as near the one before as leaves SPACE between the two, at least LEAST_GAP clear pixels
apart. SPACE is the room between their edges summed over the rows of the lowercase letters,
each row counting SPACE_DEPTH pixels at most, so that a round cog sits closer to a letter than
two straight stems sit to each other and the gaps look alike. The frame is as wide as the
word.

A cog is the Mod Icon (tools/sprites/mod_icon.txt) worked out from its shape rather than its
grid, so that it can be drawn at any angle: a disk, eight teeth and a hole, with the groove
ring in the body. Upright it is the icon's very outline. Only the teeth turn: the light stays
where it is, so each pixel of the body is lit by which way its edge faces now (from the top
left, as the icon is), and the Rarity's sheen (mod_icons.py's) keeps its place on the screen
as the teeth pass through it.

The letters are drawn from the masks in tools/sprites/logo.txt: this outlines each in the
palette's darkest color, as the cog is, lights its top and left edges, shades its bottom and
right ones, and fades its face from light at the top to deeper at the bottom with a 2 x 2
Bayer dither where the two meet, as Dither Shading's bands do. "Mod" is white tinged with
Rare's gold, "Mox" white tinged with Mythic's bronze. The whole word casts a dark shadow a few
pixels down.

Also writes a review sheet to tools/sprites/preview/logo.png (the first frame at four, two and
one times its size on the main menu's window and on a dark ground, then every frame's cogs
at four times) and the loop as tools/sprites/preview/logo.gif at twice its size.
"""
import importlib.util
import math
import os
import sys

from PIL import Image

sys.dont_write_bytecode = True

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GRID = os.path.join(ROOT, "tools", "sprites", "logo.txt")
MOD_ICONS = os.path.join(ROOT, "tools", "sprites", "mod_icons.py")
OUT = os.path.join(ROOT, "ui", "sprites", "menu", "logo.png")
SHEET = os.path.join(ROOT, "tools", "sprites", "preview", "logo.png")
LOOP = os.path.join(ROOT, "tools", "sprites", "preview", "logo.gif")

SIZE = 32
# The word, one character to a cell: a letter's mask and its tint, or a Rarity's cog and the
# way it turns (1 clockwise, -1 against).
WORD = [("letter", "M", "gold"), ("cog", "rare", 1), ("letter", "d", "gold"),
        ("letter", "M", "bronze"), ("cog", "mythic", -1), ("letter", "x", "bronze")]
# How the characters are set: the room between two, the most a row counts toward it, the rows
# it is counted over (those of the lowercase letters, outline and all), and the fewest clear
# pixels between two.
SPACE = 36
SPACE_DEPTH = 6
SPACE_ROWS = range(10, 28)
LEAST_GAP = 1
# The loop, as MenuLogo plays it, and how far a cog turns over it: two teeth.
FRAMES = 24
FRAMES_PER_SECOND = 8
TURN = math.pi / 2
# The cog's shape, in pixels from the middle of its center pixel, without the outline: the
# disk, the hole, how far the teeth reach and half their width, and the groove ring's radius
# and half its width. These give the Mod Icon's own outline when it is upright.
CENTER = 15
DISK = 9.6
HOLE = 3.2
TOOTH_REACH = 12.8
TOOTH_HALF_WIDTH = 2.5
TEETH = 8
GROOVE = 7.0
GROOVE_HALF_WIDTH = 0.4
# Where the cog's light comes from, and how squarely an edge must face toward it or away from
# it to be lit or shaded.
LIGHT = (-0.6, -0.8)
FACING = 0.9
# The outline: the palette's darkest color, the cog's.
OUTLINE = (20, 20, 26)
# Each tint's tones: the shaded edge, the face's deeper tone, its lighter one, and the lit edge.
TINTS = {
    "gold": ["#d6b26c", "#f7e8c2", "#fffaea", "#ffffff"],
    "bronze": ["#d98d55", "#fbdcbf", "#fff4e8", "#ffffff"],
}
# Where the face turns from its lighter tone to its deeper one, as a share of the tallest
# letter's height, the same row in every letter so that the word is lit as one; and over how
# many rows the two are dithered together.
FACE_TURN = 0.55
FACE_DITHER_ROWS = 4
BAYER = [[0.0, 0.5], [0.75, 0.25]]
# The shadow the word casts: how far down, and its color.
SHADOW_DROP = 2
SHADOW = (12, 10, 14, 150)
DARK = (34, 28, 28)
WINDOW = (75, 63, 63)
PAD = 12


def load_mod_icons():
    """mod_icons.py, for the cog's Rarity tones and sheen."""
    spec = importlib.util.spec_from_file_location("mod_icons", MOD_ICONS)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def rgb(text):
    return tuple(int(text[i:i + 2], 16) for i in (1, 3, 5))


def read_masks():
    """Each letter's 32 rows, by its name."""
    masks = {}
    name = None
    for line in open(GRID):
        line = line.rstrip("\n")
        if line.startswith("= "):
            name = line[2:].strip()
            masks[name] = []
        elif line and line[0] not in ";@" and name is not None:
            masks[name].append(line)
    for name, rows in masks.items():
        assert len(rows) == SIZE and all(len(row) == SIZE for row in rows), "%s is not 32 x 32" % name
    return masks


def is_cog_body(x, y, angle):
    """Whether pixel ([param x], [param y]) is in the body of a cog turned [param angle]
    radians clockwise."""
    dx, dy = x - CENTER, y - CENTER
    reach = math.hypot(dx, dy)
    if reach < HOLE:
        return False
    if reach <= DISK:
        return True
    for tooth in range(TEETH):
        toward = angle + tooth * 2 * math.pi / TEETH
        ux, uy = math.sin(toward), -math.cos(toward)
        along = dx * ux + dy * uy
        across = abs(dx * uy - dy * ux)
        if 0 <= along <= TOOTH_REACH and across <= TOOTH_HALF_WIDTH:
            return True
    return False


def cog_rows(angle):
    """A cog turned [param angle] radians clockwise as the Mod Icon's grid has it: 0 the
    outline, H the groove, J a lit edge, G a shaded one and I the rest."""
    body = [[is_cog_body(x, y, angle) for x in range(SIZE)] for y in range(SIZE)]

    def on(x, y):
        return 0 <= x < SIZE and 0 <= y < SIZE and body[y][x]

    rows = []
    for y in range(SIZE):
        row = ""
        for x in range(SIZE):
            if not on(x, y):
                outlined = any(on(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                row += "0" if outlined else "."
                continue
            # Which way the edge here faces: toward the neighbors outside the body.
            facing_x = facing_y = 0
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if (dx or dy) and not on(x + dx, y + dy):
                        facing_x += dx
                        facing_y += dy
            lit = facing_x * LIGHT[0] + facing_y * LIGHT[1]
            if abs(math.hypot(x - CENTER, y - CENTER) - GROOVE) <= GROOVE_HALF_WIDTH:
                row += "H"
            elif lit > FACING:
                row += "J"
            elif lit < -FACING:
                row += "G"
            else:
                row += "I"
        rows.append(row)
    return rows


def draw_letter(rows, tint, turn):
    """The letter whose body is the # of [param rows], outlined and shaded in [param tint],
    its face turning deeper at row [param turn]."""
    tones = [rgb(tone) for tone in TINTS[tint]]
    edge_dark, face_deep, face_light, edge_light = tones

    def body(x, y):
        return 0 <= x < SIZE and 0 <= y < SIZE and rows[y][x] == "#"

    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    for y in range(SIZE):
        for x in range(SIZE):
            if not body(x, y):
                if any(body(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    image.putpixel((x, y), OUTLINE + (255,))
                continue
            if not body(x, y - 1) or not body(x - 1, y) and body(x, y + 1):
                color = edge_light
            elif not body(x, y + 1) or not body(x + 1, y):
                color = edge_dark
            else:
                # The face: light above the turn, deep below it, dithered across it.
                share = (y - turn) / FACE_DITHER_ROWS + 0.5
                color = face_deep if share > BAYER[y % 2][x % 2] else face_light
            image.putpixel((x, y), color + (255,))
    return image


def edges(pictures):
    """The leftmost and the rightmost drawn column of each row over all [param pictures], by
    row: rows drawn in none are left out."""
    left, right = {}, {}
    for picture in pictures:
        alpha = picture.getchannel("A")
        for y in range(SIZE):
            drawn = [x for x in range(SIZE) if alpha.getpixel((x, y))]
            if drawn:
                left[y] = min(left.get(y, SIZE), drawn[0])
                right[y] = max(right.get(y, -1), drawn[-1])
    return left, right


def place(characters):
    """Where each of [param characters] (its pictures over the loop) sets its 32 x 32 cell,
    from the left of the word: the first touches it, and each after sits as near the one
    before as leaves SPACE between them and LEAST_GAP clear pixels in every row."""
    sides = [edges(pictures) for pictures in characters]
    places = [-min(sides[0][0].values())]
    for (_, before), (after, _) in zip(sides, sides[1:]):
        last = places[-1]
        shared = set(before) & set(after)
        at = max(last + before[y] + 1 + LEAST_GAP - after[y] for y in shared)

        def space(at):
            return sum(min(SPACE_DEPTH, at + after.get(y, 2 * SIZE) - last - before.get(y, -2 * SIZE) - 1)
                       for y in SPACE_ROWS)

        while space(at) < SPACE:
            at += 1
        places.append(at)
    width = places[-1] + max(sides[-1][1].values()) + 1
    return places, width


def draw_logo(cells, places, width):
    """One frame of the Logo: each of [param cells] set at its place in [param places], the
    word [param width] wide, with the shadow it casts."""
    word = Image.new("RGBA", (width, SIZE), (0, 0, 0, 0))
    for cell, at in zip(cells, places):
        # The first character's cell may begin left of the word, where it draws nothing.
        word.alpha_composite(cell.crop((max(0, -at), 0, SIZE, SIZE)), (max(0, at), 0))
    # The shadow: the word's shape, a few pixels down, under it.
    logo = Image.new("RGBA", word.size, (0, 0, 0, 0))
    shade = Image.new("RGBA", word.size, SHADOW[:3] + (0,))
    shade.putalpha(word.getchannel("A").point(lambda alpha: SHADOW[3] if alpha else 0))
    logo.alpha_composite(shade, (0, SHADOW_DROP))
    logo.alpha_composite(word)
    return logo


def draw_frames():
    """The Logo's frames, and each character's pictures over the loop."""
    mod_icons = load_mod_icons()
    fixed = mod_icons.palette_tones()
    masks = read_masks()
    filled = [y for rows in masks.values() for y in range(SIZE) if "#" in rows[y]]
    turn = min(filled) + (max(filled) - min(filled) + 1) * FACE_TURN
    characters = []
    for kind, name, way in WORD:
        if kind == "cog":
            characters.append([mod_icons.draw(cog_rows(way * TURN * frame / FRAMES), name, fixed)
                               for frame in range(FRAMES)])
        else:
            characters.append([draw_letter(masks[name], way, turn)] * FRAMES)
    places, width = place(characters)
    frames = [draw_logo([pictures[frame] for pictures in characters], places, width) for frame in range(FRAMES)]
    return frames, characters


def review_sheet(frames, characters):
    """The first frame at four, two and one times its size on the window and on a dark
    ground, then every frame's cogs (of [param characters]) at four times."""
    width = frames[0].width * 4 + PAD * 2
    strips = []
    for scale in (4, 2, 1):
        for ground in (WINDOW, DARK):
            big = frames[0].resize((frames[0].width * scale, frames[0].height * scale), Image.NEAREST)
            strip = Image.new("RGBA", (width, big.height + PAD * 2), ground + (255,))
            strip.alpha_composite(big, (PAD, PAD))
            strips.append(strip)
    cogs = [index for index, (kind, _, _) in enumerate(WORD) if kind == "cog"]
    side = SIZE * 4
    per_row = (width - PAD) // (side * len(cogs) + PAD)
    rows = -(-len(frames) // per_row)
    grid = Image.new("RGBA", (width, rows * (side + PAD) + PAD), WINDOW + (255,))
    for number, frame in enumerate(frames):
        x = PAD + (number % per_row) * (side * len(cogs) + PAD)
        y = PAD + (number // per_row) * (side + PAD)
        for place, index in enumerate(cogs):
            cell = characters[index][number].resize((side, side), Image.NEAREST)
            grid.alpha_composite(cell, (x + place * side, y))
    strips.append(grid)
    sheet = Image.new("RGBA", (width, sum(strip.height for strip in strips)), DARK + (255,))
    y = 0
    for strip in strips:
        sheet.alpha_composite(strip, (0, y))
        y += strip.height
    return sheet


def main():
    frames, characters = draw_frames()
    strip = Image.new("RGBA", (frames[0].width, SIZE * FRAMES), (0, 0, 0, 0))
    for number, frame in enumerate(frames):
        strip.alpha_composite(frame, (0, number * SIZE))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    strip.save(OUT)
    os.makedirs(os.path.dirname(SHEET), exist_ok=True)
    review_sheet(frames, characters).save(SHEET)
    shown = []
    for frame in frames:
        ground = Image.new("RGBA", (frame.width + PAD * 2, frame.height + PAD * 2), WINDOW + (255,))
        ground.alpha_composite(frame, (PAD, PAD))
        shown.append(ground.resize((ground.width * 2, ground.height * 2), Image.NEAREST).convert("RGB"))
    shown[0].save(LOOP, save_all=True, append_images=shown[1:], duration=1000 // FRAMES_PER_SECOND, loop=0)
    print("OK: %d frames of %d x %d in %s, sheet at %s, loop at %s" % (
        FRAMES, frames[0].width, SIZE, os.path.relpath(OUT, ROOT), os.path.relpath(SHEET, ROOT),
        os.path.relpath(LOOP, ROOT)))


if __name__ == "__main__":
    main()
