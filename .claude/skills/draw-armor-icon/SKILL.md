---
name: draw-armor-icon
description: 'Draws a 32 × 32 Armor Icon in ui/sprites/armor/, in the shape of its Armor Slot''s template (helm, cuirass or greaves, in tools/sprites/armor_templates/), from the Armor''s name, a description of its look or what it does, and its Armor Slot. Use whenever the user asks for an armor sprite, armor icon, armor art or a picture for a Helm, Cuirass or Greaves, types /draw-armor-icon, or lists Armor as a name, a text and a bracketed slot such as "(Lionguard Helm: a gold helm with a red crest [Helm])", even if they don''t say "icon".'
---

# Draw an Armor Icon

From an Armor's name, a description and its Armor Slot to one 32 × 32 sprite, `ui/sprites/armor/<key>.png` with its `.aseprite` file, drawn in the shape of that slot's template. An Armor Icon shows on its entry in the Satchel and in its Armor Slot while it is Worn (GLOSSARY.md, "Armor Icon"); an empty Armor Slot shows the template itself, a faint outline under the Hero's Portrait. So every icon of a slot keeps its template's silhouette, and a Worn piece fills the outline that was there.

The helper `scripts/armor.py` does the mechanical parts. Run it from the repo root as `python3 -I .claude/skills/draw-armor-icon/scripts/armor.py`, called `armor.py` below:

