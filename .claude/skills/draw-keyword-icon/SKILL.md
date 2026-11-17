---
name: draw-keyword-icon
description: Draws a 16 × 16 Keyword Icon for a Keyword Chip in the style of the existing ones, from a keyword name and a description of the picture. Use when the user asks for a keyword icon, chip icon or keyword sprite.
---

# Draw a Keyword Icon

From a keyword and a description of its picture to one 16 × 16 sprite in `ui/sprites/keywords/`, drawn by hand in the style of the icons already there. `$GODOT` below is `~/Desktop/Godot_v4.7.2-stable_linux.x86_64`.

## 1. Take the inputs

The **key** is the keyword in snake_case (`first_strike`, `lifelink`): the icon's file name, and the name `KeywordChips.chips_for` and `Reminders.TEXTS` know it by. The **description** says what the picture shows ("a drop of blood inside a heart"). When either is missing, ask for it. When `ui/sprites/keywords/<key>.png` already exists, ask whether to replace it before going on. Done when both are known.

## 2. Study the style

The built PNGs are the truth, not `tools/sprites/keyword_icons.txt`: several were redrawn by hand in Aseprite and no longer match their grid. Read the contact sheet `tools/sprites/preview/keyword_icons.png`, then dump every built icon as a grid:

```bash
python3 -I -c "
import sys, glob, os
from PIL import Image
for path in sorted(glob.glob('ui/sprites/keywords/*.png')):
    image = Image.open(path).convert('RGBA'); print('=', os.path.basename(path)[:-4])
    for y in range(16):
        print(''.join('.' if image.getpixel((x, y))[3] == 0 else {(255, 255, 255): '#', (154, 163, 181): '+'}.get(image.getpixel((x, y))[:3], '?') for x in range(16)))
"
```

What they share, which the new icon keeps:

- **Two colors only**: white (`#`, Neutral 8) and one gray (`+`, Neutral 5), on a transparent ground. `test_keyword_icons.gd` fails any other color.
- **A 12 × 12 drawing area**: the outer two rows and columns stay empty, since the chip's outline and rounded corners live there. Most icons fill the area edge to edge.
- **One bold silhouette** in white, read at 16 px on a dark chip: strokes two pixels wide, no outline, no detail finer than one pixel of gray.
- **Gray as shade**, with light from the upper left: on the lower-right edge of a form, or the darker face of a two-tone shape (`protection`, `indestructible`). Gray never carries the shape alone.
- **A symbol, not a scene**: one object or creature part (a wing, a sword, a paw, a skull), turned to its most recognizable view, often on the diagonal for motion.

Done when every point above is checked against the dump and anything new the dump shows is noted too.

## 3. Draft the icon

Plan the silhouette first: what the description shows, reduced to the one shape that reads at 16 px, and how it fills the 12 × 12 area. When the description is too busy for that, propose what to drop before drawing. Then append to `tools/sprites/keyword_icons.txt`:

```
= <key>
<16 rows of 16 characters: . # +>
```

Draw it pixel by pixel. A symmetric shape drafts well as a left half mirrored. Done when the grid has 16 rows of 16 and passes every point in step 2.

## 4. Build and import

```bash
ASEPRITE=~/Projects/aseprite/build/bin/aseprite tools/sprites/build.sh
$GODOT --headless --path . --import
```

The script builds only icons without an `.aseprite` file, so the hand-edited ones are kept. Then set `mipmaps/generate=false` in `ui/sprites/keywords/<key>.png.import` (pixel art imports without mipmaps) and import again. Redrawing the new icon from its grid takes `--force=<key>`; once the user has touched it up in Aseprite, that file is the truth, so ask before forcing. Done when the PNG and its import exist.

## 5. Review

The build redraws `tools/sprites/preview/keyword_icons.png`: every icon on a chip at 1×, 2× and 4×. Read it yourself: at 1× the new icon must read as what the description says, and it must sit beside the others at the same weight. Revise the grid and rebuild with `--force=<key>` until it holds up. Then send the sheet to the user and revise until they sign off.

## 6. Hook it up

A keyword shows its icon once `KeywordChips.chips_for` (`ui/cards/keyword_chips.gd`) gives its chip the key, and `test_reminders.gd` fails for any icon file without a sentence in `Reminders.TEXTS` (`ui/cards/reminders.gd`).

- **The keyword is on chips already** (its key is in `chips_for`): add the key to `KEYWORDS` in `tests/ui/cards/test_keyword_icons.gd`, in chip order.
- **It is not**: the keyword itself is not in the game yet, and adding it is `/add-card`'s work (its step 4 proposes the primitive, its chip and its Reminder). Tell the user the icon is ready for it, and that `test_reminders.gd` fails until that sentence lands.

Then run the icon tests:

```bash
GODOT=$GODOT tools/test.sh -gselect=test_keyword_icons
GODOT=$GODOT tools/test.sh -gselect=test_reminders
```

Done when both pass, or the only failure is the missing Reminder of a keyword not yet in the game, which the user knows about.
