---
name: add-armor
description: Adds an Armor to ModMox, ready to be worn, from a name, an Armor Slot (Helm, Cuirass or Greaves), what it does as Starting Conditions (more or less starting life, a smaller opening hand, extra free mulligans, or an emblem with an ability), an optional price and a 32 × 32 sprite. It composes the Emblem from the engine's primitives, places the Armor Icon, saves the Armor and its Emblem to Content, checks its generated words against the user's, tests it and shows it worn in an encounter. Use whenever the user types /add-armor, or asks to add, make, author or implement an Armor, a Helm, a Cuirass, Greaves, an armor piece or something the Hero wears, even when they give only a name and an ability, or attach a sprite for one.
---

# Add Armor

From the user's words and sprite to an Armor in `content/armor/` that a run can hold and wear (game ADR 0106). The user says what it does; this session turns that into Starting Conditions, composes any Emblem from engine primitives, saves both files, and checks that `StartingConditionText` writes it back with the same meaning. `$GODOT` below is `~/Desktop/Godot_v4.7.2-stable_linux.x86_64`, and `$TOOL` is `$GODOT --headless --path . -s res://.claude/skills/add-armor/scripts/armor_tool.gd --`.

Before composing anything, read the glossary's entries for Armor, Armor Slot, Worn, Armor Icon, Starting Condition, Potion and Emblem Face in `GLOSSARY.md`, and `docs/adr/0106-*.md`. They set the rules an Armor is held to, and the words it is allowed.

## 0. With no arguments

Answer with the syntax and add nothing:

```
/add-armor [Name] [Slot] [Starting Conditions] [Price] + a sprite

  Name                 Seer's Cuirass
  Slot                 Helm, Cuirass or Greaves
  Starting Conditions  what changes at the start of each encounter while it is Worn, one sentence each:
                         You start each encounter with 3 more life.   (or 2 less life)
                         Your opening hand has one fewer card.
                         You start each encounter with an extra free mulligan.
                         You get an emblem with "{2}{U}: Draw a card. Activate only as a sorcery and only once each game."
  Price                optional, in gold, usually 150 to 300; 200 when left out
  Sprite               a 32 × 32 PNG, attached or as a path; with none, /draw-armor-icon draws one

Several Armor: one line each, with a sprite for each.
```

## 1. Read the Armor

The user may bracket the parts, write them as a sentence ("a [Cuirass] with the ability [...]") or list several. Take from each:

- **Name** and its **key**: the file name, the name in snake_case with apostrophes dropped (`name.to_snake_case().replace("'", "")`; "Seer's Cuirass" is `seers_cuirass`). The Armor, its Emblem and its icon all use the key. The content test checks the files against it.
- **Armor Slot**: Helm, Cuirass or Greaves. "Boots", "chest" or "legs" are not slots. Ask which one is meant, and say "Armor Slot" yourself: the glossary avoids "armor type".
- **Starting Conditions**: each sentence is one of the four kinds in step 2.
- **Price**: a whole number of gold. When none is given it is 200, and the report says so, since prices are placeholders the user tunes later.
- **Sprite**: an image attached to the message (its path appears as `[Image: source: …]`), a path the user gives, or none.

Refuse a line, saying why, when its name or slot is missing, when an Armor with that key is already in `content/armor/`, or when `content/emblems/<key>.tres` already exists and is not this Armor's. Never replace one without the user's yes. Done when every line is read or refused, and the user has seen any refusal.

## 2. Triage the Starting Conditions

A Starting Condition is one change to how the Hero starts an encounter. The engine is handed only final numbers and Emblems (ADR 0011), so these are the only kinds there are:

| Kind | Tool spec | Words `StartingConditionText` writes |
|---|---|---|
| More or less starting life | `life:3`, `life:-2` | You start each encounter with 3 more life. |
| A smaller opening hand | `hand:1` | Your opening hand has one fewer card. |
| Extra free mulligans | `mulligans:1` | You start each encounter with an extra free mulligan. |
| An Emblem | `emblem` | You get an emblem with "…" |

Put each Armor in one group:

- **Ready**: every sentence is one of these kinds, and any Emblem's ability is composed exactly from existing primitives. A near miss is not Ready.

  Start from the closest authored ability, because most Emblems are a known shape with other numbers. The Emblems in `content/emblems/` include `diviners_boon.tres` (an activated ability with a mana cost, sorcery speed and once each game, drawing cards) and `electromancers_boon.tres` (one with a target, dealing damage). Cards in `content/cards/` cover more shapes; grep their `.tres` files for the effect's class. In a `.tres`, a mana cost's `symbols` are `MmMana.Type` values: WHITE 0, BLUE 1, BLACK 2, RED 3, GREEN 4, COLORLESS 5; its generic mana is `generic`. Only when no authored ability comes close, run `$GODOT --headless --path . -s res://tools/cards/card_tool.gd -- primitives`, which lists every class (about 550 lines), and grep it rather than reading it whole.
