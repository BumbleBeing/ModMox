---
name: primitives
description: Breaks a Magic card, or a piece of effect text, into the rules engine's primitives (which ones it takes, what each is and how it is used here) and how they compose, in prose and in plain GDScript checked against AbilityText. Sketches any primitive the engine lacks. Use when the user asks what a card or an ability needs, how it would be composed or implemented, or whether the engine can express some text.
argument-hint: "<card name> | \"<effect text>\""
---

# Primitives

From a card name or a piece of effect text to the engine primitives that express it, how they compose, and a sketch of each one the engine lacks. It is read-only: nothing in the repo is written, and adding a card stays with `/add-card`, whose triage words (Ready, Blocked, Set Aside, Unsuited, near miss) are used here. `$GODOT` below is `~/Desktop/Godot_v4.7.2-stable_linux.x86_64`, and `$TOOL` is `$GODOT --headless --path . -s res://tools/cards/card_tool.gd --`.

## 1. Get the text

- **Effect text** (quoted, or worded as rules text) is the text. It has no card, so take its source from its words: "this creature" is a creature, a bare instruction such as "Draw two cards" is an instant's spell ability. Say what you took.
- **A card name**: look for it by `name` in `content/cards/oracle.json`. A card there is already in Content, and its `.tres` under `content/cards/` holds its authored composition: read it, since it is what the answer is checked against. Otherwise `$TOOL fetch "Name"` prints its Oracle text, type line and **refusals** (an `{X}`, a hybrid symbol, a type the engine lacks, two faces). Never `write`.
- Look for the card in `docs/waiting_cards.md` too: one triaged before carries what it waits on and anything the user has agreed about how it plays.
- Reminder text in parentheses is not rules.

Done when you hold the exact rules text, its source's card type, and any refusal.

## 2. Read the primitives

Run `$TOOL primitives` and read it whole: every class cards are composed from, with its doc comment and fields, read from the engine's source. It is the source of truth, uncommitted work included, and a primitive named from memory may not exist or may mean something else.

- An enum's values are in its file: `MmTurn.Step` in `src/rules/mm_turn.gd`, `MmZone.Kind` and `MmCounter.Kind` in `src/core/`, `MmCardTypes` in `src/cards/`, `MmMana.Type` in `src/mana/`.
- A primitive's usage shows in Content: `grep -rl --include=*.tres "<its file name>.gd" content/` lists the authored cards that use it, and the closest one's `.tres` shows its fields set. `addons/modmox_rules/tests/support/scenario.gd` builds the common shapes in code (`enters()`, `leaves()`, `targeted()`, `free_prison()`).

Done when you have the listing and know what each primitive you will name is for.

## 3. Map the text

Split the text into its abilities (keyword, static, activated, triggered, spell), and each ability into its parts: cost, trigger, condition, targets, effects, and within each effect its Selection, Value and Filter. Give every part one primitive, or mark it a **gap**. A part the closest primitive gets almost right is a **near miss**, and a near miss is a gap: "can't be blocked except by Walls" is never "can't be blocked", and an effect whose doc comment says it moves cards in a graveyard does not move a permanent. Name the rules difference.

The shapes that recur in this engine:

- Effects never hold targets (ADR 0014). "Target creature" is a `TargetRequirement` on the ability and a `TargetSelection` with that requirement's index on the effect; several effects may share one. "Each creature" is an `EachSelection`, with no target.
- "Any target" is an `AnyOfFilter` of `IsPlayerFilter` and a creature `HasCardTypeFilter`. "And" is `AllOfFilter`; "non-", "un-" and "another" wrap a Filter in `NotFilter` (`IsTappedFilter`, `HasColorFilter`, `IsSourceFilter`).
- "This" is `SourceSelection` in an effect, and `IsSourceFilter` in a trigger's or a target's Filter.
- "That player" is `TriggeringPlayerSelection`, fixed as the ability triggers. `ControllerOfSelection` of the `TriggeringObjectSelection` reads the same, but finds no one once the spell has left the stack, as a countered one has.
- Every number is an `MmValue`: a `ConstantValue` for a printed one.
- A keyword with no parameters is its own `StaticAbility` subclass; "protection from X" is a `ProtectionAbility` with a Filter.
- "Until end of turn" is a `CreateContinuousEffect` holding an `MmContinuousEffect`, and what it affects is fixed as it resolves. A static "gets +1/+1" is a `ContinuousStaticAbility`, matched again all the time.
- An ability's `{R}` is its `mana_cost`. The card's own mana cost is a printed characteristic the card tool writes, never composed.
- A field's default is part of the meaning, and a `.tres` leaves it out: a `ZoneChangeTrigger` left at its defaults is "enters the battlefield" from anywhere.
- An encounter is one Hero against one Villain: "each opponent" is the one opponent, and "target player" may be either.

