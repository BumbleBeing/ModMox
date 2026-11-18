---
name: add-enemy-deck
description: Adds every card of a Villain's deck list to Content through /add-card, one subagent per card, building the missing primitives the deck needs (the one blocking the most cards first, each with the user's yes), then writes the deck to content/decks/ and the Villain that plays it, placed on a Stage. Use when the user gives a deck name and a list of "<count> <card name>" lines, asks to add an enemy's or Villain's deck, or wants a whole decklist made playable.
---

# Add an enemy deck

From a deck name and a deck list to every card in Content, the deck saved in `content/decks/`, and the Villain who plays it in `content/villains/`, listed on a Stage. This skill only orchestrates: each card is added by its own subagent following `/add-card` (`.claude/skills/add-card/SKILL.md`), and each missing primitive is built by its own subagent after the user agrees to it. You keep the plan and the ledger, talk to the user, and pick what comes next; the subagents do the work, so your own context stays small enough to see a whole deck through.

`$GODOT` is `~/Desktop/Godot_v4.7.2-stable_linux.x86_64`; `$TOOL` is `$GODOT --headless --path . -s res://tools/cards/card_tool.gd --`. The subagent prompts are in `references/prompts.md`: read it before you start the first subagent.

## 1. Take the input

First run `git status`. If engine files are changed and not committed, another session may be working in this checkout. The card subagents edit `oracle.json`, `test_ability_text.gd` and `waiting_cards.md` too, and someone else's half-done work can break the suite for reasons that have nothing to do with this deck. Tell the user what you see and ask whether to go on.

The user gives the deck's name first, then the list:

```
ajani_2
6 Charmed Stray
2 Coordinated Maneuver
17 Plains
```

- **The deck's name** is the enemy's name in snake case (`ajani`). An enemy with several decks, such as a unique encounter, gets one per tier, `<enemy>_<tier>` (`ajani_2`). Ask for the name if it is missing or doesn't fit this form, and ask before you replace a deck that is already in `content/decks/`.
- **The Villain** is `content/villains/<enemy>.tres`: one Villain plays a lone deck at every Tier, or plays five Tier decks, one per Tier (ADR 0024). Ask the user now, so the end of the run doesn't wait on them:
  - its name on screen, for a new Villain (`Charmed Stray`);
  - its Portrait and Pain Portrait: `ui/sprites/portraits/<enemy>.png` and `<enemy>_pain.png` if they exist, or else whether to draw both with `/draw-portrait <card name>` or use `purple_demon.png` with no Pain Portrait for now;
  - which Stage (`content/stages/`) lists it, and at which Rank (Lesser, Elite or Boss), or none. A Villain with five Tier decks can't go on a Stage until all five are written: `StageDefinition.validate()` refuses it.
- **The list** has one `<count> <card name>` per line. Save it as it was given to `list.txt` in a folder for this deck in the session's scratchpad (`<scratchpad>/add-enemy-deck/<deck>/`); the ledger goes in the same folder. Tell the user the folder's full path so they can follow along.

## 2. Triage the deck: one subagent

Start one **triage subagent** (the triage prompt) for the whole list. It runs `/add-card`'s steps 1 and 2 on every card and writes `ledger.json`. One agent triages all the cards so that a primitive needed by two cards gets one name: the loop in step 4 counts cards by that name, so two names for one missing thing would split its count.

Read the ledger once it returns. Show the user `/add-card`'s triage table: each card with its count in the deck, its group and the reason, and the Blocked cards grouped by the primitives they lack, each primitive with how many cards it blocks. Put each question the triage left in the ledger's `questions` (a card whose play in a one-on-one encounter is unclear) to the user and record the answer before going on. A card already in Content is `done` already. A basic land not in Content is triaged like any other card.

Set Aside and Unsuited cards drop out here and are reported at the end (step 6). Done when the user has seen the table and every question has an answer.

## 3. Add the Ready cards: one subagent per card

For each Ready card, in list order, start a **card subagent** (the card prompt) and wait for it to finish before starting the next one. The card subagents run one at a time because they all edit `content/cards/oracle.json` and `tests/ui/cards/test_ability_text.gd`. Each one adds its card through `/add-card`'s steps 3 and 5, runs the card tests, and returns a report.

Update the ledger from each report. A subagent may find that its card isn't Ready after all: it names the missing primitive (reusing a ledger name when it is the same thing) and stops without adding the card. Move the card to `blocked` with that primitive. Done when every Ready card is `done` or `blocked`.

## 4. Build primitives, the one blocking the most cards first

Repeat this round until no card is `blocked` on a primitive that can still be built:

