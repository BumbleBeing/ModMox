#!/usr/bin/env python3
"""Helpers for drawing an Armor Icon in the shape of its Armor Slot's template.

Run from the repo root, as `python3 -I .claude/skills/draw-armor-icon/scripts/armor.py ...`:

  grid SOURCE
      Print SOURCE as a 32 x 32 grid in the characters of tools/sprites/*.txt. SOURCE is a
      slot (helm, cuirass, greaves), a .png or an .aseprite file. A slot's template prints as
      a map, not a drawing: 0 its edge, = its inner lines (the helm's face opening, the seam
      between the greaves' legs, the cuirass's fauld), - the inside to paint.
  base SLOT --ramp RAMP [--key KEY] [--matte]
      Print the slot's template filled as one solid form in RAMP, lit from the upper left: a
      starting point to draw over. RAMP is a ramp name (steel, gilded, black, red, rust,
      earth, flesh, gold, olive, green, teal, blue, violet, rose, silver, bronze, bone) or five palette characters,
      darkest to lightest; all five are used. --matte leaves out the white glint (leather,
      cloth, bone).
  set GRID_FILE KEY X,Y=CHARS...
      Paint pixels into a drawing in place: CHARS from column X rightward on row Y, both
      counted from 0. Prints the drawing after.
  mirror GRID_FILE [KEY] --slot SLOT [--copy]
      Print the drawing with its left half mirrored onto its right half. With --copy (the
      greaves only), the left leg is moved across onto the right leg instead, so each keeps
      its own light from its upper left.
  compare SOURCE... --out PNG
      Draw drafts side by side: each bare at 8x, then at 3x on an entry's parchment and in
      its Armor Slot, and at 1x. A SOURCE is a .png, a grid file (all its drawings) or
      FILE:KEY.
  check GRID_FILE KEY SLOT
      Check the drawing named KEY in GRID_FILE (or a .png) against SLOT's template.
  preview SOURCE [KEY] --slot SLOT [--out PNG]
      Draw the review sheet: the icon bare at 8x and against its template, then as the
      Satchel shows it at 3x (on an entry's parchment, in its Armor Slot, and in the Worn
      column under the Hero's Portrait), at 2x and 1x, and beside the Armor Icons already in
      ui/sprites/armor/ (or, while there are none, the liked ones in references/examples.md).

The templates are the .aseprite files in tools/sprites/armor_templates/, read through Aseprite
(found at $ASEPRITE, else ~/Projects/aseprite/build/bin/aseprite); each has a matching .png.
"""

import argparse
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

SIZE = 32
SLOTS = ["helm", "cuirass", "greaves"]
TEMPLATES = "tools/sprites/armor_templates"
ARMOR = "ui/sprites/armor"
PALETTE_FILE = "tools/sprites/modmox.gpl"
# One character for each color of modmox.gpl, in its order (as KEY in build_sprites.lua).
KEY = ("0123+56#" "abcde" "fghij" "klmno" "pqrst" "uvwxy" "ABCDE" "FGHIJ" "KLMNO" "PQRST"
       "UVWXY" "zZ489" "!$%&*")
RAMPS = {
    "red": "abcde", "rust": "fghij", "earth": "klmno", "flesh": "pqrst", "gold": "uvwxy",
    "olive": "ABCDE", "green": "FGHIJ", "teal": "KLMNO", "blue": "PQRST", "violet": "UVWXY",
    "rose": "zZ489",
    # Steel: Neutral 2 to Neutral 7 (white, Neutral 8, is the glint).
    "neutral": "123+6", "steel": "123+6",
    # Gold as the liked Lionguard Helm has it: the gold ramp alone reads as brass or khaki,
    # so bright yellow carries the lit body and the ramp's own steps the shade.
    "gilded": "vwx$y",
    # Polished, pale steel, for white: lighter than steel by a step.
    "silver": "23+56",
    # Blackened iron as the liked Hornward Helm has it: a Neutral 2 body, shaded toward Blue
    # darkest, lit in Neutral 3 and 4 (pour it --matte; a white glint is too loud on it).
    "black": "P1123",
    # Bone, as the liked Gravewatch Helm has it: a pale gray lit body over cream and tan, and
    # a warm sheen (pour it --matte). Earth lightest alone is the Satchel's parchment, so a
    # piece lit in it vanishes there.
    "bone": "mno6t",
    # Bronze: the rust ramp alone reads as rust or clay, so bright yellow lights it.
    "bronze": "fgh$y",
}
# The Satchel prototype's grounds (prototypes/satchel/satchel.gd): an entry's parchment and
# its edge, the Worn column's set-in panel, an Armor Slot's dark square and its edge.
PAPER = (0xe9, 0xdc, 0xbc)
PAPER_EDGE = (0x7a, 0x62, 0x43)
SET_IN = (0x3f, 0x2a, 0x1b)
SLOT_GROUND = (0x2c, 0x1d, 0x12)
SLOT_EDGE = (0x1c, 0x12, 0x0b)
SCALE = 3
SHEET = (42, 44, 56)
INK = (195, 201, 214)
# A template pixel is outline when at least this opaque (the templates draw it at 60%), and
# inside when painted more faintly (12%).
LINE_ALPHA = 100


