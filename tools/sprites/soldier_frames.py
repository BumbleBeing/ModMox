#!/usr/bin/env python3
"""Drafts every soldier frame of tools/sprites/menu_sprites.txt from its neutral frame.

    python3 tools/sprites/soldier_frames.py
    ASEPRITE=... tools/sprites/build.sh tools/sprites/menu_sprites.txt ui/sprites/menu --force

It reads `soldier_idle_0` from the grid, takes it apart into head, body, spear, shield and
hand, and writes the grid again with every frame put back together from those parts: a
face, a part moved a pixel or two, a body drawn again, marks beside the head. Change the
neutral frame's rows in the grid, or a face or a frame here, and run both commands.
"""
import os

PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "menu_sprites.txt")
EMPTY = "."
SIZE = 32


def blank():
    return [[EMPTY] * SIZE for _ in range(SIZE)]


def put(onto, layer, dx=0, dy=0):
    for y in range(SIZE):
        for x in range(SIZE):
            tone = layer[y][x]
            if tone != EMPTY and 0 <= y + dy < SIZE and 0 <= x + dx < SIZE:
                onto[y + dy][x + dx] = tone


def take(layer, columns, rows):
    taken = blank()
    for y in rows:
        for x in columns:
            taken[y][x] = layer[y][x]
            layer[y][x] = EMPTY
    return taken


def stamp(onto, rows, x, y):
    for j, row in enumerate(rows):
        for i, tone in enumerate(row):
            if tone != EMPTY and 0 <= y + j < SIZE and 0 <= x + i < SIZE:
                onto[y + j][x + i] = tone


def recolor(rows, tones):
    return ["".join(tones.get(tone, tone) for tone in row) for row in rows]


lines = open(PATH).read().split("\n")
start = lines.index("= soldier_idle_0") + 1
base = [list(row) for row in lines[start:start + SIZE]]
header = lines[:start - 1]

body = [row[:] for row in base]
spear = blank()
for y in range(0, 7):
    for x in range(3, 8):
        spear[y][x] = body[y][x]
for y in range(7, 30):
    spear[y][4:7] = list("0m0")
spear[30][4:7] = list("000")
for y in range(SIZE):
    for x in range(3, 7):
        body[y][x] = EMPTY
for y in range(7):
    body[y][7] = EMPTY
shield = take(body, range(21, 29), range(18, 28))
head = take(body, range(8, 24), range(0, 16))

# A face is the eight columns and six rows inside the helmet, from the brows to the chin.
FACES = {
    "neutral": ["skksskkr", "s0#ss0#r", "s00ss00r", "dssssssd", "s0####0s", "rs0000sr"],
    "blink": ["skksskkr", "sssssssr", "s00ss00r", "dssssssd", "s0####0s", "rs0000sr"],
    "left": ["skksskkr", "s0#ss0#r", "s0#ss0#r", "dssssssd", "sss00sss", "rssssssr"],
    "right": ["skksskkr", "s#0ss#0r", "s#0ss#0r", "dssssssd", "sss00sss", "rssssssr"],
    "sleepy": ["sssssssr", "skksskkr", "s00ss00r", "dssssssd", "ssssssss", "rss00ssr"],
    "yawn": ["skksskkr", "s00ss00r", "sssssssr", "dss00ssd", "ss0bc0ss", "rss00ssr"],
    "asleep": ["sssssssr", "sssssssr", "s00ss00r", "dssssssd", "sss00sss", "rssssssr"],
    "startled": ["skksskkr", "s##ss##r", "s#0ss0#r", "dssssssd", "sss00sss", "rss00ssr"],
    "cheer": ["sssssssr", "s0ssss0r", "0s0ss0s0", "dssssssd", "s0####0s", "rs0bb0sr"],
    "angry": ["kksssskk", "s0kssk0r", "s00ss00r", "cssssssc", "ss0000ss", "rs0##0sr"],
    "roar": ["kksssskk", "s0kssk0r", "s00ss00r", "cssssssc", "s0####0s", "r0bbbb0r"],
    "vampire": ["skksskkr", "s!#ss!#r", "sb!ssb!r", "sssssssr", "s0####0s", "rs#00#sr"],
    "hiss": ["skksskkr", "s!#ss!#r", "sb!ssb!r", "sssssssr", "s0#00#0s", "rs#bb#sr"],
    "sick": ["sssssssr", "skksskkr", "s00ss00r", "dssssssd", "s0s0s0ss", "rs0s0s0r"],
    "queasy": ["sssssssr", "skksskkr", "s00ss00r", "dssssssd", "ss0s0s0s", "r0s0s0sr"],
    "sly": ["kksssskk", "s#0ss#0r", "s00ss00r", "dssssssd", "s0ssss0s", "rs0000sr"],
    "sly_left": ["kksssskk", "s0#ss0#r", "s00ss00r", "dssssssd", "s0ssss0s", "rs0000sr"],
    "alert_left": ["skksskkr", "s0#ss0#r", "s0#ss0#r", "dssssssd", "ss0000ss", "rssssssr"],
    "alert_right": ["skksskkr", "s#0ss#0r", "s#0ss#0r", "dssssssd", "ss0000ss", "rssssssr"],
    "eager": ["skksskkr", "s00ss00r", "s00ss00r", "dssssssd", "s0####0s", "rs0bb0sr"],
    "pant": ["skksskkr", "s00ss00r", "s00ss00r", "dssssssd", "ss0000ss", "rs0bb0sr"],
    "focus": ["skksskkr", "s00ss00r", "s00ss00r", "dssssssd", "ss0000ss", "rssssssr"],
    "fierce": ["kksssskk", "s0kssk0r", "s00ss00r", "cssssssc", "s0####0s", "rs0000sr"],
    "snort": ["kksssskk", "s0kssk0r", "s00ss00r", "cssssssc", "s000000s", "rs0##0sr"],
    "serene": ["skksskkr", "s00ss00r", "s00ss00r", "dssssssd", "s0ssss0s", "rs0000sr"],
    "goblin": ["kksssskk", "s0$ss$0r", "s$$ss$$r", "ssssssss", "00000000", "r#0#0#0r"],
    "cackle": ["kksssskk", "s0$ss$0r", "s$$ss$$r", "ssssssss", "0#0#0#00", "r0bbbb0r"],
}