Where two primitives could carry a part, a **look-alike** is the one that reads the same and plays differently. Name it, and the case where it goes wrong, so the choice is shown rather than asserted.

Then give the text one verdict, in `/add-card`'s words: **Ready** with no gap; **Blocked** on its gaps; **Set Aside** when it needs something new on screen (a new kind of decision, such as "choose one —", or something new drawn on a face); **Unsuited** when it can mean nothing here (ante, more than two players). Where it is unclear how the text should play in this game, say so and describe the readings, rather than settle it.

Done when every word of the rules text is carried by a primitive or a named gap.

## 4. Sketch each gap

A gap gets a sketch, never code in the repo:

- the primitive: its class name, folder, base class, and `@export` fields with types and defaults, named as `addons/modmox_rules/docs/conventions.md` says (a subclass ends with its base kind and has no `Mm` prefix; an enum has explicit values);
- its doc comment in the engine's voice: the Oracle sentence it expresses, with its CR rule;
- why the nearest existing primitive won't do. Widening an existing primitive is preferred where it fits, when no card in Content that uses it plays differently afterward (check each one). An existing field's default never changes (conventions, "Static typing"): a widening that would need a different default is a new field;
- the ADRs it touches, found by their titles in `addons/modmox_rules/docs/adr/` and `docs/adr/`;
- its words in `AbilityText` (`ui/cards/ability_text.gd`);
- a new kind of decision, something new drawn on a face, or a change to the AI, if it needs one.

A refusal is a gap in the card tool: say what the tool would have to read.

Done when every gap has a sketch.

## 5. Check the code

Write the composition in plain GDScript: each Resource built with `.new()` and its fields, every variable typed as the conventions require, in a function that returns `Array[MmAbility]`, so that an `/add-card` compose script can set a card's `abilities` from it. Put it in this throwaway script in the scratchpad, with the source's card types and name, and run it with `$GODOT --headless --path . -s <script>`:

```gdscript
extends SceneTree


func _initialize() -> void:
	print(AbilityText.of_card(_abilities(), [MmCardTypes.CardType.CREATURE], [], "Card Name"))
	quit()


func _abilities() -> Array[MmAbility]:
	# The composition.
```

Read what it prints:

- A parse or script error: fix the code and run it again.
- The Oracle text's meaning, in any plainly correct wording (ADR 0023): checked.
- A different meaning: the composition is wrong. Fix it and run it again.
- A `[ClassName]`: `AbilityText` has no words for that primitive yet, and adding the card would need them. Say so.

A gap's primitive does not exist yet, so leave it out of the script with a comment where it would go, check the rest, and say which part was checked.

Done when the script runs and every difference from the Oracle text is explained.

## 6. Report

In chat, in this order:

1. **Heading**: the card's name (or "Effect text"), its rules text quoted, and the verdict with its gaps named.
2. **Primitives**: a table with a row for each primitive the composition uses: its class and folder, what it is (its doc comment cut to a sentence), and how it is used here (the fields set, and an authored card that uses it, if any). A gap's row is marked **new**.
3. **Composition in prose**: a few sentences on how the parts fit and why (which effect reads which target, what is fixed as it resolves, what links two abilities, each look-alike passed over), then an indented outline from each ability down to its Values and Filters, one line per primitive with the words of the text it carries.
4. **Composition in code**: the function from step 5, and the rules text it printed.
5. **New primitives**: each sketch from step 4.
