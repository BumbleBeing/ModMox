"""Draws assets/card_frames/masks/hybrid_blend.png, the mask a hybrid card's Frame draws its
right color through (engine ADR 0077): clear on the left, opaque on the right, and blending
in a band across the middle, measured from printed hybrid cards in the M15 frame.

    python3 -I tools/art/hybrid_blend_mask.py
"""

import pathlib

from PIL import Image

OUT = pathlib.Path(__file__).resolve().parents[2] / "assets" / "card_frames" / "masks" / "hybrid_blend.png"
WIDTH, HEIGHT = 2010, 2814
# The band, as fractions of the card's width.
BAND_START, BAND_END = 0.44, 0.58


def alpha_at(x: int) -> int:
    t = (x / WIDTH - BAND_START) / (BAND_END - BAND_START)
    t = min(1.0, max(0.0, t))
    return round(255 * t * t * (3 - 2 * t))  # smoothstep, so the band has no hard edges


def main() -> None:
    row = Image.new("L", (WIDTH, 1))
    row.putdata([alpha_at(x) for x in range(WIDTH)])
    mask = Image.new("RGBA", (WIDTH, HEIGHT), (255, 255, 255, 0))
    mask.putalpha(row.resize((WIDTH, HEIGHT)))
    mask.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
