"""Draws the Menu Backdrop (game glossary, game ADR 0081) into ui/sprites/backgrounds/menu/.

    python3 -I tools/sprites/menu_backdrop.py

Last Light: the top of a castle tower at nightfall, the main menu's window set into its parapet
as its middle merlon, braziers burning on the corner merlons, stars, a crescent moon, the last of
the sun on the hills to the left and village lights in the valley. 320 x 180 pixels, a
Backdrop's size, every gradient blended between neighboring tones with the encounter
Backdrops' 4 x 4 Bayer ramp (ui/backdrops/backdrop.gdshader's ramp()). Signed off in the menu
backdrop prototype.

It plays a ten-second loop at ten frames a second in which only the braziers' flames and the
light they throw on the stone, some of the stars and the arrow slit's light change, each very
little. Every flicker is built from waves repeating a whole number of times over the loop, with
a little noise from the frame, so the last frame steps into the first like any other.

Writes:
- last_light.png: the still, the loop's first frame.
- last_light_flicker.png: each pixel that ever changes, one to a column, in its color on each
  frame, one to a row.
- last_light_flicker.json: where each of those pixels is on the picture, column by column.
- tools/sprites/preview/menu_backdrop.gif: the loop three times over, to watch.

The window's top lies on row TOP, the merlons' tops, where MenuBackdrop.PARAPET says.
"""
import json
import math
import os

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "ui", "sprites", "backgrounds", "menu")
STILL = os.path.join(OUT, "last_light.png")
FLICKER = os.path.join(OUT, "last_light_flicker.png")
FLICKER_PIXELS = os.path.join(OUT, "last_light_flicker.json")
PREVIEW = os.path.join(ROOT, "tools", "sprites", "preview", "menu_backdrop.gif")

W, H = 320, 180
# The rows of the parapet: the merlons' tops, where the window's top lies, and the crenels'
# sills.
TOP = 67
SILL = TOP + 10

BAYER = (0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5)


def bayer(x, y):
    return (BAYER[(y & 3) * 4 + (x & 3)] + 0.5) / 16.0


def rgb(code):
    code = code.lstrip("#")
    return tuple(int(code[i:i + 2], 16) for i in (0, 2, 4))


def tones(*codes):
    return [rgb(code) for code in codes]


def ramp(ts, t, x, y):
    """One of the tones for t in 0..1, dithered between neighbors: the shader's ramp()."""
    t = min(max(t, 0.0), 0.999)
    return ts[min(int(t * (len(ts) - 1) + bayer(x, y)), len(ts) - 1)]


def clamp01(v):
    return min(max(v, 0.0), 1.0)


def fract(v):
    return v - math.floor(v)


def hash2(x, y):
    return fract(math.sin(x * 127.1 + y * 311.7) * 43758.5453)


def noise(x, y):
    ix, iy = math.floor(x), math.floor(y)
    fx, fy = x - ix, y - iy
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    a, b = hash2(ix, iy), hash2(ix + 1, iy)
    c, d = hash2(ix, iy + 1), hash2(ix + 1, iy + 1)
    return (a + (b - a) * fx) + ((c + (d - c) * fx) - (a + (b - a) * fx)) * fy


def fbm(x, y, octaves=4):
    total, weight, norm = 0.0, 0.5, 0.0
    for _ in range(octaves):
        total += weight * noise(x, y)
        norm += weight
        x *= 2.03
        y *= 2.03
        weight *= 0.5
    return total / norm


def ridge(x, base, amp, scale, seed, octaves=3):
    """A hill line's top row at column x."""
    return base - amp * fbm(x / scale, seed, octaves)


class Canvas:
    def __init__(self, fill=(0, 0, 0)):
        self.px = [[fill] * W for _ in range(H)]
        # When a set, every pixel put from then on is added to it.
        self.covered = None

    def put(self, x, y, color):
        if 0 <= x < W and 0 <= y < H and color is not None:
            self.px[y][x] = color
            if self.covered is not None:
                self.covered.add((x, y))

    def get(self, x, y):
        return self.px[y][x]


# The tower ----------------------------------------------------------------------------------

