---
name: add-mod
description: Adds Mods and Hexes to Content from a name, an Augmentation written as text, a Mod Cost, the card types it accepts and a Rarity, composing the Augmentation from the engine's Modifications and building what one is missing. Use when the user types /add-mod, gives a Mod or Hex in brackets, or asks to add, author or make a Mod, Hex or card upgrade for the game.
---

# Add Mods

From the user's words to finished Mods and Hexes in `content/mods/` (game ADR 0029). The user writes what a Mod does; this session composes it from engine Modifications, saves it, and checks that `ModText` writes it back with the same meaning. `$GODOT` below is `~/Desktop/Godot_v4.7.2-stable_linux.x86_64`.

Read the glossary's entries for Mod, Hex, Augmentation, Mod Cost, Modded Name and Rarity in `GLOSSARY.md`, and `docs/adr/0029-*.md`, before composing anything: they are the rules a Mod is held to.

## 0. With no arguments

Answer with the syntax and add nothing:

```
/add-mod [Name] [Augmentation] [Mod Cost] [[Type][Type]...] [Rarity] [Hex] [Once]

  Name         one word or more, put in front of the card's name: Protective
  Augmentation what it does, as one sentence: Modified card gets +0/+1 and gains vigilance and lifelink.
  Mod Cost     mana added to the card's cost, {W} or {1}{G}; [] or [None] for a land Mod
  Types        the card types it accepts: [Creature], [Artifact][Enchantment], or [Land] alone
  Rarity       Common, Uncommon, Rare, Mythic or Unique
  Hex          optional: it is a Hex
  Once         optional: a card may hold it only once (every Unique Mod is)

Several Mods: one bracketed line each.
```

## 1. Read the Mods

Parse each line into its parts and check them before composing anything. Refuse a line, saying why, when:

- a part is missing, or the Rarity or a card type is not one of the game's (Artifact, Creature, Enchantment, Instant, Land, Sorcery; there are no planeswalkers, ADR 0001);
- it breaks the Mod's shape: Land with another type, a land Mod with a Mod Cost, another Mod without one, a Unique Hex. These are the checks of `Mod.problems()` in `run/mod.gd`;
- a Mod or Hex of that name is already in `content/mods/`.

Unique sets once per card without being asked. A Mod Cost that is not mana, such as "Sacrifice a creature", is not refused: the engine cannot cast with additional costs yet, so it is a missing primitive (step 2).

Done when every line is read or refused, and the user has seen any refusal.

## 2. Triage

Run `$GODOT --headless --path . -s res://tools/cards/card_tool.gd -- primitives` for every class there is to compose from. The Modifications a Mod is made of are in `addons/modmox_rules/src/cards/`: `AddPowerToughnessModification` ("gets +N/+N", negative for a Hex), `AddAbilityModification` (gains any one ability: a keyword, or a triggered, activated or static one), and `AddManaCostModification` (the Mod Cost). An ability is composed from the same primitives a card's is.

Put each Mod in one group:

- **Ready**: the existing primitives give exactly what its words say. A near miss is not Ready: "can't be blocked except by Walls" is never "can't be blocked".
- **Blocked**: it needs a primitive the engine lacks: a keyword, an effect, a kind of mana in the Mod Cost (hybrid {U/G}, for one), an additional cost, or a kind of Modification (such as "becomes an artifact").

When it is unclear how a Mod's words should play in this game, describe in plain words what the composition would do and ask the user before it counts as Ready. Show the triage as a table, the Blocked Mods grouped by what each lacks.

Done when every Mod has a group and the user has seen the table.

## 3. Propose what Blocked Mods need

For each missing primitive, show the user one proposal, and wait for a yes before writing any code. It follows the proposal in `/add-card`'s step 4 (`.claude/skills/add-card/SKILL.md`): the class, folder and fields, the engine test scenarios and any ADR it touches, its words in `AbilityText` or `ModText`, the AI, and a Keyword Chip asked about as a question for a new keyword. A new kind of Modification gets its words in `ModText` (`ui/cards/mod_text.gd`) with a line in `tests/ui/cards/test_mod_text.gd`.

An approved primitive is built test-first, as `addons/modmox_rules/docs/conventions.md` says, and its Mods then go through step 4. A declined one leaves its Mods unadded. Done when the user has answered every proposal and every approved primitive's tests pass.

## 4. Compose and save the Ready Mods

Write a throwaway script in the scratchpad, run with `$GODOT --headless --path . -s <script>`, that builds each Mod new and saves it with `ResourceSaver.save()` to `content/mods/<name in snake_case, apostrophes dropped>.tres` (Nomad's is `nomads.tres`), Hexes in the same folder. Build every sub-resource new for each Mod. Set:

- `name`, `is_hex`, `rarity` (`Mod.Rarity`), `card_types` (`MmCardTypes.CardType`), `is_once_per_card`;
- `augmentation`: one Modification for each part of the sentence, in its order. Power and toughness are one `AddPowerToughnessModification`; each ability its own `AddAbilityModification`;
- `mod_cost`: an `AddManaCostModification` whose `cost` is an `MmManaCost` (generic mana as `generic`, each colored symbol in `symbols`), or null for a land Mod.

The script then loads each saved file back with `ResourceLoader.CACHE_MODE_IGNORE`, prints `mod.problems()` and `ModText.of(mod)`. A problem is a composition mistake: fix it and save again.

Done when every Ready Mod is saved and has no problems.

## 5. Review the text

Show each Mod's words as the user wrote them beside what `ModText` writes. Mark each difference as the same meaning (ADR 0023 accepts plainly correct wording, such as "this land" for "this", or "gain" for "get" life) or a different meaning. A different meaning is a composition mistake: fix the Mod and review it again. Never change `ModText` or `AbilityText` to match the user's words without asking: they write every card's and Mod's text.

Then add each Mod to `ACCEPTED` in `tests/content/test_mod_content.gd`, its file name to the text `ModText` wrote.

Done when every added Mod reads with the meaning of its words, and is in `ACCEPTED`.

## 6. Test and wrap up

- Run `GODOT=$GODOT tools/test.sh -gselect=test_mod_content -gexit`, then the whole suite with `GODOT=$GODOT tools/test.sh`, and check it printed exactly one `SCRIPT ERROR` (the one `test_static_typing` expects).
- Name the Mods added, with their files and their text, and every Mod not added with what it waits on.

Adding a Mod makes it Content only: no Workshop, Spoils or Villain hands it out yet.