def fail(message):
    print("ERROR: " + message, file=sys.stderr)
    sys.exit(1)


def palette():
    colors, names = [], []
    with open(PALETTE_FILE) as handle:
        for line in handle:
            parts = line.split()
            if len(parts) >= 3 and all(part.isdigit() for part in parts[:3]):
                colors.append(tuple(int(part) for part in parts[:3]))
                names.append(" ".join(parts[3:]))
    if len(colors) != len(KEY):
        fail("%s has %d colors but KEY names %d" % (PALETTE_FILE, len(colors), len(KEY)))
    return colors, names


COLORS, _NAMES = palette()
TONE = {KEY[index]: color for index, color in enumerate(COLORS)}
NAMES = {KEY[index]: name for index, name in enumerate(_NAMES)}


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
            row += "." if a == 0 else lookup.get((r, g, b), "?") if a == 255 else "?"
        rows.append(row)
    return rows


class Template:
    """A slot's template read as a map: OUTSIDE, its EDGE (the outline against the outside),
    its LINES (outline inside the shape: the face opening, a seam) and its INSIDE."""

    def __init__(self, slot):
        if slot not in SLOTS:
            fail("no Armor Slot '%s'; they are %s" % (slot, ", ".join(SLOTS)))
        path = None
        for extension in (".aseprite", ".png"):
            candidate = os.path.join(TEMPLATES, slot + extension)
            if os.path.exists(candidate):
                path = candidate
                break
        if path is None:
            fail("no template for %s in %s" % (slot, TEMPLATES))
        image = image_of(path)
        self.slot = slot
        self.shape, line, self.inside = set(), set(), set()
        for y in range(SIZE):
            for x in range(SIZE):
                alpha = image.getpixel((x, y))[3]
                if alpha == 0:
                    continue
                self.shape.add((x, y))
                (line if alpha >= LINE_ALPHA else self.inside).add((x, y))
        self.edge = {(x, y) for (x, y) in line
                     if any(neighbor not in self.shape for neighbor in around(x, y))}
        self.lines = line - self.edge

    def map_rows(self):
        rows = []
        for y in range(SIZE):
            row = ""
            for x in range(SIZE):
                point = (x, y)
                row += "0" if point in self.edge else "=" if point in self.lines else \
                    "-" if point in self.inside else "."
            rows.append(row)
        return rows

    def regions(self):
        """The inside split into its parts by the lines: each a set of points."""
        left, parts = set(self.inside), []
        while left:
            stack, part = [left.pop()], set()
            while stack:
                point = stack.pop()
                part.add(point)
                for neighbor in around(*point):
                    if neighbor in left:
                        left.discard(neighbor)
                        stack.append(neighbor)
            parts.append(part)
        return sorted(parts, key=lambda part: min((y, x) for (x, y) in part))


def around(x, y):
    return [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]


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
            if character in TONE:
                image.putpixel((x, y), TONE[character] + (255,))
    return image


def ramp_of(text):
    ramp = RAMPS.get(text, text)
    if len(ramp) != 5 or any(character not in TONE for character in ramp):
        fail("a ramp is a name (%s) or five palette characters" % ", ".join(RAMPS))
    return ramp


def command_grid(arguments):
    source = arguments.source
    if source in SLOTS:
        print("= " + source)
        print("\n".join(Template(source).map_rows()))
        return
    rows, key = drawing(source, None)
    print("= " + key)
    print("\n".join(rows))


