"""Draws a hybrid mana symbol's pip, such as {B/R}, from the two plain pips in
assets/card_frames/pips/ (CardConjurer's): the circle split on the diagonal from top right to
bottom left with no line between, the first color's half and glyph at the top left, the second's at the bottom
right, as printed hybrid symbols are (engine ADR 0077).

    python3 -I tools/art/hybrid_pip.py b r    writes assets/card_frames/pips/br.svg
"""

import pathlib
import re
import sys

PIPS = pathlib.Path(__file__).resolve().parents[2] / "assets" / "card_frames" / "pips"
SIZE = 600
GLYPH_SCALE = 0.5
# Where each half's glyph is centered: a third of the way along the diagonal from each end.
CENTERS = {"first": (192, 192), "second": (408, 408)}


def parts_of(letter: str) -> tuple[str, str]:
    """The circle's fill color and the glyph's markup of the pip named [letter]."""
    svg = (PIPS / f"{letter}.svg").read_text()
    fill = re.search(r'<circle[^>]*fill="([^"]+)"', svg).group(1)
    glyph = re.sub(r"^.*?<circle[^>]*/>", "", svg, flags=re.S)
    glyph = re.sub(r"</svg>\s*$", "", glyph)
    return fill, glyph


def glyph_at(glyph: str, center: tuple[int, int]) -> str:
    offset = SIZE / 2 * GLYPH_SCALE
    return '<g transform="translate(%g %g) scale(%g)">%s</g>' % (
        center[0] - offset, center[1] - offset, GLYPH_SCALE, glyph)


def hybrid_svg(first: str, second: str) -> str:
    first_fill, first_glyph = parts_of(first)
    second_fill, second_glyph = parts_of(second)
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" version="1.1">'
        f'<defs><clipPath id="disc"><circle cx="300" cy="300" r="300"/></clipPath></defs>'
        f'<g clip-path="url(#disc)">'
        f'<path d="M0 0H{SIZE}L0 {SIZE}Z" fill="{first_fill}"/>'
        f'<path d="M{SIZE} 0V{SIZE}H0Z" fill="{second_fill}"/>'
        f'</g>'
        f'{glyph_at(first_glyph, CENTERS["first"])}{glyph_at(second_glyph, CENTERS["second"])}'
        f'</svg>\n')


def main() -> None:
    first, second = sys.argv[1].lower(), sys.argv[2].lower()
    out = PIPS / f"{first}{second}.svg"
    out.write_text(hybrid_svg(first, second))
    print(out)


if __name__ == "__main__":
    main()
