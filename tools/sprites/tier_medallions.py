"""Draws the Tier Track's medallions (milestone 19) as 32 x 32 PNGs in ui/sprites/tier_track/.

    python3 -I tools/sprites/tier_medallions.py

One medallion for each Magic color and an empty socket. The body is the Node icons' round
medallion (its outline and shading taken from the Chaos Node's grid in
tools/sprites/map_node_icons.txt), in a silvery gray with a faint tint of its gem's color;
at its center, a cut gem: an octagon with a flat table framed by a rim lit on its top-left
edge, and eight crown facets each lit by how it faces the light from the top left, with a
white sparkle on the table's lit corner and a glint of light on the dark far facet. The
empty socket, for a Tier not yet reached, is a dark hollow with a gray rim. Signed off in
milestone 19's prototype. The tinted grays and the gems' colors are not in the shared palette
(tools/sprites/modmox.gpl), which is why this draws the pictures itself rather than going
through tools/sprites/build.sh. Also writes a review sheet to tools/sprites/preview/.
"""
import math
import os

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GRID = os.path.join(ROOT, "tools", "sprites", "map_node_icons.txt")
OUT = os.path.join(ROOT, "ui", "sprites", "tier_track")
SHEET = os.path.join(ROOT, "tools", "sprites", "preview", "tier_medallions.png")

OUTLINE = (20, 20, 26)
# The ring's grays, darkest to lightest: the palette's neutrals 3 to 6.
SILVER = [(69, 74, 92), (102, 109, 130), (154, 163, 181), (195, 201, 214)]
TINT = 0.1
# Each gem's five tones, darkest to lightest, and the color its ring is tinted toward.
GEMS = {
    "white": [(84, 62, 38), (146, 114, 72), (194, 162, 110), (224, 200, 150), (246, 234, 200)],
    "blue": [(16, 34, 92), (28, 76, 168), (52, 136, 228), (124, 192, 250), (214, 240, 255)],
    "black": [(12, 8, 18), (34, 22, 48), (62, 42, 86), (104, 78, 136), (182, 160, 214)],
    "red": [(68, 8, 16), (138, 18, 30), (212, 44, 50), (248, 112, 100), (255, 214, 204)],
    "green": [(10, 58, 24), (26, 118, 48), (58, 182, 80), (132, 228, 130), (222, 255, 216)],
}
SPARKLE = (255, 255, 255)
CX, CY = 15.5, 15.5
GEM_RADIUS = 7.5  # the gem's octagon: |dx| and |dy| within this, |dx| + |dy| within 1.42 times it
TABLE = 3.6  # the table's octagon, the same shape


def body_levels():
    """The Chaos Node's body as levels 0 (darkest) to 3, "o" for its outline, None outside."""
    rows, found = [], False
    for line in open(GRID):
        line = line.rstrip("\n")
        if line.startswith("= chaos_node"):
            found = True
            continue
        if found:
            if len(rows) == 32:
                break
            rows.append(line)
    levels = {"U": 0, "V": 1, "W": 2, "X": 3}
    grid = [[None if c == "." else "o" if c == "0" else levels.get(c, "?") for c in row] for row in rows]
    changed = True
    while changed:  # fill the question mark's pixels from the body round them
        changed = False
        for y in range(32):
            for x in range(32):
                if grid[y][x] == "?":
                    near = [grid[j][i] for j in range(y - 1, y + 2) for i in range(x - 1, x + 2)
                            if 0 <= i < 32 and 0 <= j < 32 and isinstance(grid[j][i], int)]
                    if near:
                        grid[y][x] = max(set(near), key=near.count)
                        changed = True
    return grid


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def in_octagon(dx, dy, radius):
    return abs(dx) <= radius and abs(dy) <= radius and abs(dx) + abs(dy) <= radius * 1.42


def gem_tone(dx, dy):
    """Which of the gem's five tones (0 darkest to 4 lightest) the pixel dx, dy is."""
    if in_octagon(dx, dy, TABLE):
        if not in_octagon(dx, dy, TABLE - 1.0):
            # The table's rim, a ridge that catches the light on its lit side.
            return 4 if dx + dy < 0 else 1
        # The table: a window into the gem, lighter toward the light.
        return 3 if dx + dy < -1 else 2
    # The crown's eight facets, one for each side of the octagon, each lit by how it faces
    # the light from the top left.
    sector = round(math.atan2(dy, dx) / (math.pi / 4)) % 8
    facing = math.cos(sector * math.pi / 4 - math.radians(-135))
    if facing > 0.9:
        return 4
    if facing > 0.5:
        return 3
    if facing > -0.5:
        return 2
    if facing > -0.9:
        return 1
    return 0


def medallion(grid, name):
    tones = GEMS[name]
    ring = [mix(c, tones[2], TINT) for c in SILVER]
    image = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    for y in range(32):
        for x in range(32):
            cell = grid[y][x]
            if cell is None:
                continue
            if cell == "o":
                image.putpixel((x, y), OUTLINE + (255,))
                continue
            dx, dy = x - CX, y - CY
            if in_octagon(dx, dy, GEM_RADIUS):
                is_edge = not in_octagon(dx, dy, GEM_RADIUS - 1.0)
                color = mix(OUTLINE, tones[0], 0.5) if is_edge else tones[gem_tone(dx, dy)]
            elif in_octagon(dx - 1, dy - 1, GEM_RADIUS):
                color = mix(ring[0], OUTLINE, 0.35)  # the gem's shadow on the ring
            else:
                color = ring[cell]
            image.putpixel((x, y), color + (255,))
    # The sparkle: a small cross on the table's lit corner, and a glint of light coming
    # through on the girdle's far side.
    for px, py in [(11, 10), (10, 11), (11, 11), (12, 11), (11, 12)]:
        image.putpixel((px, py), SPARKLE + (255,))
    for px, py in [(20, 20), (19, 20)]:
        image.putpixel((px, py), tones[3] + (255,))
    return image


def empty(grid):
    image = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    for y in range(32):
        for x in range(32):
            cell = grid[y][x]
            if cell is None:
                continue
            dx, dy = x - CX, y - CY
            if cell == "o" or math.hypot(dx, dy) < 11.0:
                color = OUTLINE
            else:
                light = -(dx + dy) / math.hypot(dx, dy)
                color = SILVER[0] if light > 0.5 else SILVER[2] if light < -0.5 else SILVER[1]
            image.putpixel((x, y), color + (255,))
    return image


def main():
    grid = body_levels()
    os.makedirs(OUT, exist_ok=True)
    pictures = {name: medallion(grid, name) for name in GEMS}
    pictures["empty"] = empty(grid)
    for name, picture in pictures.items():
        picture.save(os.path.join(OUT, "tier_%s.png" % name))
    # The review sheet: each at 4 times, on the slate and on Kitty Keep's cream.
    scale, pad = 4, 16
    side = 32 * scale
    sheet = Image.new("RGBA", (pad + len(pictures) * (side + pad), 2 * (side + pad) + pad))
    for row, ground in enumerate([(42, 44, 56), (226, 214, 184)]):
        sheet.paste(ground + (255,), (0, pad // 2 + row * (side + pad), sheet.width, pad // 2 + (row + 1) * (side + pad)))
        for index, picture in enumerate(pictures.values()):
            big = picture.resize((side, side), Image.NEAREST)
            sheet.alpha_composite(big, (pad + index * (side + pad), pad + row * (side + pad)))
    sheet.save(SHEET)
    print("wrote", OUT, "and", SHEET)


main()