def command_base(arguments):
    """The template filled as one solid form under a light from the upper left, the way the
    liked icons are shaded (references/examples.md): across each part, lit on its left, mid in
    its middle, dark toward its right and darkest near its right edge, with a pixel of
    reflected light against it; its top lit and its foot darkened; the lip beside or below an
    inner line lit; on the greaves, a dark band where each part overhangs the next; and a
    one-pixel highlight down the left of each section, with a white glint unless --matte."""
    template = Template(arguments.slot)
    steps = ramp_of(arguments.ramp)  # darkest, dark, mid, light, lightest
    rows = [["."] * SIZE for _ in range(SIZE)]
    for point in template.edge | template.lines:
        rows[point[1]][point[0]] = "0"

    def run_of(point, part):
        """The stretch of the row the point's form spans: the row of its part, cut only where
        empty canvas parts it (the cuirass's two shoulders), not where an inner line does
        (the helm's face opening runs through one form)."""
        x, y = point
        left = right = x
        while (left - 1, y) in part or ((left - 1, y) in template.lines and (left - 2, y) in part):
            left -= 1
        while (right + 1, y) in part or ((right + 1, y) in template.lines and (right + 2, y) in part):
            right += 1
        return left, right

    for part in template.regions():
        spans = {}
        for (x, y) in part:
            spans.setdefault(y, []).append(x)
        part_rows = sorted(spans)
        count = len(part_rows)
        level = {}
        for (x, y) in part:
            left, right = run_of((x, y), part)
            across = (x - left + 0.5) / (right - left + 1)
            # Across the form: light, mid, dark, darkest (steps 3, 2, 1, 0).
            step = 3 if across < 0.4 else 2 if across < 0.6 else 1 if across < 0.82 else 0
            down = part_rows.index(y) / max(1, count - 1)
            if down < 0.12:
                step = min(3, step + 1)
            if (x, y + 1) not in part:
                step = max(0, step - 1)
            # The lip beside or below an inner line catches the light (the cheek beside the
            # face opening, the fauld's top under its line).
            if ((x - 1, y) not in part and (x - 1, y) in template.lines) or (x, y - 1) in template.lines:
                step = max(step, 3)
            # Reflected light: a pixel of the dark step along the right edge, so the shade
            # doesn't run into the outline and vanish in the dark Armor Slot.
            if step == 0 and (x + 1, y) in template.edge and right - left + 1 >= 6:
                step = 1
            level[(x, y)] = step
        # Where a greave narrows below (the knee cop over the shin, the shin over the ankle),
        # the upper part's foot is dark and the lower part's top lies in its shadow; each
        # section between is lit on its own.
        sections, section = [], []
        for y in part_rows:
            section.append(y)
            narrows = (template.slot == "greaves" and y + 1 in spans
                       and min(spans[y + 1]) > min(spans[y]) and max(spans[y + 1]) < max(spans[y]))
            if narrows:
                for x in spans[y]:
                    level[(x, y)] = min(level[(x, y)], 1)
                for x in spans[y + 1]:
                    level[(x, y + 1)] = 0
                sections.append(section)
                section = []
        sections.append(section)
        # The highlight: one pixel two in from the left, down each section's upper part,
        # ending where it would have to jump, so it stays one clean line.
        for section in sections:
            rows_here = [y for y in section if all(level[(x, y)] != 0 for x in spans[y])]
            if not rows_here:
                continue
            widest = max(max(spans[y]) - min(spans[y]) + 1 for y in rows_here)
            streak, last = [], None
            for y in rows_here:
                left = min(spans[y])
                # It starts only where the row's leftmost run of plate is wide (the chest, not
                # a shoulder strap), then follows the left edge down.
                run = 0
                while (left + run, y) in part:
                    run += 1
                if not streak and run < 0.7 * widest:
                    continue
                x = left + 2
                if last is not None and abs(x - last) > 1:
                    break
                if (x, y) not in part or len(streak) >= max(3, len(rows_here) * 2 // 5):
                    break
                streak.append((x, y))
                last = x
            for point in streak:
                level[point] = 4
            if streak and not arguments.matte:
                level[streak[min(1, len(streak) - 1)]] = 5
        for (x, y), step in level.items():
            rows[y][x] = "#" if step == 5 else steps[step]
    print("@ size %d" % SIZE)
    print("= " + (arguments.key or arguments.slot))
    print("\n".join("".join(row) for row in rows))


def command_set(arguments):
    """Paints pixels into the drawing KEY of GRID_FILE, in place: each X,Y=CHARS writes CHARS
    from column X rightward on row Y (both 0-based), so a row is edited by its coordinates
    rather than by counting characters."""
    with open(arguments.grid_file) as handle:
        lines = handle.read().splitlines()
    if ("= " + arguments.key) not in lines:
        fail("%s has no '= %s'" % (arguments.grid_file, arguments.key))
    top = lines.index("= " + arguments.key) + 1
    for paint in arguments.paints:
        place, _equals, characters = paint.partition("=")
        try:
            x, y = (int(part) for part in place.split(","))
        except ValueError:
            fail("'%s' is not X,Y=CHARS" % paint)
        if not (0 <= y < SIZE and 0 <= x and x + len(characters) <= SIZE):
            fail("'%s' runs off the 32 x 32 canvas" % paint)
        for character in characters:
            if character not in TONE and character != ".":
                fail("'%s' is no palette color" % character)
        row = lines[top + y]
        lines[top + y] = row[:x] + characters + row[x + len(characters):]
    with open(arguments.grid_file, "w") as handle:
        handle.write("\n".join(lines) + "\n")
    print("\n".join(lines[top:top + SIZE]))


def luminance(color):
    r, g, b = color
    return 0.299 * r + 0.587 * g + 0.114 * b


def command_check(arguments):
    rows, key = drawing(arguments.grid_file, arguments.key)
    if len(rows) != SIZE or any(len(row) != SIZE for row in rows):
        fail("%s must be %d rows of %d characters (it has %d rows, widths %s)"
             % (key, SIZE, SIZE, len(rows), sorted({len(row) for row in rows})))
    template = Template(arguments.slot)
    errors, warnings = [], []
    for y, row in enumerate(rows):
        for x, character in enumerate(row):
            if character not in TONE and character != ".":
                errors.append("(%d, %d) is '%s', which is no palette color (an Armor Icon has no "
                              "see-through glass)" % (x, y, character))

    def at(point):
        return rows[point[1]][point[0]]

    empty = sorted(point for point in template.shape if at(point) == ".")
    if empty:
        errors.append("%d pixels of the template's shape are left empty, at %s: the piece fills "
                      "its template's shape" % (len(empty), empty[:8]))
    edge_changed = sorted(point for point in template.edge if at(point) not in ".0")
    if edge_changed:
        warnings.append("%d pixels of the template's edge are not the outline, at %s: the "
                        "silhouette is the template's, so only something standing in front "
                        "of the piece may cover it" % (len(edge_changed), edge_changed[:8]))
    dark = {"0", "1", "2"} | {ramp[0] for ramp in RAMPS.values()}
    lines_changed = sorted(point for point in template.lines if at(point) not in dark)
    if lines_changed:
        warnings.append("%d pixels of the template's inner lines (%s) are not dark, at %s: "
                        "keep them unless something is meant to show in them, such as eyes "
                        "glowing in a face opening"
                        % (len(lines_changed), INNER_LINES[template.slot], lines_changed[:8]))
    widened = []
    for y in sorted({y for (_x, y) in template.lines}):
        line_xs = [x for (x, row_y) in template.lines if row_y == y]
        inside = [x for (x, row_y) in template.inside if row_y == y]
        for side, xs in (("left", [x for x in inside if x < min(line_xs)]),
                         ("right", [x for x in inside if x > max(line_xs)])):
            if xs and all(rows[y][x] == "0" for x in xs):
                widened.append((y, side))
    if widened:
        warnings.append("%s runs out to the edge on %s: the piece beside it is painted in the "
                        "outline color, so the line no longer reads as its shape"
                        % (INNER_LINES[template.slot],
                           ", ".join("row %d (%s)" % item for item in widened[:6])))
    painted = {(x, y) for y in range(SIZE) for x in range(SIZE) if rows[y][x] != "."}
    extras = sorted(painted - template.shape)
    border = sorted((x, y) for (x, y) in painted if x in (0, SIZE - 1) or y in (0, SIZE - 1))
    if border:
        errors.append("%d pixels touch the canvas's edge, at %s: keep a pixel clear all round"
                      % (len(border), border[:8]))
    unlined = sorted((x, y) for (x, y) in extras if at((x, y)) != "0" and any(
        not (0 <= nx < SIZE and 0 <= ny < SIZE) or rows[ny][nx] == "." for (nx, ny) in around(x, y)))
    if unlined:
        warnings.append("%d pixels of what stands outside the template meet the empty canvas "
                        "without the outline, at %s" % (len(unlined), unlined[:8]))
    used = {}
    for row in rows:
        for character in row:
            if character in TONE:
                used[character] = used.get(character, 0) + 1
    body = [character for point in painted for character in at(point) if character != "0"]
    if len(set(body)) < 3:
        warnings.append("the piece is painted in %d colors besides the outline: a flat piece "
                        "reads as a sticker; shade it" % len(set(body)))
    if body:
        dim = sum(1 for character in body if luminance(TONE[character]) < 60) / len(body)
        if dim > 0.5:
            warnings.append("%d%% of the piece is darker than the Armor Slot's square can show: "
                            "light its edges and highlights so it doesn't vanish there"
                            % round(dim * 100))
    print("%s against the %s template" % (key, template.slot))
    print("  the template's shape: %d pixels, %d painted" % (len(template.shape),
                                                              len(template.shape) - len(empty)))
    if extras:
        xs = [x for (x, _y) in extras]
        ys = [y for (_x, y) in extras]
        print("  outside the template: %d pixels, in x %d-%d, y %d-%d"
              % (len(extras), min(xs), max(xs), min(ys), max(ys)))
    else:
        print("  outside the template: none")
    print("  colors: " + ", ".join("%s %s (%d)" % (character, NAMES[character], count)
                                    for character, count in sorted(used.items(), key=lambda item: -item[1])))
    for warning in warnings:
        print("WARN: " + warning)
    for error in errors:
        print("ERROR: " + error)
    if errors:
        sys.exit(1)
    print("OK")


INNER_LINES = {
    "helm": "the T-shaped face opening",
    "cuirass": "the line between the breastplate and the fauld",
    "greaves": "the seam between the legs",
}


def command_mirror(arguments):
    """The drawing with its left half copied onto its right: mirrored, or with --copy (the
    greaves only) the left leg moved across onto the right one, so both keep their light."""
    rows, key = drawing(arguments.grid_file, arguments.key)
    out = [list(row) for row in rows]
    if arguments.copy:
        if arguments.slot != "greaves":
            fail("--copy moves the left leg onto the right, so it is for the greaves only")
        for y in range(SIZE):
            for x in range(4, 16):
                out[y][x + 12] = rows[y][x]
    else:
        for y in range(SIZE):
            for x in range(16):
                out[y][SIZE - 1 - x] = rows[y][x]
    print("@ size %d" % SIZE)
    print("= " + key)
    print("\n".join("".join(row) for row in out))


def sources_of(texts):
    """Each source of compare: a .png, an .aseprite file, a grid file of one drawing, or
    FILE:KEY for one drawing in a grid file of several. Returns (label, rows) pairs."""
    found = []
    for text in texts:
        path, _colon, key = text.partition(":") if not os.path.exists(text) else (text, "", "")
        if not path.endswith((".png", ".aseprite")) and not key:
            for name, rows in read_blocks(path).items():
                found.append((name, rows))
            continue
        rows, name = drawing(path, key or None)
        found.append((name, rows))
    return found


def command_compare(arguments):
    """Drafts side by side: each bare at 8x, then as the Satchel shows it at 3x, on an entry's
    parchment and in its Armor Slot, and at 1x."""
    found = sources_of(arguments.sources)
    font = ImageFont.load_default()
    pad = 16
    column = SIZE * 8 + pad
    sheet = Image.new("RGBA", (pad + len(found) * column, 16 + 256 + pad + 128 + pad + 40),
                      SHEET + (255,))
    draw = ImageDraw.Draw(sheet)
    for index, (name, rows) in enumerate(found):
        icon = image_of_grid(rows)
        x = pad + index * column
        draw.text((x, 4), name, fill=INK, font=font)
        sheet.alpha_composite(checker(icon, 8), (x, 18))
        y = 18 + 256 + pad
        sheet.alpha_composite(entry(icon, SCALE), (x, y))
        sheet.alpha_composite(armor_slot(icon, SCALE), (x + SIZE * SCALE + 24 + 8, y))
        sheet.alpha_composite(entry(icon, 1), (x, y + 120))
        sheet.alpha_composite(armor_slot(icon, 1), (x + SIZE + 24 + 8, y + 124))
    out = arguments.out
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    sheet.save(out)
    print(out)


EXAMPLES = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        "references", "examples.md")


