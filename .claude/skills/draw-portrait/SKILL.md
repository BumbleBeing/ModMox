---
name: draw-portrait
description: Draws a Villain's Portrait, Pain Portrait and Blink Portrait after a Magic card's art. Use when the user names a card to make a Portrait, sprite or character of, or asks for a Portrait's Blink Portrait.
---

# Draw a Portrait

From one card name to three 32 × 32 sprites: the **Portrait**, the **Pain Portrait** and the **Blink Portrait** (game glossary), drawn by hand after the art of the card's first printing, turned to face the front. `tools/sprites/portraits/keldon_warlord.txt` is a finished example. `$GODOT` below is `~/Desktop/Godot_v4.7.2-stable_linux.x86_64`.

## 1. Fetch the art

```bash
$GODOT --headless --path . -s res://tools/art/fetch_reference.gd -- --card="Keldon Warlord"
```

It saves the first printing's art crop (A227) to `tools/sprites/reference/<key>.jpg` and prints the key and the two credit lines for the grid's header. A card it cannot fetch (not found, or double-faced, which is not handled yet) goes back to the user with the reason. Done when the art is on disk.

## 2. Study the figure

Read the art, and crop and enlarge the figure into the scratchpad to see its details. Draw the most prominent figure. When the art has no clear figure, or several of equal weight, ask the user which to draw before going on. List what makes the character recognizable, silhouette first: headgear, the face or what covers it, shoulders and costume, the colors of each. Where the art hides the face or turns it away, invent a front view that fits the costume. Done when every feature on the list has a place on the 32 × 32 grid.

## 3. Draw the Portrait

Write `tools/sprites/portraits/<key>.txt`: a one-line description and the credit lines in `;` comments, `@ size 32`, then `= <key>` and its 32 rows of 32. Each character is a color of `tools/sprites/modmox.gpl` by its place in `KEY` in `tools/sprites/build_sprites.lua`, and `.` is transparent. The look matches the placeholders in `placeholders.txt`:

- Front-facing, from the chest to the top of the head, with horns, hats and crowns inside the top edge.
- Shoulders cut by the bottom edge; a non-humanoid shows its whole head and some of its body, shoulders optional.
- A one-pixel outline in Neutral 2 (`1`), the frame's edge columns included where the body meets them; a transparent ground.
- Light from the upper left: the right side one step darker.

Draw it pixel by pixel; a shrunk copy of the art serves only to pick colors. A symmetric figure drafts well as a left half mirrored, with its asymmetric pieces drawn over it afterwards.

## 4. Draw the Pain Portrait

Add `= <key>_pain`: the same character the moment after being hurt. The body stays where it is; the head is knocked one pixel aside, its eyes squeezed shut (`>` `<`) and its teeth gritted, or a non-humanoid's jaw clenched. It shows only the wince itself, so the game is free to add a flash or a shake later.

## 5. Draw the Blink Portrait

Add `= <key>_blink`: the Portrait with its eyes closed and nothing else changed, so that swapping the two reads as a blink, never a twitch. Each open eye becomes a shut lid: its pixels take the skin's or fur's color round it, with a one-pixel line where the lids meet, a step darker than the skin's shade. Eyes that are only glints, in a helm or under a hood, go dark. Scrunch the brows or cheeks only where a plain line does not read as shut. Done when a diff of the two grids shows only the eyes changed, and the scrunch where there is one.

A Portrait drawn before Blink Portraits existed gets one with this step and the two after it, once its art is in `tools/sprites/reference/` (step 1 fetches it if not). When its `.aseprite` file was touched up by hand, start from its PNG, not from its grid rows, and sync those rows to the PNG.

## 6. Build and import

```bash
ASEPRITE=~/Projects/aseprite/build/bin/aseprite tools/sprites/build.sh tools/sprites/portraits/<key>.txt ui/sprites/portraits
$GODOT --headless --path . --import
```

Then set `mipmaps/generate=false` in every new `.import` file in `ui/sprites/portraits/` (pixel art imports without mipmaps) and import again. Redrawing a built sprite from its grid takes `--force=` with its name (`<key>`, `<key>_pain`, `<key>_blink`), which replaces its `.aseprite` file; once the user has touched a sprite up in Aseprite, that file is the truth, so ask before forcing.

## 7. Review

```bash
$GODOT --headless --path . -s res://tools/sprites/review_portrait.gd -- --key=<key>
```

It draws `tools/sprites/preview/<key>_review.png`: the art, then the three sprites at 6× (as the player's panel shows them), 2× and 1×, on the panel's color. Read it yourself and check each feature from step 2 against the art. Revise until it holds up. Then send the sheet to the user and revise until they sign off on all three sprites.
