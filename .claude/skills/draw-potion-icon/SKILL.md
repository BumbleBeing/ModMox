---
name: draw-potion-icon
description: 'Draws a 32 × 32 Potion Icon in ui/sprites/potions/, in the style of Big Gulp''s, from the Potion''s name, what it should evoke (a description of its look, or its rules text) and one of the seven empty bottle templates (bottle, cone, gourd, jar, square, teardrop, vial). Use whenever the user asks for a potion sprite, potion icon, potion art or a picture for a Potion, or lists potions as a name, a text and a bracketed shape such as "(Fogbrew: Prevent all damage... [Jar])", even if they don''t say "icon".'
---

# Draw a Potion Icon

From a Potion's name, what it should evoke and a bottle shape to one 32 × 32 sprite, `ui/sprites/potions/<key>.png` with its `.aseprite` file, drawn in the style of Big Gulp's. `PotionArt` finds an icon by the Potion's definition file name, so that name is the key.

The helper `scripts/potion.py` does the mechanical parts. Run it from the repo root as `python3 -I .claude/skills/draw-potion-icon/scripts/potion.py`, called `potion.py` below:

- `potion.py grid <shape | file.png | file.aseprite>` prints a sprite as a 32 × 32 text grid.
- `potion.py fill <shape> --level <row> --ramp <ramp> --key <key>` prints the shape's template with a liquid poured in from that row down, shaded as Big Gulp's is.
- `potion.py check <grid file | png> <key> <shape>` checks a drawing against its template.
- `potion.py preview <grid file | png> [key] --out <png>` draws a review sheet: the icon bare at 8×, on every Rarity's plate as `PotionArt` draws it, large and small, and beside the Potion Icons already made.

The templates are the `.aseprite` files in `tools/sprites/potion_templates/`. They are the truth: several were touched up by hand after `tools/sprites/potion_templates.txt` was written, and `bottle` has no PNG. `potion.py` reads them through Aseprite.

## 1. Take the inputs

- **Name**: the key is its snake_case: lowercase, apostrophes dropped, every other run of characters that aren't letters or digits an underscore ("Dragon's Breath" is `dragons_breath`). When `content/potions/` already holds this Potion under another file name, ask which to use.
- **What it should evoke**: either a look ("a murky swamp brew with an eye floating in it") or what the Potion does, often its rules text ("This potion deals 3 damage to any target"). Either works; for a rules text alone, step 3 offers the user a few ideas before drawing.
- **Shape**: `bottle` (the standard round flask Big Gulp uses), `cone`, `gourd`, `jar`, `square`, `teardrop` or `vial`.

The user may give several at once, each a name, a text and a shape in some kind of brackets: `(Fogbrew: Prevent all damage... [Jar])` or `[Mind Hazy: Target opponent discards a card. (teardrop)]`. The shape is the one word bracketed on its own, in either kind of bracket and any case. Draw them one after another, each with its own review sheet, and show them together at the end.

Ask when any of the three is missing or the shape isn't one of the seven. Ask before replacing an existing `ui/sprites/potions/<key>.png`. The key `bottle` is taken: it is the plain icon of every Potion without one of its own.

## 2. Know the house style

Print the template and Big Gulp side by side and read them:

```bash
potion.py grid <shape>
potion.py grid ui/sprites/potions/big_gulp.png
```

In a grid, `.` is transparent, `~` is the see-through glass lining, and every other character is a color of `tools/sprites/modmox.gpl`:

| Ramp | Darkest → lightest |
| --- | --- |
| neutral | `0 1 2 3 + 5 6 #` (Neutral 1 to 8; `0` is the outline, `#` white) |
| red | `a b c d e` |
| rust | `f g h i j` |
| earth | `k l m n o` |
| flesh | `p q r s t` |
| gold | `u v w x y` |
| olive | `A B C D E` |
| green | `F G H I J` |
| teal | `K L M N O` |
| blue | `P Q R S T` |
| violet | `U V W X Y` |
| rose | `z Z 4 8 9` |
| brights | `!` red, `$` yellow, `%` green, `&` blue, `*` violet |