def liked_examples():
    """The grids in references/examples.md, by key, in the order they appear."""
    found, current, inside = [], None, False
    if not os.path.exists(EXAMPLES):
        return found
    with open(EXAMPLES) as handle:
        for line in handle:
            line = line.rstrip()
            if line.startswith("```"):
                inside = not inside
                current = None
                continue
            if inside and line.startswith("= "):
                current = (line[2:].strip(), [])
                found.append(current)
            elif inside and current is not None and len(line) == SIZE:
                current[1].append(line)
    return [(name, rows) for (name, rows) in found if len(rows) == SIZE]


def scaled(image, scale):
    return image.resize((image.width * scale, image.height * scale), Image.NEAREST)


def checker(icon, scale):
    side = SIZE * scale
    picture = Image.new("RGBA", (side, side))
    for y in range(SIZE):
        for x in range(SIZE):
            shade = (128, 132, 140) if (x + y) % 2 else (112, 116, 124)
            picture.paste(shade + (255,), (x * scale, y * scale, (x + 1) * scale, (y + 1) * scale))
    picture.alpha_composite(scaled(icon, scale))
    return picture


def against_template(icon, rows, template, scale):
    """The icon at SCALE with what strays from the template marked: magenta where the
    template's edge or lines are not dark, cyan over what stands outside the shape."""
    picture = checker(icon, scale)
    marks = ImageDraw.Draw(picture)
    dark = {"0", "1", "2"} | {ramp[0] for ramp in RAMPS.values()}
    for y in range(SIZE):
        for x in range(SIZE):
            box = [x * scale + 1, y * scale + 1, (x + 1) * scale - 2, (y + 1) * scale - 2]
            if (x, y) in template.edge | template.lines and rows[y][x] not in dark:
                marks.rectangle(box, outline=(255, 0, 255, 255), width=2)
            elif (x, y) not in template.shape and rows[y][x] != ".":
                marks.rectangle(box, outline=(0, 230, 255, 255), width=1)
    return picture