- `armor.py grid <slot | file.png | file.aseprite>` prints a sprite as a 32 × 32 text grid; a slot prints its template as a map.
- `armor.py base <slot> --ramp <ramp> --key <key> [--matte]` prints the template filled as one solid form, lit from the upper left, each part and section on its own: a start to draw over.
- `armor.py set <grid file> <key> X,Y=CHARS ...` paints pixels into a drawing in place, by coordinates, so no row is miscounted.
- `armor.py mirror <grid file> [key] --slot <slot> [--copy]` prints a drawing with its left half mirrored onto its right; for the greaves, `--copy` moves the left leg across onto the right one instead, so each keeps its own light.
- `armor.py check <grid file | png> <key> <slot>` checks a drawing against its template.
- `armor.py compare <grid files, file:key or pngs> --out <png>` draws drafts side by side, at 8× and as the Satchel shows them.
- `armor.py preview <grid file | png> [key] --slot <slot> --out <png>` draws a review sheet: the icon bare at 8× and against its template, as the Satchel shows it at 3× (on an entry's parchment, in its Armor Slot, and in the Worn column), at 2× and 1×, and beside the Armor Icons already made (or, while there are none, the liked ones in `references/examples.md`).

The templates are `helm`, `cuirass` and `greaves` in `tools/sprites/armor_templates/`, an `.aseprite` file and a matching `.png` each. The `.aseprite` files are the truth.

## 1. Take the inputs

- **Name**: the key is its snake_case: lowercase, apostrophes dropped, every other run of characters that aren't letters or digits an underscore ("Seer's Helm" is `seers_helm`).
- **Description**: either a look ("a gold helm with a red crest") or what the Armor does, often its Starting Conditions ("You start each encounter with 3 more life"). Either works; for a rules text alone, step 3 offers the user a few ideas before drawing.
- **Armor Slot**: `helm`, `cuirass` or `greaves`. The user may call it the type. Say "Armor Slot" yourself: the glossary avoids "armor type".

The user may give several at once, each a name, a description and a slot in some kind of brackets: `(Lionguard Helm: a gold helm with a red crest [Helm])` or `[Marcher's Greaves: You start each encounter with 2 more life. (greaves)]`. The slot is the one word bracketed on its own, in either kind of bracket and any case. Draw them one after another, each with its own review sheet, and show them together at the end.

Ask when any of the three is missing or the slot isn't one of the three. Ask before replacing an existing `ui/sprites/armor/<key>.png`.

## 2. Know the house style

Print the template and read it:

```bash
armor.py grid <slot>
```

In the map, `0` is the template's edge, `=` its inner lines and `-` the inside to paint. In a drawing's grid, `.` is transparent and every other character is a color of `tools/sprites/modmox.gpl`:

| Ramp | Darkest → lightest |
| --- | --- |
| neutral | `0 1 2 3 + 5 6 #` (Neutral 1 to 8 in that order; `0` is the outline, `#` white; `4` is not among them, it is a rose) |
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

Nothing else is allowed: `build_sprites.lua` rejects any other character, and the shared palette keeps every sprite in the game of a piece. An Armor Icon has no see-through glass (`~`).

What every Armor Icon has:

- **The template's shape.** The piece fills every pixel of its template, and the template's edge stays the near-black outline (`0`). The inner lines stay too, dark: the helm's T-shaped face opening, the line between the cuirass's breastplate and its fauld (the skirt plate below it), and the seam between the greaves' two legs. They are what make every helm, cuirass and greaves read as the same kind of thing, and what lets a Worn piece fill the outline its empty slot showed. The user called a helm whose face opening was reshaped into a skull "awful", for the way "the slots from the template were abandoned completely".
- **Its parts**, by row (`armor.py grid <slot>` shows them):
  - Helm: the dome, rows 2 to 11; the face opening's crossbar, rows 12 and 13, and its stem, rows 14 to 22, with a cheek plate either side; the gorget flaring at the foot, rows 23 to 28.
  - Cuirass: the shoulders, rows 2 to 6, either side of the neck opening; the chest, down to a lower edge that dips from row 21 at the sides to row 23 in the middle; the fauld below it, rows 21 to 29, which reaches up the sides at rows 21 and 22 because that line curves.
  - Greaves, each leg alike: the knee cop, rows 2 to 12, where the legs are widest and touch at the seam; the shin, rows 13 to 22; the ankle, rows 23 to 29. Where the knee cop overhangs the shin, and the shin the ankle, a dark band parts them: the upper part's foot dark, the lower part's top in its shadow (`base` pours it).
  - The templates are symmetric about the line between columns 15 and 16, so an emblem centered on the helm or the cuirass is an even number of pixels wide.
- **Light from the upper left.** Each part lit on its upper left and shaded down its right side and along its foot. A rounded part (a helm's dome, a breastplate's chest, a greave's shin) has a highlight on its upper left that follows its curve. Parts side by side are each lit from their own upper left: the right leg of a pair of greaves is lit on its left too, so a symmetric piece mirrors its shapes but not its light.
- **A solid form.** Every piece is shaded with volume, whatever it is made of: across each part, light on the left, the mid step through the middle, the dark step toward the right and the darkest near its right edge, with one pixel of reflected light (the dark step) right against the edge, so the shade doesn't run into the outline in the dark Armor Slot; its top lit and its foot darkened. That is what `base` pours, and what the user's liked icons have. The user turned down a pair of leather greaves as "too flat" and chose one shaded so it looked "well-shaded and sturdy". Materials differ in their highlights, not in their volume: metal takes a one-pixel highlight of the lightest step and one white (`#`) glint where the light is brightest on each metal part (an inlaid emblem of another metal may have its own); leather, cloth and bone take the same light-to-dark with a softer highlight and no white.
- **Metals that read as metal.** The palette's muted ramps alone read as dull stuff, so each metal has a ramp of its own for `base`:
  - Gold is bright yellow: the `gilded` ramp (`v w x $ y`) has `$` as its lit body and the gold ramp's steps as its shade. The gold ramp alone reads as brass or khaki.
  - Bronze is polished: the `bronze` ramp (`f g h $ y`) lights the rust ramp's darks with bright yellow. The rust ramp alone reads as rust or clay: the user called a rust-ramp bronze "rusty" and wanted it "more metallic".
  - Steel is the neutrals (`steel`); pale, polished steel is `silver` (`2 3 + 5 6`), which the user liked for life gain: "the lighter colored metal matches better with the theme".
  - Bone is `bone` (`m n o 6 t`), poured `--matte`: a pale gray lit body over cream and tan, with a warm sheen in Flesh lightest, as the liked Gravewatch Helm has it. Earth lightest alone is the color of the Satchel's parchment, so a piece lit in it vanishes there.
  - A metal may be lacquered or enameled in a color: the user liked a cuirass's blood-red plate ("I like the color of the metal"). Shade it as metal, in that color's ramp, with its glint.
  - Blackened iron is `black` (`P 1 1 2 3`), poured `--matte`: a Neutral 2 body, a blue-black shade, a lit stripe in Neutrals 3 to 5, as the user's favorite Hornward Helm has it. Draw it truly dark; the user preferred the darker of two because "blackened iron fits the theme of protection from colorful magics". Its lit left edge and reflected right edge keep it in the dark Armor Slot.
  - Gold on pale metal: `$` is as light as Neutral 6, so on silver or white a gold emblem is rimmed in dark gold (`v`, `w`), as the liked sun is.
- **One idea, and the detail that belongs to it.** A piece needs more than its shape and its one idea: the user called a steel cuirass with a gold sun "a little plain", and preferred a helm that "looks more detailed, but in a way that matches the description" (rivets on a brow band, a lit lip on each step of the gorget's flare). Detail is welcome when it belongs to the material and the idea. What isn't is ornament for its own sake and busy shading round a busy motif: the user found trim at the collar, waist and hem "aggressive", and liked a cuirass whose plain shading let its detailed eye stand out.
- **Clean highlights.** A highlight is an unbroken one-pixel line that follows the form. Highlights scattered about, doubled or smeared look careless. A rivet is one light pixel with a dark one under it. A gem or an eye may have its own one-pixel catchlight besides the metal's glint. Texture (ridges on a horn, scales) breaks into the shaded side and leaves the highlight whole.
- **Two grounds.** The Satchel draws the icon with no plate: on an entry's light parchment (`#e9dcbc`) and in an Armor Slot's near-black brown square (`#2c1d12`). The outline carries the piece on the parchment. On the dark square the outline vanishes, so the piece's lit upper-left edge and its lighter steps must carry the silhouette: a piece that is mostly darker than the mid neutrals disappears there. So does anything outside the template drawn in the outline color alone: a spike, a thorn or a horn there is outlined and has its own lit pixel on its upper left.
- **A pixel of empty canvas all round.** All three templates span columns 4 to 27 and start at row 2, leaving columns 1 to 3 and 28 to 30 free on each side and row 1 free above; the helm also has rows 29 and 30 free below its gorget. Nothing is drawn on the canvas's outermost ring.

## 3. Design it

Before designing, read [references/examples.md](references/examples.md): the icons the user liked and turned down, and why, in their words.

**What the piece must do.** All three at once:

- **It reads as its Armor Slot at a glance**, at 3× and at 1×. What stands outside the template is plainly part of the piece. It may be large when it is the idea: the user liked "horns that protrude from the usual bounds of a helm".
- **Its idea plainly fits its name and what it does, and suggests rather than illustrates.** Someone who knows the Armor sees at once why it looks this way, but the piece doesn't spell out its name. The literal object is on the nose: the user found a blood drop on the Bloodbound Cuirass "a bit on the nose", and a plate whose one idea was that drop "boring and on-the-nose", but liked "the way the veins were drawn", red veins running through the iron from the gem. Work the idea into the armor (a vein, a glow, a stain in the metal, a material) rather than setting its emblem on it.
- **It has one idea.** At 32 × 32 there is room for one strong idea in one or two materials, not a catalog of ornaments. Pick the strongest and drop the rest.

**Offer ideas first when the look is open.** When the user gave only what the Armor does, they often have a picture in mind that no rules text leads to. So before drawing, offer two or three ideas, a line each (the materials and colors, the idea, what it hints at), with the one you'd pick first, and let the user choose or describe their own. Offer every Armor's ideas in one message when there are several. Skip this when the user described the look or said to just draw; then pick the strongest and say what you chose.

**The color.** The material and its color tell pieces apart at a glance, so they carry most of the meaning. When the user describes a look, use their colors. When they give a rules text, take the color from what the Armor does, as Magic would. When it does two things, a cost and a benefit, let its name choose which leads; the other may go unshown. The liked Bloodbound Cuirass ("4 less life and an extra free mulligan") showed only the cost, in blackened iron and blood red.

| What it does | Color | Ideas |
| --- | --- | --- |
| more life, protection | white: polished steel, gold trim, light blue | a sun or a lion on the brow or chest, a soft glow, white enamel |
| a better opening hand, a free mulligan, card draw | blue, teal | a sapphire set in the brow, star-like inlay, a calm blue glow in the face opening |
| an Emblem that is theirs for the encounter | the Emblem's color | the Emblem's own motif worked into the piece |
| power at a cost: less life, a smaller hand | black, red: blackened iron, rose and red darks | spikes, a blood-red gem, eyes glowing in the dark face opening |
| strength, growth, the wilds | green, earth, olive | leather and bark, leaves along a trim, horns or antlers |

**The material carries the theme too, and has to make sense with the motif.** Pale metal for life gain, blackened iron for protection from magic. A motif and the material it sits on should belong together: the user turned down blue-and-white lightning on brown bronze ("the white and blue on brown clashes in a way that doesn't make much sense") and wanted the bronze "more metallic and less rusty, as electricity hates rust". When the user names a material, draw it at its most fitting: polished and bright, its color leaning toward the motif's.

Look at the icons already in `ui/sprites/armor/` (or, while there are none, the examples) and keep the new one apart from them.

**Where the idea goes.** By slot:

- **Helm**: a band across the brow above the face opening; a ridge or crest down the middle of the dome; the cheek plates either side of the opening's stem; the face opening itself (it stays dark, but eyes or a glow may show in it); the gorget's flare at the foot. Outside the template: horns, wings or spikes, in the five free columns each side of the dome and cheeks (1 to 5 and 26 to 30; three beside the gorget). A horn or a wing that is the idea may stand in front of the helm's side edge, as the liked Hornward Helm's horns do. Above it there is only row 1, so a crest or plume is set on the dome itself, covering the top of its edge and rising at most into row 1; `check` then warns about the covered edge, which is deliberate.
- **Cuirass**: the chest (an emblem, a gem, a sunburst, sculpted muscle); trim along the neck opening, the armholes or the curved lower edge, sparingly; the fauld as a second material or color; the broad shoulders. Outside: a spike or a tuft of fur at a shoulder.
- **Greaves**: the knee cops; a ridge down each shin; bands, straps or vines round the shin and ankle; a flare of trim at the ankle. The two legs match. Outside: a spike at each knee.

**Hair, fur and feathers are worked into the armor.** A horsehair crest, a mane or a plume is set on the piece as one groomed, shaded form, its strands drawn as highlights within it: the user liked a crest of red horsehair standing along the helm's ridge, and turned down one that spilled over the crown and down both sides as "way too much like hair to make sense on a helm".

**Living effects fall where they would.** Lightning, sparks, flames, smoke and veins are not ornaments to mirror or to box in: they spread unevenly over the whole piece, as the real thing does, forking off in different directions, some running past the edge, none of them tidy. Lightning especially: the user turned down two pairs of greaves for it, one whose bolts were "far too symmetrical and contained to make sense as electricity", one whose lightning "isn't dispersed randomly enough and was concentrated down to the bottom right". So don't give each leg one bolt in a strip, and don't let the effect gather in one corner; let it branch across both legs and the gap between them, unevenly. The two legs match as armor; what plays over them needn't. An effect outside the template (a spark, a wisp of glow) needs no outline, and `check`'s warning about it is deliberate.

**Whatever wraps the piece carries its own detail.** A vine, a strap or a chain round a leg is drawn as it would wrap (steep where it comes round the edge, flatter across the front) and is more than a plain band: thorns as pale-tipped points along a vine, a buckle on a strap. The user found plain brown bands "a bit plain", and liked a bramble whose thorns made it "more interesting".

**Keep the armor empty and ordinary, but for a rare reason.** Eyes glowing in a helm's opening, a mouth, anything that makes the piece look inhabited or strange, is an aberration: the user liked the Gravewatch Helm's green eyes ("I appreciate the creativity of the eyes being added") but added that "aberrations like this should be rare". Draw one only when the description asks for it.

Draw an idea at the size it reads, not the size it really is: a gem is two or three pixels of a bright with one lighter pixel, a rivet one pixel, a thorn one dark pixel with a pale tip, an emblem five to seven pixels across with its own light and dark. Give each ornament its own light and dark (lit upper left) and an outline only where it would otherwise melt into the piece. Don't draw a wearer: no face or hair in the helm's opening, no legs in the greaves. An eye or a face as an emblem worked into the metal is fine. The pieces are empty armor, shown as the Hero would hold them.

Then write the plan down in a few lines: the materials and their ramps, the one idea, and where it goes.

Done when the user has picked an idea (or the look was given), and the plan names the materials, the one idea and where it goes.

## 4. Draft and review it yourself

Work in a folder of this Armor's own, `<scratchpad>/<key>/` (the session's scratchpad, or a temporary folder when there is none), with a suffix when that folder is already there: other drawings may be going on beside this one, and a shared file name gets overwritten.

Below, `<draft>` is that folder.

1. Pour the base: `armor.py base <slot> --ramp <ramp> --key <key> > <draft>/<key>.txt`. The ramp is a name from the table in step 2, a material's own (`steel`, `silver`, `gilded`, `bronze`, `black`, `bone`), or five palette characters from darkest to lightest to mix ramps; all five are used, from the darkest near each part's right edge to the lightest in its highlight. Add `--matte` for leather, cloth, bone or blackened iron, which leaves out the white glint. For leather, a hue's own ramp works (`earth` or `rust` for brown, `green`, `0FGHI` for a darker green).
2. Draw the plan onto the grid by hand, pixel by pixel: `armor.py set <draft>/<key>.txt <key> 12,9=$$y 14,10=!` writes each run of characters from its column on its row (both counted from 0), or edit the text file. The base is a start, not a rule: repaint a part in a second material, add trim, an emblem, a gem, and reshape its highlights to the form, but keep its volume. A symmetric piece drafts well as a left half: draw it, then `armor.py mirror <draft>/<key>.txt --slot <slot> > <draft>/<key>_2.txt` and relight the right half from its own upper left, so the halves differ in light, not in shape. For the greaves, `--copy` moves the left leg onto the right with its light as it is. Keep each round as its own file and line rounds or variants up with `armor.py compare <files> --out <draft>/compare.png`.
3. Check it: `armor.py check <draft>/<key>.txt <key> <slot>`. Fix every ERROR. Each WARN is either deliberate (a horn standing in front of the edge, eyes glowing in the face opening, sparks without an outline, the darkness warning on blackened iron, whose dark slot view on the sheet decides) or fixed.
4. Draw the sheet: `armor.py preview <draft>/<key>.txt <key> --slot <slot> --out <draft>/<key>_review.png`, then Read the image and judge it as a player would see it:
   - In the Satchel at 3×, on the parchment, in its Armor Slot and in the Worn column, does it read as this slot's piece and as this Armor?
   - Does the idea read at 3×, and still at 1×, or is it noise? Lone pixels of a color that belong to nothing are noise.
   - Is it a solid, sturdy form, lit from light to dark across each part, or flat? Does each material read as itself: metal with its glint, leather with soft highlights?
   - Is it plain, or does it carry the detail that belongs to its material and idea? Around a busy motif, is the shading calm, and is trim kept to where it helps? Does any hair, fur or plume read as part of the armor, not as hair?
   - Do the material and the motif make sense together? Does any living effect (lightning, sparks, flame, veins) spread unevenly over the whole piece, neither mirrored, boxed into a strip, nor bunched in one corner?
   - Does it suggest its name, or illustrate it? Is the literal object of the name on it, where something worked into the armor would do?
   - Is the light the same everywhere, from the upper left? Are the highlights clean lines that follow the form?
   - In the dark Armor Slot, does the silhouette still read? On the parchment, does nothing pale vanish?
   - In the against-template view, is anything magenta that isn't deliberate?
   - Beside the other Armor Icons, does it stand apart?
5. Revise and check again until it holds up. Expect two to four rounds.

Done when `check` prints OK and the sheet holds up on every point above.

## 5. Build and import

Add the grid to `tools/sprites/armor_icons.txt` as `= <key>` and its 32 rows, after the others (replace a block of the same key). The file's `@ size 32` line, at its top, covers every block. When the file doesn't exist yet, start it with these lines:

```
; Armor Icons (GLOSSARY.md, "Armor Icon"): 32 rows of 32 each, drawn in the shape of an Armor
; Slot's template in tools/sprites/armor_templates/ with /draw-armor-icon.
; . transparent; see KEY in build_sprites.lua for every color.
;   ASEPRITE=... tools/sprites/build.sh tools/sprites/armor_icons.txt ui/sprites/armor

@ size 32
```

Then:

```bash
ASEPRITE=~/Projects/aseprite/build/bin/aseprite tools/sprites/build.sh tools/sprites/armor_icons.txt ui/sprites/armor
~/Desktop/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --import
```

The build makes an `.aseprite` and a `.png` only for icons without an `.aseprite` file, so the hand-edited ones are kept, and it redraws the contact sheet `tools/sprites/preview/armor_icons.png`. Make sure `ui/sprites/armor/<key>.png.import` has `mipmaps/generate=false` (pixel art imports without mipmaps); if not, set it and import again. Redrawing an icon from its grid takes `--force=<key>`; once the user has touched it up in Aseprite, that file is the truth, so ask before forcing it.

The build also exports every other icon's PNG again from its `.aseprite`. Before building, copy `ui/sprites/armor/` aside when it exists. After it, compare the other icons' PNGs with the copies. If one changed, its `.aseprite` and PNG had drifted apart: put the old PNG back and tell the user which file holds what.

Done when the `.png`, `.aseprite` and `.png.import` exist and `armor.py check ui/sprites/armor/<key>.png <key> <slot>` prints OK.

## 6. Review with the user

Draw the sheet from the built icon, `armor.py preview ui/sprites/armor/<key>.png --slot <slot>`, which writes `tools/sprites/preview/<key>_armor_review.png`. Send it to the user (with every other Armor's sheet, when there are several) with one line each on the idea: the materials and the motif, and why. Revise, rebuild with `--force=<key>` and send again until they sign off.

## 7. Hook it up

Nothing reads `ui/sprites/armor/` yet: Armor joins the game in the roadmap's milestone "What an Armor is", and the Satchel in "The Store and the Satchel". Tell the user the icon is waiting for its Armor, whose definition will take the icon's key as its file name. There is no test to run for it.