def square_part(x, y):
    """Which part of the square tower is at (x, y), or None: its crenels and the window's top
    corners show the sky."""
    if 155 <= y <= 157 and 103 <= x <= 216:
        return "ledge"
    if 158 <= y <= 163 and 107 <= x <= 212:
        k = (x - 107) % 8
        if k in ((0, 1, 2, 3, 4, 5, 6, 7), (0, 1, 2, 3, 4, 5, 6, 7), (1, 2, 3, 4, 5, 6), (2, 3, 4, 5),
                 (2, 3, 4, 5), (3, 4))[y - 158]:
            return "corbel"
        return "slot" if 109 <= x <= 210 else None
    if y >= 164 and 109 <= x <= 210:
        return "shaft"
    if TOP <= y <= 154 and 105 <= x <= 214:
        if y < SILL and 117 <= x <= 202:
            return None
        return "face"
    return None


def square_tower(parts):
    for y in range(TOP, H):
        for x in range(100, 220):
            part = square_part(x, y)
            if part is not None:
                parts[(x, y)] = part


def masonry(x, y, part):
    """Whether (x, y) is a mortar line, and how far its stone's tone is jittered."""
    if part in ("face", "shaft"):
        row = (y - TOP) // 4
        off = 4 * (row % 2) + 1
        col = (x + off) // 8
        return (y - TOP) % 4 == 3 or (x + off) % 8 == 0, (hash2(col, row) - 0.5) * 0.16
    if part == "ledge":
        return (x + 3) % 10 == 0 and y != 155, (hash2((x + 3) // 10, 3.0) - 0.5) * 0.1
    if part == "bartizan":
        row = y // 3
        col = (x + 2 * (row % 2)) // 4
        return y % 3 == 2 or (x + 2 * (row % 2)) % 4 == 0, (hash2(col, row + 40) - 0.5) * 0.14
    if part == "roof":
        return y % 2 == 1 and (x + y) % 3 == 0, (hash2(x // 2, y // 2 + 80) - 0.5) * 0.1
    return False, 0.0


def shade(cv, parts, stone, light, rim_right=(), rim_left=(), top_boost=0.3, slot=None, roof=None):
    """Paints every part: its tone from light(x, y, part), its masonry, a lift where it faces
    the sky above, and rims of light where its side meets the sky."""
    for (x, y), part in parts.items():
        if part == "slot":
            cv.put(x, y, slot)
            continue
        mortar, jitter = masonry(x, y, part)
        t = light(x, y, part) + jitter - (0.2 if mortar else 0.0)
        if (x, y - 1) not in parts:
            t += top_boost
        color = ramp(roof if part == "roof" and roof else stone, t, x, y)
        if rim_right and part != "slot":
            if (x + 1, y) not in parts:
                color = rim_right[0]
            elif len(rim_right) > 1 and (x + 2, y) not in parts and bayer(x, y) < 0.6:
                color = rim_right[1]
        if rim_left and part != "slot":
            if (x - 1, y) not in parts:
                color = rim_left[0]
            elif len(rim_left) > 1 and (x - 2, y) not in parts and bayer(x, y) < 0.6:
                color = rim_left[1]
        cv.put(x, y, color)


# The loop -----------------------------------------------------------------------------------

LOOP_FRAMES = 100
LOOP_FPS = 10
BRAZIERS = (110, 209)
FLAME_INK = {"a": rgb("#a83a2a"), "b": rgb("#e8602c"), "c": rgb("#ffb347"), "d": rgb("#fff3b0")}
# The flame's shapes over its bowl, nine rows of eight: steady, tall, short and leaning. Their
# bottom three rows, in the bowl, are the same in all.
FLAMES = {
    "steady": ["........", "...a....", "...aa...", "..aba...", "..abba..", ".abccba.", ".abccba.",
               "abcddcba", ".bcddcb."],
    "tall": ["...a....", "...aa...", "..aba...", "..abba..", ".abcba..", ".abccba.", ".abccba.",
             "abcddcba", ".bcddcb."],
    "short": ["........", "........", "...a....", "..aba...", "..abba..", ".abccba.", ".abccba.",
              "abcddcba", ".bcddcb."],
    "left": ["........", "..a.....", "..aa....", ".aba....", ".abba...", ".abcba..", ".abccba.",
             "abcddcba", ".bcddcb."],
    "right": ["........", "....a...", "....aa..", "....aba.", "...abba.", "..abcba.", ".abccba.",
              "abcddcba", ".bcddcb."],
}
# A star's tones, dimmest to brightest; the arms of the brightest.
STAR_TONES = (None, rgb("#59587f"), rgb("#b9b4dc"), rgb("#e8e2ff"))
STAR_ARM = rgb("#7d7aa8")
SLIT = (159, 168, 9)
SLIT_TONES = tones("#fff3c0", "#ffe08a", "#f0a04a", "#a85a35")
SLIT_SPILL = rgb("#33263c")
WARM = tones("#1e223d", "#2e2440", "#4c2b3a", "#7a3e36", "#b05a34", "#e08a3a")


def wave(t, cycles, phase):
    """A swing from -1 to 1, cycles times over the loop: seamless at its wrap."""
    return math.sin(2 * math.pi * (cycles * t + phase))


class LastLight:
    def __init__(self):
        self.backdrop = Canvas()
        cv = self.backdrop
        set_at = (42, 136)
        horizon = 136.0
        sky = tones("#07091a", "#0c0f24", "#121630", "#191c3c", "#222349", "#2e2853", "#402c59",
                    "#5a3059", "#7a3552", "#9e4048", "#c4573d", "#e27c36", "#f6a947")

        def sky_t(x, y):
            d = math.hypot((x - set_at[0]) * 0.5, (y - set_at[1]) * 2.0)
            return (y / horizon) ** 1.5 * 0.62 + clamp01(1 - d / 120) * 0.5 - 0.02

        for y in range(H):
            for x in range(W):
                cv.put(x, y, ramp(sky, sky_t(x, y), x, y))
        # Everything drawn from here on hides the stars behind it.
        covered = set()
        cv.covered = covered
        self.stars = []
        for y in range(0, 110):
            for x in range(W):
                h = hash2(x * 1.71, y * 3.37)
                limit = 0.993 + y / 110 * 0.005
                if h > limit and sky_t(x, y) < 0.36:
                    level = 3 if h > 0.9994 else 2 if h > 0.995 else 1
                    twinkles = hash2(x * 0.37, y * 0.91) > 0.55
                    self.stars.append({
                        "x": x, "y": y, "level": level, "twinkles": twinkles,
                        "flares": level == 2 and hash2(x * 0.53, y * 0.31) > 0.5,
                        "cycles": 1 + int(hash2(x * 0.13, y * 0.57) * 3),
                        "phase": hash2(x * 0.71, y * 0.23),
                    })
        moon = (264, 30)
        for y in range(moon[1] - 16, moon[1] + 17):
            for x in range(moon[0] - 16, moon[0] + 17):
                r = math.hypot(x - moon[0], y - moon[1])
                if r <= 8.5 and math.hypot(x - moon[0] - 4, y - moon[1] + 3) > 7.5:
                    cv.put(x, y, rgb("#f3eccd") if r < 7.5 else rgb("#c8bf9c"))
        for y in range(set_at[1] - 6, set_at[1] + 1):
            for x in range(set_at[0] - 7, set_at[0] + 8):
                if math.hypot(x - set_at[0], y - set_at[1] - 1) <= 6.5:
                    cv.put(x, y, rgb("#ffd27a"))

        far = tones("#221e3e", "#2a2448", "#352a52", "#7a3a52", "#b4553f")
        mid = tones("#121630", "#161b38", "#1c2241", "#232a4c")
        near = tones("#0a0c1d", "#0d1024", "#11152c")

        def glow(x, y):
            return clamp01(1 - math.hypot((x - set_at[0]) * 0.6, (y - set_at[1]) * 1.5) / 110)

        for x in range(W):
            top = ridge(x, 138, 8, 36, 2.2)
            for y in range(int(top), H):
                t = 0.3 - (y - top) / 30 + glow(x, y) * 0.3
                if y - top < 1.2:
                    t = 0.45 + glow(x, y) * 0.6
                cv.put(x, y, ramp(far, t, x, y))
        lights = []
        for x in range(W):
            top = ridge(x, 150, 13, 28, 7.7)
            for y in range(int(top), H):
                cv.put(x, y, ramp(mid, 0.55 - (y - top) / 30, x, y))
            village = (40 <= x <= 92) or (232 <= x <= 300)
            if village and hash2(x * 0.7, 3.0) > 0.7:
                lights.append((x, int(top) + 2 + int(hash2(x, 5.0) * 7)))
        for x in range(W):
            tree = max(0.0, 2.5 - abs((x % 6) - 2.5)) * (1 if hash2(x // 6, 4.0) > 0.4 else 0)
            top = ridge(x, 168, 10, 22, 12.1) - tree * 1.4
            for y in range(int(top), H):
                cv.put(x, y, ramp(near, 0.5 - (y - top) / 20, x, y))
        for x, y in lights:
            if cv.get(x, y) in mid:
                cv.put(x, y, rgb("#ffcf6a") if hash2(x, y) > 0.4 else rgb("#d98a3c"))

        stone = tones("#11132a", "#171a33", "#1e223d", "#262b48", "#303654", "#3c4462", "#4b5473",
                      "#5e6888")
        self.parts = {}
        square_tower(self.parts)

        def light(x, y, part):
            if part == "ledge":
                return (0.85, 0.45, 0.15)[y - 155]
            if part == "corbel":
                return 0.12
            if part == "shaft":
                return 0.12 + 0.25 * (x - 109) / 101 - (0.1 if y < 167 else 0)
            return 0.26 + 0.3 * (x - 105) / 109 - 0.12 * (y - TOP) / 90

        shade(cv, self.parts, stone, light, rim_right=(rgb("#8f99c0"), rgb("#5c6690")),
              top_boost=0.3, slot=rgb("#07081a"))
        cv.covered = None
        # The stone each brazier can light: what its tone would be, before the light's reach, and
        # whether it is on the moonlit rim down a merlon's edge (as shade() puts it there).
        self.lit = []
        for cx in BRAZIERS:
            near_stone = []
            for (x, y), part in self.parts.items():
                d = math.hypot(x - cx - 0.5, (y - TOP + 2) * 1.3)
                if d < 24 and part != "slot":
                    mortar, jitter = masonry(x, y, part)
                    lift = 0.25 if (x, y - 1) not in self.parts else 0.0
                    is_rim = (x + 1, y) not in self.parts or ((x + 2, y) not in self.parts and bayer(x, y) < 0.6)
                    near_stone.append((x, y, d, jitter + lift - (0.2 if mortar else 0), is_rim))
            self.lit.append(near_stone)
        self.bowls = {}
        for cx in BRAZIERS:
            for y in range(TOP - 3, TOP):
                for x in range(cx - 3, cx + 5):
                    if y == TOP - 3 or abs(x - cx - 0.5) <= 2.5:
                        self.bowls[(x, y)] = rgb("#3a2a2a") if y == TOP - 3 else rgb("#1a1216")
        # Only the parts of a star that nothing in front of it hides.
        self.visible = lambda x, y: 0 <= x < W and 0 <= y < H and (x, y) not in covered

    def burn(self, brazier, frame):
        """How high brazier's fire burns on frame: 0..1, about 0.5."""
        t = frame / LOOP_FRAMES
        p = [hash2(brazier * 3.7 + 1, j * 1.9 + 2) for j in range(3)]
        return (0.5 + 0.2 * wave(t, 7, p[0]) + 0.12 * wave(t, 13, p[1]) + 0.08 * wave(t, 29, p[2])
                + 0.16 * (hash2(frame * 1.31 + 0.5, brazier * 7.17 + 0.3) - 0.5))

    def star_layer(self, frame):
        t = frame / LOOP_FRAMES
        out = {}
        for star in self.stars:
            level = star["level"]
            if star["twinkles"]:
                # Once a cycle a bright star either dims or flares, by its own choice; a dim or
                # brightest one dims, on half as many cycles, rounded up.
                cycles = star["cycles"] if star["level"] == 2 else (star["cycles"] + 1) // 2
                if wave(t, cycles, star["phase"]) > 0.88:
                    level = 3 if star["flares"] else level - 1
            x, y = star["x"], star["y"]
            if level == 0:
                continue
            if self.visible(x, y):
                out[(x, y)] = STAR_TONES[level]
            if level == 3 and star["level"] == 3:
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    if self.visible(x + dx, y + dy):
                        out[(x + dx, y + dy)] = STAR_ARM
        return out

    def fire_light_layer(self, frame):
        out = {}
        for brazier, near_stone in enumerate(self.lit):
            f = self.burn(brazier, frame)
            for x, y, d, lift, is_rim in near_stone:
                # The moonlit rim takes the fire's light at its steady strength, so that it never
                # flickers between the fire's dark tone and the moon's pale one.
                burn = 0.5 if is_rim else f
                radius = 20 * (0.95 + 0.1 * burn)
                strength = 0.8 * (0.94 + 0.12 * burn)
                reach = 1 - d / radius
                t = reach * strength + lift
                if reach > 0 and t > 0.12:
                    out[(x, y)] = ramp(WARM, t, x, y)
        return out

    def flame_layer(self, frame):
        t = frame / LOOP_FRAMES
        out = {}
        for brazier, cx in enumerate(BRAZIERS):
            f = self.burn(brazier, frame)
            lean = wave(t, 3, hash2(brazier, 11.0)) + 0.5 * wave(t, 11, hash2(brazier, 12.0))
            if f > 0.72:
                pose = "tall"
            elif f < 0.3:
                pose = "short"
            elif lean > 0.8:
                pose = "right"
            elif lean < -0.8:
                pose = "left"
            else:
                pose = "steady"
            # Now and then a pixel of the white core dims.
            dim_core = hash2(frame * 2.17, brazier * 5.3) > 0.75
            for dy, line in enumerate(FLAMES[pose]):
                for dx, ch in enumerate(line):
                    if ch == ".":
                        continue
                    if dim_core and ch == "d" and dy == 7 and dx == 3 + (frame + brazier) % 2:
                        ch = "c"
                    out[(cx - 3 + dx, TOP - 12 + dy)] = FLAME_INK[ch]
        return out

    def slit_layer(self, frame):
        t = frame / LOOP_FRAMES
        q = (0.5 + 0.22 * wave(t, 5, 0.3) + 0.14 * wave(t, 17, 0.7)
             + 0.14 * (hash2(frame * 0.93 + 0.2, 9.0) - 0.5))
        shift = (0.5 - q) * 1.2
        x0, y0, height = SLIT
        out = {}
        for dy in range(height):
            tone = SLIT_TONES[min(max(int(dy / 3 + 1 + shift), 0), len(SLIT_TONES) - 1)]
            out[(x0, y0 + dy)] = tone
            out[(x0 + 1, y0 + dy)] = tone
        # When it burns bright its light spills on the stone either side.
        for dy in range(1, height - 1):
            for x in (x0 - 1, x0 + 2):
                if bayer(x, y0 + dy) < (q - 0.62) * 2.5:
                    out[(x, y0 + dy)] = SLIT_SPILL
        return out

    def layers(self, frame):
        """The changing layers of frame, bottom to top, each a map of its pixels."""
        return [("stars", self.star_layer(frame)), ("fire light", self.fire_light_layer(frame)),
                ("braziers", self.bowls), ("flames", self.flame_layer(frame)),
                ("slit light", self.slit_layer(frame))]

    def frame(self, frame):
        image = Image.new("RGB", (W, H))
        image.putdata([c for row in self.backdrop.px for c in row])
        for _, pixels in self.layers(frame):
            for (x, y), color in pixels.items():
                image.putpixel((x, y), color)
        return image


def changed_pixels(still, frames):
    """Every pixel that differs from the still on some frame, in reading order."""
    first = list(still.getdata())
    changed = set()
    for frame in frames:
        for index, color in enumerate(frame.getdata()):
            if color != first[index]:
                changed.add(index)
    return [(index % W, index // W) for index in sorted(changed)]


def main():
    scene = LastLight()
    frames = [scene.frame(frame) for frame in range(LOOP_FRAMES)]
    still = frames[0]
    os.makedirs(OUT, exist_ok=True)
    still.save(STILL)
    pixels = changed_pixels(still, frames[1:])
    strip = Image.new("RGB", (len(pixels), LOOP_FRAMES))
    for row, frame in enumerate(frames):
        for column, (x, y) in enumerate(pixels):
            strip.putpixel((column, row), frame.getpixel((x, y)))
    strip.save(FLICKER)
    with open(FLICKER_PIXELS, "w") as file:
        json.dump({"pixels": [[x, y] for x, y in pixels]}, file)
        file.write("\n")
    big = [frame.resize((W * 3, H * 3), Image.NEAREST) for frame in frames]
    big[0].save(PREVIEW, save_all=True, append_images=big[1:], duration=1000 // LOOP_FPS, loop=0,
                disposal=1)
    print("drew Last Light: %d frames, %d pixels flicker" % (LOOP_FRAMES, len(pixels)))


if __name__ == "__main__":
    main()