def entry(icon, scale):
    """A piece of a Satchel entry's parchment with the icon on it."""
    side = SIZE * scale
    picture = Image.new("RGBA", (side + 24, side + 16), (0, 0, 0, 0))
    ImageDraw.Draw(picture).rounded_rectangle([0, 0, side + 23, side + 15], radius=8,
                                              fill=PAPER + (255,), outline=PAPER_EDGE + (255,),
                                              width=2)
    picture.alpha_composite(scaled(icon, scale), (12, 8))
    return picture


def armor_slot(icon, scale):
    """An Armor Slot's dark square with the icon on it, as the Worn column draws it."""
    side = SIZE * scale + 4
    picture = Image.new("RGBA", (side, side), SLOT_GROUND + (255,))
    ImageDraw.Draw(picture).rectangle([0, 0, side - 1, side - 1], outline=SLOT_EDGE + (255,), width=2)
    picture.alpha_composite(scaled(icon, scale), (2, 2))
    return picture


def worn_column(icon, slot):
    """The three Armor Slots under the Hero's Portrait: this icon in its slot and each other
    slot's template (the empty slot) or, when given, that slot's icon."""
    gap = 8
    side = SIZE * SCALE + 4
    picture = Image.new("RGBA", (side + 32, 3 * side + 2 * gap + 32), SET_IN + (255,))
    for index, other in enumerate(SLOTS):
        shown = icon if other == slot else image_of(os.path.join(TEMPLATES, other + ".png"))
        picture.alpha_composite(armor_slot(shown, SCALE), (16, 16 + index * (side + gap)))
    return picture