- **Blocked**: it needs something the engine or the game lacks. That is either an engine primitive for the Emblem's ability, or a new kind of Starting Condition, such as "your maximum hand size is eight" or "you play first", which the game has no class for.

Some sentences need judgment before they count as Ready:

- A total is not a change. "Start with 25 life" is "5 more life" only while the default is 20, and other Armor add to it, so ask.
- An ability on a permanent or in play is an Emblem. "Creatures you control get +1/+1" becomes `You get an emblem with "Creatures you control get +1/+1."`, so confirm that reading with the user.
- Whatever is gone once used is a Potion, never an Emblem (glossary, "Potion"). An Emblem's ability is static, triggered or activated, at most "only once each game", and the Emblem itself stays.
- An Armor brings one Emblem at most, holding every ability it gives, and the content test checks this. Two "emblem with" sentences become one Emblem with both abilities.

When it is unclear how a sentence should play, describe in plain words what the composition would do, and ask before it counts as Ready. Show the triage as a table. Done when every Armor has a group and the user has seen the table.

## 3. Propose what Blocked Armor needs

For each missing piece, show the user one proposal and wait for a yes before writing any code:

- **An Emblem's primitive** follows `/add-card`'s step 4 (`.claude/skills/add-card/SKILL.md`): the class, its engine tests, its words in `AbilityText`, the AI, and any ADR it touches.
- **A new kind of Starting Condition** is a subclass of `StartingCondition` in `run/starting_conditions/`:
  - `apply_to()` changes the `MmPlayerSetup`, and `problems()` rejects an amount of nothing. If its number needs holding in bounds, that goes in `StartingCondition.apply_all()`.
  - Its words go in `StartingConditionText`, shown to the user exactly first, with a line in `tests/ui/cards/test_starting_condition_text.gd`.
  - It gets a test in `tests/run/test_armor.gd`, a spec in `scripts/armor_tool.gd`, and its row in ADR 0106 and in step 2's table.
  - Nothing in it names Armor, because a Status will hold the same ones (milestone 33).

An approved piece is built test-first, as `addons/modmox_rules/docs/conventions.md` says, and its Armor then goes on to step 4. A declined one leaves its Armor unadded. Done when the user has answered every proposal and every approved piece's tests pass.

## 4. The Armor Icon

The icon is `ui/sprites/armor/<key>.png`: 32 × 32, pixel art, drawn in the shape of its slot's template in `tools/sprites/armor_templates/`. The Satchel shows it on its entry and in its Armor Slot.