PALE = {"s": "t", "r": "s", "d": "t"}
GREEN = {"s": "D", "r": "C", "d": "C"}
VENOM = {"6": "J", "5": "I", "3": "H"}
DARK = {"R": "2", "S": "3", "Q": "1", "P": "1"}

# The body from the shoulders to the belt, swollen: wide pauldrons, a bare arm three rows
# thick and a bare chest with a line under it.
BUFF = {
    15: ".......000............000.......",
    16: ".......065+0000rr00005+30.......",
    17: ".......05++3sttssttr5++30.......",
    18: ".......tsssrsttqqttr0...........",
    19: ".......ssssrsqqrrqqr0...........",
    20: ".......rrrqrsssqsssq0...........",
    21: ".......0000rssqsqssq0...........",
}
# A cape's collar standing up either side of the chin.
COLLAR = [
    ([".0", "0b", "0b", "01b", "01b", "011b"], 7, 11),
    (["..0.", "..b0", "..b0", ".b10", ".b10", "b110"], 21, 11),
]
WING = [".....00.", "....0#60", "...0##60", "..0###60", ".0####60", "0####660",
        "0###6600", "0#6660..", "06600...", "000....."]
HEART = [".!.!.", "!!!!!", "!!!!!", ".!!!.", "..!.."]
BUBBLE = ["I%", "%I"]
Z3 = ["666", ".6.", "666"]
Z4 = ["6666", "..6.", ".6..", "6666"]
BANG = ["$$", "$$", "$$", "$$", "..", "$$"]


# The right arm as the left one mirrored, free of the shield, to hold a second spear.
TWIN_ARM = ["5+000", "5+5+3", "+5332", ".0000"]
# A tower shield over the whole body, its top just under the eyes.
TOWER = [
    ".0000000000.",
    "055555555550",
    "05ddcccccb50",
    "05dcc$$ccb50",
    "05dcc$$ccb50",
    "05d$$$$$$b50",
    "05c$$$$$$b50",
    "05ccc$$cbb50",
    "05ccc$$cbb50",
    "05ccc$$cbb50",
    "05cccccbbb50",
    ".05cccbbb50.",
    "..055bbb50..",
    "...005550...",
    ".....000....",
]
# The legs, rows 25 to 30 from column 10, with one foot lifted two rows.
LEFT_UP = {25: ".0lml03+30.", 26: "0mmll03+30.", 27: "0mlll0lml0.", 28: "000000llmm0",
           29: ".....0lllm0", 30: ".....000000"}
