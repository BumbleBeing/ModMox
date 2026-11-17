---
name: add-card
description: Adds real Magic cards to Content from their Oracle Data, triaging each against the engine's primitives and building what a card is missing. Use when the user names cards to add, gives a Scryfall search, or asks what cards are waiting.
---

# Add cards

From card names to finished Card Definitions in Content (game ADR 0040). The card tool fetches each card's **Oracle Data** and writes its printed characteristics; this session composes its abilities. `$GODOT` below is `~/Desktop/Godot_v4.7.2-stable_linux.x86_64`, and `$TOOL` is `$GODOT --headless --path . -s res://tools/cards/card_tool.gd --`.

Only real cards on Scryfall are added this way; a card of the user's own design goes back to them as out of scope. Adding a card makes it Content only: no deck, Villain or Starting Pool gets it.

## 1. Fetch

- Names: `$TOOL fetch "Serra Angel" "Lightning Bolt"`.
- A Scryfall search: `$TOOL search "set:lea"`.
- No arguments: open `docs/waiting_cards.md`, show its groups, and ask which to work on. Its Ready group goes first.

Each card prints its Oracle text, the file it would be written to, its Rarity, and every **refusal**: something the tool cannot read, such as `{X}`, a type the engine lacks, a `*` power or two faces. Done when every card has its Oracle Data printed, or the reason it could not be fetched.

## 2. Triage

Run `$TOOL primitives`: every class cards are composed from, with its doc comment and fields, read from the engine's source. Read `ui/cards/ability_text.gd` too when a wording matters. Put each card in exactly one group:

- **Ready**: the existing primitives give its exact current Oracle behavior. A near miss is not Ready: "can't be blocked except by Walls" is never "can't be blocked". Reminder text in parentheses is not rules.
- **Blocked**: it needs new primitives, or a refusal the tool must learn to read (an `{X}` cost is both). A `*` power, or a "special" or "bonus" Rarity, is not a block: the first is a characteristic-defining ability composed in step 3, the second a Rarity the user chooses.
- **Set Aside**: it needs something new on screen, which starts with a GUI prototype the user signs off on: a new kind of decision ("choose one —", "choose a color"), something new drawn on a face (counters, tokens), or two faces.
- **Unsuited**: it can never mean anything here, such as ante or more than two players. Never proposed.
- Already in Content: skipped.

Whenever it is unclear how a card should play in this game (an encounter is one Hero against one Villain), describe in plain words what it would do with the current primitives and ask the user to confirm or deny before it counts as Ready.

Show the user the triage as a table, with the Blocked cards grouped by the primitive each lacks, so one primitive is seen to unblock several. At most 20 Ready cards are added in one session; the rest go in the waiting list's Ready group in step 6. Done when every card has a group and a reason, and the user has seen the table.

## 3. Add the Ready cards

1. `$TOOL write "Name" ...` writes each card's file under `content/cards/<first set>/` with its printed characteristics, and its entry in `content/cards/oracle.json`. It refuses a card with any refusal; pass `--anyway` only when every refusal is a `*` power or toughness, or a Rarity the user has chosen.
2. Compose the abilities in a throwaway script in the scratchpad, run with `$GODOT --headless --path . -s <script>`. It loads each written file with `ResourceLoader.CACHE_MODE_IGNORE`, sets `abilities` (and `rarity`, if the user chose one), and saves it back with `ResourceSaver.save()`. To see how an ability is built, read the `.tres` of an authored card with a similar one; `prodigal_sorcerer.tres` is "deals 1 damage to any target". Build every sub-resource new for each card: two cards sharing one fails `test_no_two_cards_share_a_sub_resource`.
3. `$GODOT --headless --path . -s res://tools/art/fetch_art.gd` fetches art for every card without it.

Done when every Ready card's file has its abilities and its art.

## 4. Propose and build what Blocked cards need

For each missing primitive, show the user one proposal, and wait for a yes before writing any code:

- the primitive: its class, folder and fields, and the Oracle sentence it expresses;
- its engine test scenarios, and any ADR it touches or would change;
- its words in `AbilityText`;
- for a new keyword, its sentence in `Reminders` and a Keyword Icon drawn with `/draw-keyword-icon` (`.claude/skills/draw-keyword-icon/`) for the user to touch up;
- the AI: why its derived Timing Tag and simulation already play it well, or the change the AI needs, with one Agent test that it is played when it should be;
- for a refusal, the tool's change, with its test in `tests/tools/test_oracle_reading.gd`.

An approved primitive is built test-first, as `addons/modmox_rules/docs/conventions.md` says; its cards then go through step 3, and they count toward the 20. A declined one leaves its cards Blocked. Done when the user has answered every proposal and every approved primitive's tests pass.

## 5. Review the rules text

Run `$TOOL review <file name> ...` for every card added. It prints each card's generated rules text under its Oracle text. Mark each difference as the same meaning (ADR 0023 accepts plainly correct wording) or a different meaning. A printed "named X" is generated as "originally named X" on purpose (ADR 0023): accept it, and put the generated words in `PRINTED`. A different meaning is a composition mistake: fix the card and review it again. Show the user the reviewed cards. Then add each card that has abilities to `PRINTED` in `tests/ui/cards/test_ability_text.gd`, with the text the review accepted.

Done when every added card reads with its Oracle text's meaning.

## 6. Test and wrap up

- A card gets a behavior test in `tests/content/test_card_content.gd` only when it puts primitives together in a way no existing test covers. A card that repeats a tested pattern with other numbers needs none: `test_card_oracle_data.gd` and the review cover it.
- Run `GODOT=$GODOT tools/test.sh`, and check it printed exactly one `SCRIPT ERROR` (the one `test_static_typing` expects).
- Update `docs/waiting_cards.md`: take out the cards added, and put in every card not added under its group and what it waits on.
- Name the added cards, so the user can set their art's focus point in the Card Gallery (`$GODOT --path . res://tools/card_gallery/card_gallery.tscn`) when they like.

Done when the suite is green and the waiting list holds every card triaged and not added.

## Rebalancing a card

A **Rebalance** is a deliberate change to a card away from its Oracle Data. Change the Card Definition; then, unless the change is to its Rarity (never checked), add the field to its entry's `"rebalanced"` list in `content/cards/oracle.json`: `name`, `mana_cost`, `type_line`, `power` or `toughness`.