- **A sprite given**: check that it is a 32 × 32 PNG (`cmp` it, and read its size with Python's PIL or `file`).
  - When `ui/sprites/armor/<key>.png` already exists and is byte-identical, it is in place and already imported: go on to step 5.
  - When one exists and differs, ask before replacing it. Icons drawn by `/draw-armor-icon` also have an `.aseprite` file beside the PNG and a `= <key>` block in `tools/sprites/armor_icons.txt`. `tools/sprites/build.sh` exports the PNG again from the `.aseprite` on every build, so a new PNG copied over it would be quietly undone. Replacing one means also deleting its `.aseprite` file and its grid block, and the user should hear that in the same question.
  - Otherwise copy it there. A PNG the user supplies needs no `.aseprite` file and no grid block.
- **No sprite**: hand off to `/draw-armor-icon` (`.claude/skills/draw-armor-icon/`) with the name, a look if the user gave one (otherwise the Armor's words) and the slot. Come back once the user signs the icon off; that skill builds and imports it.

When you copied a PNG, import it with `$GODOT --headless --path . --import`, and make sure `ui/sprites/armor/<key>.png.import` has `mipmaps/generate=false`, since pixel art imports without mipmaps. If it doesn't, set it and import again. Then run `python3 -I .claude/skills/draw-armor-icon/scripts/armor.py check ui/sprites/armor/<key>.png <key> <slot>`, and tell the user if the sprite does not fit its template's silhouette. It is their sprite, so this is a note, not a refusal.

Done when the icon is imported at its key.

## 5. Compose and save

1. **The Emblem first**, when the Armor has one. Write a throwaway script in the scratchpad, run with `$GODOT --headless --path . -s <script>`. It builds a new `MmCardDefinition` whose `name` is the Armor's name and whose `abilities` are the composed abilities, and nothing else (ADR 0011). Build every sub-resource new, and save it with `ResourceSaver.save()` to `content/emblems/<key>.tres`. To see how an ability is built, read the `.tres` of an authored Emblem or card with a similar one. The script loads the file back with `ResourceLoader.CACHE_MODE_IGNORE` and prints `AbilityText.lines_of(emblem.abilities, AbilityText.EMBLEM_NOUN)`.
2. **Then the Armor**, with the tool, its Starting Conditions in the order the user wrote them:

   ```bash
   $TOOL save seers_cuirass "Seer's Cuirass" cuirass 200 emblem
   $TOOL save lionguard_helm "Lionguard Helm" helm 250 life:3 mulligans:1
   ```

   It makes each Starting Condition new, links the Emblem and icon by path, saves `content/armor/<key>.tres`, loads it back, and prints the Armor's problems and its words. A problem is a composition mistake: fix it and save again with `--replace`. `$TOOL show <key>` prints the same again later, without saving.

Done when every Ready Armor is saved and its save printed "problems: none".

## 6. Review the words

Show each Armor's words as the user wrote them beside what `StartingConditionText` wrote, a sentence at a time. Mark each difference as the same meaning (ADR 0023 accepts plainly correct wording, such as "an emblem" for "the emblem", or "this emblem" for "it") or a different meaning. A different meaning is a composition mistake: fix the Emblem or the Armor and review it again. Never change `StartingConditionText` or `AbilityText` to match the user's words without asking, because they write every Armor's and card's text.

Then add the Armor to `ACCEPTED` in `tests/content/test_armor_content.gd`: its key, mapped to its words with one sentence to a line, joined by `\n`, and an Emblem's quotes escaped:

```gdscript
	"lionguard_helm": "You start each encounter with 3 more life.\nYou start each encounter with an extra free mulligan.",
	"seers_cuirass": "You get an emblem with \"{2}{U}: Draw a card. Activate only as a sorcery and only once each game.\"",
```

Done when every added Armor reads with the meaning of the user's words and is in `ACCEPTED`.

## 7. Test it

- **The Emblem does what it says.** Each authored Emblem has a test in `tests/content/test_emblem_and_potion_content.gd` that plays it through a game: what it costs, when it can be used, what it does, and how often. A mis-saved field or a changed default then shows as a change in play, not just in its text. Add one for the Armor's Emblem, modeled on the nearest test there. "Draw a card" is Diviner's Boon's test with one card in place of two. The same file checks every Emblem's shape on its own, so nothing else there needs a line.
- **Run the tests through the guard, one run at a time.** Stacked runs once took the machine down, and the guard refuses to start beside another run.
  - While building, run the Armor's own test files, which take seconds: `GODOT=$GODOT tools/guarded.sh tools/test.sh -gselect=test_armor_content -gexit`, then the same with `test_emblem_and_potion_content`. `-gselect` matches a file's name; `-gtest=` runs the whole suite in one process, so don't use it for one file. Skip `--quick` here: it picks its tests from `git status`, and with other work in the tree it can run nearly the whole suite.
  - Then the whole suite: `GODOT=$GODOT tools/guarded.sh tools/test.sh --jobs=4`. Under the guard it can take five or six minutes, so start it in the background and wait for it to finish. Don't poll it with `pgrep -f tools/test.sh`, which matches its own command line and never stops.
  - A passing run prints exactly one `SCRIPT ERROR`, `Variable "untyped" has no static type`, which `test_static_typing` provokes on purpose. Any other is a failure.

Done when the whole suite passes.

## 8. See it worn, and wrap up

Check what wearing it does to the Hero's setup, beside the setup wearing nothing:

```bash
$TOOL worn <key>
```

It prints the starting life, opening hand, free mulligans and the Emblems' names. Each should differ from the bare setup exactly as the Armor's words say, and nothing else should change.

Then wear it in a debug encounter and save a picture, once no test run is going (both want the cores), with an absolute path in the scratchpad:

```bash
$GODOT --path . -- --hero=red_green --villain=white_black --seed=7 --armor=<key> --screenshot=<scratchpad>/<key>_worn.png
```

The picture is taken at the coin flip, before the opening hand. Look at it: an Emblem lights the Hero's Emblems button with its count, and a change of life shows in the Hero's life total. It cannot show which Emblem it is or the Armor Icon, so send the user the picture together with `worn`'s lines.

Then report:

- each Armor added: its files (`content/armor/<key>.tres`, `content/emblems/<key>.tres`, `ui/sprites/armor/<key>.png`), its slot, its price (saying when it was the default of 200), and its words;
- every Armor not added, with what it waits on;
- that Emblem art is optional: a picture in `content/art/emblems/<key>.png`, with its credit in the manifest there, shows on its Emblem Face.

An added Armor is held in every debug run (`Run.debug()`), and `--armor=<key>` wears it in a debug encounter. The Satchel, which puts Armor on in a run, comes in milestone 24, and the Store, Spoils and Trove that hand it out come in milestones 24 and 26. When this run changed an ADR, the glossary or the conventions, copy them into the Obsidian vault as `CLAUDE.md` says.