RIGHT_UP = {25: ".03+30lml0.", 26: ".03+30llmm0", 27: ".0lml0lllm0", 28: "0mmll000000",
            29: "0mlll0.....", 30: "000000....."}
GOLD = {"#": "y", "6": "y", "5": "x", "+": "x", "3": "w", "2": "v", "s": "x", "r": "w",
        "k": "u", "d": "w", "c": "v", "b": "u", "!": "w", "R": "w", "S": "x", "Q": "v",
        "P": "u", "l": "v", "m": "w", "$": "y", "q": "v", "t": "y"}
WIDOW = {"R": "V", "S": "W", "Q": "U", "P": "U"}
HOURGLASS = ["!!!!", ".!!.", "!!!!"]
EYE_LEFT = ["..0000..", ".0&&##0.", "0&00###0", ".0&&##0.", "..0000.."]
EYE_RIGHT = ["..0000..", ".0##&&0.", "0###00&0", ".0##&&0.", "..0000.."]
TWINKLE = [".#.", "#$#", ".#."]
SPARKLE = ["..#..", "..#..", "##$##", "..#..", "..#.."]
BOLT = ["..$$", ".$$.", "$$$$", ".$$.", "$$.."]
SWEAT = [".&", "&T", "&&"]
DUST = [".on.", "onno"]
SLASH = ["#...", ".#..", "..#.", "...#"]
STREAK = ["6", "6", ".", "6"]
# Bull horns either side of the helmet's top, under the plume.
HORN = [".0", "0o0", "0o0", "0no0", ".0nn0", "..000"]
GHOST = {"c": "T", "d": "#", "b": "S", "$": "&"}
GOBLIN = {"s": "I", "r": "H", "d": "H", "k": "F"}
RAGS = {"R": "g", "S": "h", "Q": "f", "P": "f"}
RUST = {"6": "i", "5": "h", "3": "g"}
# A goblin's long ear out of the right of the helmet; mirrored for the left.
EAR = ["....00", "...0I0", "..0IH0", ".0IH0.", "0IH0..", "0H0...", "00...."]
WISP = [".*.", "**.", "*W*", ".W."]
WISP_SMALL = [".*", "*W", "W."]


def spider(is_up):
    """Three jointed legs either side, behind the body: knees up, or knees down."""
    lift = 0 if is_up else 2
    legs = [
        [(21, 14), (25, 5 + lift), (28, 10 + lift)],
        [(21, 17), (29, 11 + lift), (31, 16 + lift)],
        [(21, 20), (30, 18 + lift), (31, 24)],
    ]
    layer = blank()
    for points in legs:
        for side in (points, [(31 - x, y) for x, y in points]):
            put(layer, drawn([(x, y + 1) for x, y in side[:2]]))
            put(layer, drawn(side[:2], "3"))
            put(layer, drawn(side[1:]))
    return (["".join(row) for row in layer], 0, 0)

def wings(is_up):
    rows = WING if is_up else WING[::-1]
    top = 7 if is_up else 13
    return [(rows, 23, top), ([row[::-1] for row in rows], 1, top)]


def frame(face="neutral", head_dx=0, head_dy=0, bob=0, spear_dy=0, shield_dy=0,
          marks=(), behind=(), torso=None, cloth=None, skin=None, spear_tones=None, hand=None,
          legs=None, shield_rows=None, shield_tones=None, twin=None, whole=None, aura=(), shake=0):
    skin = skin or {}
    shape = [row[:] for row in body]
    for y, row in (torso or {}).items():
        shape[y][7:] = list(row[7:])
    for y, row in (legs or {}).items():
        shape[y][10:21] = list(row)
    shape = [list(recolor(["".join(row)], cloth or {})[0]) for row in shape]
    shape[16][15:17] = list(recolor(["rr"], skin)[0])
    upper = blank()
    for y in range(0, 27 - bob):
        upper[y] = shape[y][:]
    faced = [row[:] for row in head]
    stamp(faced, recolor(FACES[face], skin), 12, 10)
    put(upper, faced, head_dx, head_dy)
    if twin is not None:
        stamp(upper, recolor(TWIN_ARM, skin), 20, 17)
    elif shield_rows is not None:
        stamp(upper, shield_rows, 10, 13 + shield_dy)
    else:
        put(upper, [list(recolor(["".join(row)], shield_tones or {})[0]) for row in shield], 0, shield_dy)

    out = blank()
    for rows, x, y in behind:
        stamp(out, rows, x, y + bob)
    toned = [list(recolor(["".join(row)], spear_tones or {})[0]) for row in spear]
    put(out, toned, 0, spear_dy)
    if twin is not None:
        put(out, toned, 21, twin)
    for y in range(27, 31):
        for x in range(SIZE):
            if shape[y][x] != EMPTY:
                out[y][x] = shape[y][x]
    put(out, upper, 0, bob)
    stamp(out, recolor(hand or ["0sss", "0sss"], skin), 3, 18 + bob + spear_dy)
    if twin is not None:
        stamp(out, recolor(["sss0", "sss0"], skin), 25, 18 + bob + twin)
    if whole:
        out = [list(recolor(["".join(row)], whole)[0]) for row in out]
    for tone in aura:
        out = ringed(out, tone)
    for rows, x, y in marks:
        stamp(out, rows, x, y)
    if shake:
        moved = blank()
        put(moved, out, shake, 0)
        out = moved
    return out