def command_preview(arguments):
    rows, key = drawing(arguments.source, arguments.key)
    template = Template(arguments.slot)
    icon = image_of_grid(rows)
    font = ImageFont.load_default()
    pad = 16
    width = 900
    sheet = Image.new("RGBA", (width, 1400), SHEET + (255,))
    draw = ImageDraw.Draw(sheet)
    y = pad
    draw.text((pad, y), "%s: bare at 8x, and against the %s template (magenta: its edge or "
              "lines changed; cyan: outside it)" % (key, template.slot), fill=INK, font=font)
    y += 16
    sheet.alpha_composite(checker(icon, 8), (pad, y))
    sheet.alpha_composite(against_template(icon, rows, template, 8), (pad + 256 + pad, y))
    y += 256 + pad
    draw.text((pad, y), "In the Satchel at 3x: an entry's parchment, its Armor Slot, and the Worn "
              "column under the Portrait", fill=INK, font=font)
    y += 16
    x = pad
    sheet.alpha_composite(entry(icon, SCALE), (x, y))
    x += SIZE * SCALE + 24 + pad
    sheet.alpha_composite(armor_slot(icon, SCALE), (x, y))
    x += SIZE * SCALE + 4 + pad
    column = worn_column(icon, template.slot)
    sheet.alpha_composite(column, (x, y))
    tall = column.height
    x += column.width + pad
    draw.text((x, y), "at 2x and 1x", fill=INK, font=font)
    sheet.alpha_composite(entry(icon, 2), (x, y + 16))
    sheet.alpha_composite(armor_slot(icon, 2), (x + SIZE * 2 + 24 + pad, y + 16))
    sheet.alpha_composite(entry(icon, 1), (x, y + 16 + SIZE * 2 + 16 + pad))
    sheet.alpha_composite(armor_slot(icon, 1), (x + SIZE + 24 + pad, y + 16 + SIZE * 2 + 16 + pad))
    y += tall + pad
    others = []
    if os.path.isdir(ARMOR):
        others = sorted(name[:-4] for name in os.listdir(ARMOR)
                        if name.endswith(".png") and name[:-4] != key)
    shown = {name: Image.open(os.path.join(ARMOR, name + ".png")).convert("RGBA") for name in others}
    heading = "Beside the other Armor Icons, on parchment at 3x: %s" % ", ".join(others)
    if not others:
        shown = {name: image_of_grid(grid) for (name, grid) in liked_examples() if name != key}
        others = list(shown)
        heading = ("No Armor Icons are built yet, so beside the liked examples in "
                   "references/examples.md, on parchment at 3x")
    draw.text((pad, y), heading, fill=INK, font=font)
    y += 16
    x = pad
    for name in others + [key]:
        other = icon if name == key else shown[name]
        tile = entry(other, SCALE)
        if x + tile.width > width:
            x = pad
            y += tile.height + pad
        sheet.alpha_composite(tile, (x, y))
        x += tile.width + pad
    y += SIZE * SCALE + 16 + pad
    sheet = sheet.crop((0, 0, width, y))
    out = arguments.out or os.path.join("tools/sprites/preview", key + "_armor_review.png")
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    sheet.save(out)
    print(out)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    grid = commands.add_parser("grid")
    grid.add_argument("source")
    grid.set_defaults(run=command_grid)
    base = commands.add_parser("base")
    base.add_argument("slot", choices=SLOTS)
    base.add_argument("--ramp", required=True)
    base.add_argument("--key")
    base.add_argument("--matte", action="store_true")
    base.set_defaults(run=command_base)
    check = commands.add_parser("check")
    check.add_argument("grid_file")
    check.add_argument("key")
    check.add_argument("slot", choices=SLOTS)
    check.set_defaults(run=command_check)
    paint = commands.add_parser("set")
    paint.add_argument("grid_file")
    paint.add_argument("key")
    paint.add_argument("paints", nargs="+")
    paint.set_defaults(run=command_set)
    mirror = commands.add_parser("mirror")
    mirror.add_argument("grid_file")
    mirror.add_argument("key", nargs="?")
    mirror.add_argument("--slot", choices=SLOTS, required=True)
    mirror.add_argument("--copy", action="store_true")
    mirror.set_defaults(run=command_mirror)
    compare = commands.add_parser("compare")
    compare.add_argument("sources", nargs="+")
    compare.add_argument("--out", required=True)
    compare.set_defaults(run=command_compare)
    preview = commands.add_parser("preview")
    preview.add_argument("source")
    preview.add_argument("key", nargs="?")
    preview.add_argument("--slot", choices=SLOTS, required=True)
    preview.add_argument("--out")
    preview.set_defaults(run=command_preview)
    arguments = parser.parse_args()
    arguments.run(arguments)


if __name__ == "__main__":
    main()