1. **Pick.** For each primitive not yet built or declined, count the `blocked` cards that need it. Take the one with the highest count. Break a tie by the number of cards it would leave with nothing else missing, and then by the copies of those cards in the deck: the aim is the most cards actually added for each primitive built.
2. **Propose.** Start a **primitive subagent** (the primitive prompt). It drafts `/add-card`'s step 4 proposal for that primitive and returns it without writing any code. Show the user the proposal and the cards it would unblock, and wait for their answer. CLAUDE.md requires the user's agreement before a new primitive is built, and a subagent can't ask for it itself.
3. **Build or drop.**
   - **Yes** (with any changes the user asks for): continue the same subagent with `SendMessage`, so it keeps what it read, passing on the user's words. It builds the primitive test-first, following `addons/modmox_rules/docs/conventions.md`, and returns the class it made and the tests it ran. Record the primitive as `built`, with its class and a line on what it expresses, so later subagents know about it without having to find it.
   - **No:** record it as `declined`. Every card that needs it is out of the loop and stays Blocked on it.
4. **Re-check the unblocked cards.** For each `blocked` card that needed this primitive, start a card subagent, one at a time as in step 3. It checks the card against the primitives now in the engine. If nothing is missing, it adds the card. If something still is, it names that primitive and adds nothing. Building one primitive often shows the next one a card needs, and that is how the loop goes deeper: the new name goes into the ledger and is counted in the next round.

Done when every card is `done`, or is `blocked` only on declined primitives.

## 5. Write the deck and its Villain

Write the deck with the bundled script, leaving out with `--skip` each card that was not added:

```bash
$GODOT --headless --path . -s res://.claude/skills/add-enemy-deck/scripts/write_deck.gd -- <deck> <list.txt> --skip "Daydream"
```

It writes `content/decks/<deck>.tres` as a Player Setup with one Run Card per copy, and refuses to write anything if a card that isn't skipped is not in Content. `tests/run/test_content_decks.gd` lists every deck in order, so add the new one there.

If you drew a Portrait with `/draw-portrait`, draw it before this step. Then write the Villain, with the answers from step 1:

```bash
$GODOT --headless --path . -s res://.claude/skills/add-enemy-deck/scripts/write_villain.gd -- <enemy> <deck> --name "Charmed Stray" --stage kitty_keep --rank lesser
```

- A Tier deck adds `--tier <N>`. Tier decks are written in order, and the script refuses one that comes too soon.
- Leave out `--name`, `--sprite` and `--pain-sprite` to keep what an existing Villain has. Without them, a new Villain takes `ui/sprites/portraits/<enemy>.png` and `<enemy>_pain.png`, where those exist.
- Leave out `--stage` and `--rank` for no Stage, and always for a Tier Villain that still lacks decks.

The script creates or updates the Villain, and adds it to the Stage's list only if the Stage stays valid. `tests/content/test_villain_and_stage_content.gd` checks that every deck is a setup of exactly one Villain, named after it or as its `_<tier>` deck, so a deck with no Villain fails it.

## 6. Test and wrap up

- Run the whole suite once (`GODOT=$GODOT tools/test.sh`) in the background, and check that it printed exactly one `SCRIPT ERROR` (the one `test_static_typing` expects). If a failure comes from one card's or one primitive's work, send it back to that subagent with `SendMessage`; otherwise start a new subagent with the failure and the ledger.
- Update `docs/waiting_cards.md` as `/add-card`'s step 6 says: take out the cards that were added, and put in every card from this deck that wasn't, under its group and what it waits on.
- If an ADR, a glossary, the roadmap or the conventions changed, copy them into the Obsidian vault and regenerate its index, as CLAUDE.md says.
- Report to the user:
  - the deck file and its card count, and the Villain with where it is listed (or that it still waits on Tier decks);
  - each card added, and each primitive built with the cards it unblocked;
  - each card left out, with its group and reason (Set Aside, Unsuited, or Blocked on a declined primitive), and how many copies the deck lost because of it;
  - that nothing is committed;
  - the added cards' names, so the user can set their art's focus points in the Card Gallery.

Done when the suite is green, the deck is in `content/decks/`, its Villain plays it, and the waiting list holds every card from the deck that wasn't added.

## The ledger

`ledger.json` is what the subagents share: every subagent reads it before it starts, so it knows which primitives this run has already built or named. You are the only one who writes it, from the subagents' reports, apart from the triage subagent, which creates it. Keep it current after every report: if your context is summarized during a long run, the ledger is how you pick up where you left off.

```json
{
  "deck": "ajani_2",
  "cards": {
    "Charmed Stray": {"count": 6, "status": "done", "file": "content/cards/war_of_the_spark/charmed_stray.tres"},
    "Daydream": {"count": 2, "status": "set_aside", "reason": "Flashback: casting from the graveyard needs a GUI prototype"},
    "Some Card": {"count": 2, "status": "blocked", "needs": ["enters-with-counter"], "reason": "..."}
  },
  "primitives": {
    "enters-with-counter": {"status": "missing", "expresses": "a permanent enters with a +1/+1 counter on it (CR 122.6)", "class": null}
  },
  "questions": []
}
```

The card statuses are `ready`, `blocked`, `done`, `set_aside` and `unsuited`; the primitive statuses are `missing`, `built` and `declined`. Only `blocked` cards have `needs`: whatever a Set Aside card would still need after its prototype goes in its `reason`, so the loop never counts a card that is out of it. A primitive's name is a short kebab-case label for the missing thing, not the class it will become. The class is filled in once it is built.