Nothing else is allowed: `build_sprites.lua` rejects any other character, and the shared palette keeps every sprite in the game of a piece.

What every Potion Icon has:

- **The template's bottle.** A near-black outline (`0`), a one-pixel see-through lining (`~`) inside the glass, clear glass (`.`), a white shine (`#`) down the upper left, a cork in rust (`j i h`) and a neck band in white and light grays (`# 6 +`). The glass is left clear because `PotionArt` draws the icon over a plate in its Rarity's color: gray, silver, gold, sienna or pale green. The plate shows through the glass, and the lining keeps the glass visible on all five. So the glass's outline is the template's: it is what makes the shapes read as the same family.
- **Light from the upper left.** Highlights on the left, shade on the right and at the foot.
- **A liquid shaded the way Big Gulp's is**, the base that step 3's idea builds on. Its surface is one row in the light step across the whole glass; its body is the mid step; a band of the dark step down its right side, three pixels at the widest and narrowing as the wall curves in; its bottom two rows dark; a highlight streak in the light step, one pixel wide and about four rows tall, two pixels in from the left lining, under the glass's shine (where the liquid covers the template's shine, the streak carries the shine on); and two or three single-pixel bubbles of the lightest step, scattered and touching nothing light. The liquid stays inside the lining. Above it the glass stays clear, with its shine.
- **Clean highlights.** The shine and the streak are unbroken one-pixel lines that follow the wall. Highlights scattered about, doubled or smeared look careless, and the user has turned down an icon for it.
- **A pixel of empty canvas all round.** In a window's entry the icon fills its plate edge to edge, so a pixel on the canvas's edge lands on the plate's dark rim.

## 3. Design it

Before drawing, read [references/examples.md](references/examples.md): the icons the user liked and turned down, and why, in their words.

**What the user judges an icon by.** All three at once:

- **It is a magic potion, not a drink.** "Water with two big bubbles" and "a worm in some grape juice" were turned down, though their ideas were sound. Magic shows as light inside the liquid, a glow, a swirl, a color that shifts from top to foot, two brews that won't mix.
- **Its idea plainly fits what it does.** Someone who knows the Potion sees at once why it looks this way. Of a violet wisp for a discard potion: "It isn't clear what a purple tendril has to do with forgetfulness or brain fog."
- **It suggests rather than illustrates.** The idea is something that could really happen inside a bottle, with a touch of whimsy: clouds drifting in a jar for a fog potion, eyes glowing out of a black brew for a demonic one, a fire living in the liquid for a burning one. A face, a creature, a weapon or a symbol drawn in the liquid is too on the nose and makes no sense inside glass; such a picture belongs on a label or a seal, if anywhere.

**The liquid is part of the idea.** Big Gulp's flat body is the plainest potion in the game, a baseline and not a target. A motif over one flat tone reads as "monotone" (the user, of a fire over a flat red liquid). Give the liquid its own life: a gradient from a glowing heart, a swirl of a second tone, two brews coiled round each other, motes of light, a darker murk at the foot. The brights (`! $ % & *`) lend a liquid the glow of magic: the user called a red-and-blue brew in brights "vibrant and interesting", while a muted ramp under a flame read as dull. Let the brights carry the color and the muted steps of the same hue carry the shading.

**Offer ideas first when the look is open.** When the user gave only what the Potion does, they often have a picture in mind that no rules text leads to: for a copying potion one user wanted "a mitotic or yin/yang feel to it with some red/blue coloring". So before drawing, offer two or three ideas, a line each (the colors, the idea, what it hints at), with the one you'd pick first, and let the user choose or describe their own. Offer every Potion's ideas in one message when there are several. Skip this when the user described the look or said to just draw; then pick the strongest and say what you chose.

Then write the plan down in a few lines: the colors, the one idea, where it goes, and the fill level. A 32 × 32 icon has room for one idea, and a window's entry shows it at 2× (64 pixels at 1080p), so pick the strongest and drop the rest.

**The color.** The liquid's color tells potions apart at a glance, so it carries most of the meaning. When the user describes a look, use their colors. When they give a rules text, take the color from what the Potion does, as Magic would:

| What it does | Color | Ideas |
| --- | --- | --- |
| deals damage, burns, hastes, enrages | red, rust, brights `!` and `$` | a fire living in the liquid, glowing from a white-hot heart; embers drifting up |
| prevents damage, protects, gains life, heals | white: blue lightest, neutral lights, gold lightest | clouds drifting in the glass, a soft inner glow, motes of light |
| draws, scries, counters, taps, bounces | blue, teal | a slow swirl with sparkles in it, a tiny storm, a ripple of light |
| discards, mills, confuses, steals thoughts | black and blue: violet, rose, murky grays | a hypnotic two-tone swirl, a bright spark of thought dimming into murk, fog churning inside the liquid |
| searches a library, destroys, drains, sacrifices | black: the `black` ramp, violet and rose darks | eyes glowing out of the dark, a blood-red wax seal |
| copies, clones, doubles | blue, or two contrasting colors | two brews coiled together like yin and yang, a liquid dividing in two like a cell |
| pumps, grows, ramps, fights | green, olive | a seedling sprouting from the surface, roots through the liquid, a green glow |

A Potion that is two things (search, but demonic) may take two ramps: one for the liquid and one for its motif or seal. Look at the icons already in `ui/sprites/potions/` and keep the new one apart from them.

**The one idea, and where it goes.** Places to put it, from the safest outward:

- in the liquid: something floating or glowing (a pair of eyes, motes, a leaf), two layers, a swirl;
- at its surface: flames, froth, a ripple, bubbles breaking;
- in the empty glass above: fog or smoke that fills it, sparks, a glow;
- on the bottle: a cork recolored, capped in wax or tied with string, a small label across the belly;
- outside the glass: smoke curling from the neck, a few sparks, a glow. Keep these small, inside the 30 × 30 that leaves the canvas's rim clear, and off the outline, so the silhouette still reads.

Draw an idea at the size it reads, not at the size it really is: a glowing eye is two or three pixels of a bright with a lighter core, a cloud is a short streak with a white top and a gray underside, an ember is one pixel. A motif sits on the liquid as another color, so give it its own light and dark (lit upper left) and an outline only where it would otherwise melt into the liquid.

**When the idea rises out of the liquid** (fire, steam, froth, a sprout), draw the two as one form under one light. The user turned down two fire potions whose flames sat on a flat red liquid like a sticker; they wanted the flame "shaded better and blended smoothly into the liquid".