def ringed(rows, tone):
    """[param rows] with every empty pixel beside a drawn one (sides, not corners) in [param tone]."""
    out = [row[:] for row in rows]
    for y in range(SIZE):
        for x in range(SIZE):
            if rows[y][x] == EMPTY and any(
                    0 <= y + j < SIZE and 0 <= x + i < SIZE and rows[y + j][x + i] != EMPTY
                    for i, j in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out[y][x] = tone
    return out


def drawn(points, tone="0"):
    """A layer with lines in [param tone] through [param points], each (x, y), in order."""
    layer = blank()
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        steps = max(abs(x1 - x0), abs(y1 - y0))
        for step in range(steps + 1):
            x = x0 + round((x1 - x0) * step / steps)
            y = y0 + round((y1 - y0) * step / steps)
            layer[y][x] = tone
    return layer


def flash(tone):
    """The neutral frame as one flat tone inside its outline, for a change of looks."""
    return [[tone if cell not in (EMPTY, "0") else cell for cell in row] for row in base]


BUFF_HAND = ["0sss", "0sss", "0rrr"]
frames = [
    ("soldier_idle_0", frame()),
    ("soldier_blink", frame("blink")),
    ("soldier_bob", frame(bob=1)),
    ("soldier_look_left_0", frame("left")),
    ("soldier_look_left_1", frame("left", head_dx=-1)),
    ("soldier_look_right_0", frame("right")),
    ("soldier_look_right_1", frame("right", head_dx=1)),
    ("soldier_sleepy", frame("sleepy")),
    ("soldier_yawn", frame("yawn")),
    ("soldier_asleep_0", frame("asleep", head_dy=1, marks=[(Z3, 24, 7)])),
    ("soldier_asleep_1", frame("asleep", head_dy=1, bob=1, marks=[(Z3, 25, 5), (Z4, 27, 0)])),
    ("soldier_startled", frame("startled", spear_dy=-1, marks=[(BANG, 25, 3)])),
    ("soldier_cheer_0", frame("cheer", spear_dy=-1, shield_dy=-5)),
    ("soldier_cheer_1", frame("cheer", bob=1, shield_dy=-4)),
    ("soldier_flash_white", flash("#")),
    ("soldier_flash_red", flash("!")),
    ("soldier_flash_green", flash("%")),
    ("soldier_boost_0", frame("angry", bob=1)),
    ("soldier_boost_1", frame("angry", torso=BUFF, hand=BUFF_HAND)),
    ("soldier_boost_2", frame("roar", torso=BUFF, hand=BUFF_HAND, spear_dy=-1, shield_dy=-3)),
    ("soldier_lifelink_0", frame("vampire", skin=PALE, cloth=DARK, behind=COLLAR, marks=[(HEART, 24, 5)])),
    ("soldier_lifelink_1", frame("hiss", skin=PALE, cloth=DARK, behind=COLLAR, marks=[(HEART, 25, 1)])),
    ("soldier_deathtouch_0", frame("sick", skin=GREEN, spear_tones=VENOM, marks=[
        (BUBBLE, 24, 8), (["%"], 27, 4), (["%"], 1, 12), (["I"], 5, 7)])),
    ("soldier_deathtouch_1", frame("queasy", skin=GREEN, spear_tones=VENOM, bob=1, marks=[
        (BUBBLE, 25, 4), (["%"], 27, 1), (BUBBLE, 0, 9), (["%"], 24, 10), (["I"], 5, 9)])),
    ("soldier_flying_0", frame("cheer", behind=wings(True), bob=1)),
    ("soldier_flying_1", frame("neutral", behind=wings(False))),
    ("soldier_flash_gold", flash("$")),
    ("soldier_flash_blue", flash("&")),
    ("soldier_reach_0", frame("sly", cloth=WIDOW, behind=[spider(True)], marks=[(HOURGLASS, 14, 18)])),
    ("soldier_reach_1", frame("sly_left", cloth=WIDOW, behind=[spider(False)], marks=[(HOURGLASS, 14, 18)])),
    ("soldier_vigilance_0", frame("alert_left", spear_dy=-1, shield_dy=-1, marks=[(EYE_LEFT, 24, 2)])),
    ("soldier_vigilance_1", frame("alert_right", spear_dy=-1, shield_dy=-1, marks=[(EYE_RIGHT, 24, 2)])),
    ("soldier_haste_0", frame("eager", legs=LEFT_UP, marks=[(BOLT, 26, 3), (SWEAT, 24, 9)])),
    ("soldier_haste_1", frame("pant", legs=RIGHT_UP, marks=[(BOLT, 0, 9)])),
    ("soldier_defender_0", frame("left", shield_rows=TOWER)),
    ("soldier_defender_1", frame("right", shield_rows=TOWER)),
    ("soldier_defender_2", frame("blink", head_dy=2, shield_rows=TOWER)),
    ("soldier_first_strike_0", frame("focus", bob=1, spear_tones={"6": "#", "5": "6", "3": "5"})),
    ("soldier_first_strike_1", frame("angry", spear_dy=-1, spear_tones={"6": "#", "5": "6", "3": "5"},
                                     marks=[(SPARKLE, 0, 0), (STREAK, 1, 7)])),
    ("soldier_double_strike_0", frame("fierce", twin=0)),
    ("soldier_double_strike_1", frame("fierce", twin=0, spear_dy=-1, marks=[(SLASH, 0, 0)])),
    ("soldier_double_strike_2", frame("fierce", twin=-1, marks=[([row[::-1] for row in SLASH], 28, 0)])),
    ("soldier_trample_0", frame("snort", legs=LEFT_UP, behind=[(HORN, 7, 0), ([r[::-1] for r in HORN], 20, 0)])),
    ("soldier_trample_1", frame("roar", bob=1, behind=[(HORN, 7, 0), ([r[::-1] for r in HORN], 20, 0)],
                                marks=[(DUST, 6, 29), ([r[::-1] for r in DUST], 21, 29)], shake=-1)),
    ("soldier_trample_2", frame("snort", legs=RIGHT_UP, behind=[(HORN, 7, 0), ([r[::-1] for r in HORN], 20, 0)])),
    ("soldier_trample_3", frame("roar", bob=1, behind=[(HORN, 7, 0), ([r[::-1] for r in HORN], 20, 0)],
                                marks=[(DUST, 6, 29), ([r[::-1] for r in DUST], 21, 29)], shake=1)),
    ("soldier_indestructible_0", frame(whole=GOLD, marks=[(SPARKLE, 10, 3)])),
    ("soldier_indestructible_1", frame(whole=GOLD, marks=[(TWINKLE, 25, 21), (TWINKLE, 1, 2)])),
    ("soldier_indestructible_2", frame(whole=GOLD)),
    ("soldier_protection_0", frame("serene", shield_tones=GHOST, aura=("&",))),
    ("soldier_protection_1", frame("serene", shield_tones=GHOST, aura=("T", "&"))),
    ("soldier_flash_violet", flash("*")),
    ("soldier_menace_0", frame("goblin", bob=1, skin=GOBLIN, cloth=RAGS, spear_tones=RUST,
                               behind=[(EAR, 22, 6), ([r[::-1] for r in EAR], 4, 6)],
                               marks=[(WISP, 26, 3), (WISP_SMALL, 0, 12), (WISP_SMALL, 29, 12)])),
    ("soldier_menace_1", frame("cackle", skin=GOBLIN, cloth=RAGS, spear_tones=RUST,
                               behind=[(EAR, 22, 5), ([r[::-1] for r in EAR], 4, 5)],
                               marks=[(WISP, 27, 1), (WISP, 0, 9), (WISP_SMALL, 29, 9)])),
]
assert frames[0][1] == base, "the parts no longer make the neutral frame"

out = header[:]
for name, rows in frames:
    out.append("= " + name)
    out += ["".join(row) for row in rows]
    out.append("")
open(PATH, "w").write("\n".join(out))
print("%d frames written to %s" % (len(frames), PATH))