- One ramp runs through both: lightest where the effect meets the liquid (a fire's white-hot base), cooling and darkening away from it, up into the effect's tips and down to the liquid's foot. No flat surface row runs under it: the effect grows out of the liquid.
- Grade over several rows, never jumping from a light step straight to a dark one. Where the palette has no step between two colors (there is no orange between `!` and `$`), a checkered row of the two bridges them, as the game's own Dither Shading does.
- Give the rising form volume: its core lightest, its edges a step darker, its right side and tips darkest.

**Mind the plates.** Whatever touches clear glass sits on every plate. White and near-white vanish on the silver plate unless they have a gray underside or edge; bright yellow vanishes on the gold plate unless edged in red; pale green does the same on the Power Nine plate.

**The fill level.** The first row of liquid. Roughly, by shape:

| Shape | Its glass | Usual first liquid row |
| --- | --- | --- |
| bottle | round flask, widest about row 18 | 19 |
| cone | Erlenmeyer, widening to a flat foot | 20 |
| gourd | small upper bulb, a waist about row 15, a big lower bulb | 19 |
| jar | wide mouth and a big cork, round belly | 17 |
| square | flat shoulders, straight sides | 17 |
| teardrop | narrow shoulders, belly low and round | 19 |
| vial | tall and only 8 pixels wide; its shine runs low, so the liquid covers it | 14 |

The level can be part of the idea: nearly full for a strong brew, low to leave the glass free for fog or smoke above it.

Done when the user has picked an idea (or the look was given), and the plan names the colors, the one idea, where it goes and the level.

## 4. Draft and review it yourself

Work in the session's scratchpad, or a temporary folder when there is none.

1. Pour the base: `potion.py fill <shape> --level <row> --ramp <ramp> --key <key> > <scratch>/<key>.txt`. The ramp is a name from the table in step 2, or `black` (the outline color for the shade and Violet darkest for the body, since the palette has nothing darker), or five palette characters from darkest to lightest to mix ramps: the fill takes the second for the shade, the third for the body, the fourth for the surface and streak, and the fifth for the bubbles. `--seed` moves the bubbles.
2. Draw the plan onto the grid by hand, pixel by pixel, editing the text file. The base is a start, not a rule: its flat body is the plainest liquid there is, so give it the life the plan calls for; a flaming surface replaces the flat surface row, a fogged glass covers part of its shine, a floating eye moves a bubble. A symmetric motif drafts well as a left half mirrored.
3. Check it: `potion.py check <scratch>/<key>.txt <key> <shape>`. Fix every ERROR. Each WARN is either deliberate (a label in front of the lining) or fixed.
4. Draw the sheet: `potion.py preview <scratch>/<key>.txt <key> --out <scratch>/<key>_review.png`, then Read the image and judge it as a player would see it:
   - At 2× and 1× on a plate, does it read as this Potion, and apart from the others in the bottom row?
   - Does the idea read at 2×, or is it noise? Lone pixels of a color that belong to nothing are noise; so is detail finer than the eye can sort at 1×.
   - Does it look like magic, or like a drink? Does the liquid have life of its own, or is it one flat tone under a motif?
   - Would someone who knows what the Potion does see at once why it looks this way? And does it suggest that, rather than picture it?
   - Is the light the same everywhere, from the upper left? Does anything rising out of the liquid blend into it, or sit on it?
   - On all five plates, especially the silver, the gold and the pale green, does the glass still read, and does nothing on clear glass vanish into the plate?
5. Revise and check again until it holds up. Expect two to four rounds.

Done when `check` prints OK and the sheet holds up on every point above.

## 5. Build and import

Add the grid to `tools/sprites/potion_icons.txt` as `= <key>` and its 32 rows, after the others (replace a block of the same key). That file's `@ size 32` line, at its top, covers every block; a draft file built on its own needs the line too, which `fill` writes. Then:

```bash
ASEPRITE=~/Projects/aseprite/build/bin/aseprite tools/sprites/build.sh tools/sprites/potion_icons.txt ui/sprites/potions
~/Desktop/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --import
```

The build makes an `.aseprite` and a `.png` only for icons without an `.aseprite` file, so the hand-edited ones are kept, and it redraws the contact sheet `tools/sprites/preview/potion_icons.png`. Make sure `ui/sprites/potions/<key>.png.import` has `mipmaps/generate=false` (pixel art imports without mipmaps); if not, set it and import again. Redrawing an icon from its grid takes `--force=<key>`; once the user has touched it up in Aseprite, that file is the truth, so ask before forcing it.

The build also exports every other icon's PNG again from its `.aseprite`. Before building, copy `ui/sprites/potions/` aside. After it, compare the other icons' PNGs with the copies. If one changed, its `.aseprite` and PNG had drifted apart: put the old PNG back and tell the user which file holds what. This happened once: the plain bottle's `.aseprite` had been emptied while its template was being made, and the build turned the default icon into empty glass.

Done when the `.png`, `.aseprite` and `.png.import` exist and `potion.py check ui/sprites/potions/<key>.png <key> <shape>` prints OK.

## 6. Review with the user

Draw the sheet from the built icon, `potion.py preview ui/sprites/potions/<key>.png`, which writes `tools/sprites/preview/<key>_potion_review.png`. Send it to the user (with every other Potion's sheet, when there are several) with one line each on the idea: the color and the motif, and why. Revise, rebuild with `--force=<key>` and send again until they sign off.

## 7. Hook it up

A Potion shows its icon once a definition file of the same name is in `content/potions/`. When there is none, tell the user the icon is waiting for the Potion `content/potions/<key>.tres`. Nothing else reads the file, so there is no test to run for it.
