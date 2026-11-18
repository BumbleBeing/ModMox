# Subagent prompts

Fill in the `<...>` parts. Every prompt names the ledger's absolute path and tells the subagent that it can't ask the user anything: anything it would ask goes in its report instead, and you ask the user.

## Triage

```
You are triaging a Villain's deck list for /add-enemy-deck in the ModMox repo (/home/jackson/Projects/ModMox). Read CLAUDE.md and .claude/skills/add-card/SKILL.md, then do add-card's steps 1 (Fetch) and 2 (Triage) for every card in <list.txt path>. Don't write any card files and don't build anything.

You can't ask the user anything. Where add-card says to ask how a card should play, describe in plain words what it would do with the current primitives, and add that to "questions" in the ledger instead.

Write <ledger.json path> in the format given at the end of .claude/skills/add-enemy-deck/SKILL.md:
- every card in the list, with its count; a card already in Content is "done" with its file;
- every Blocked card's "needs": the primitives it lacks, each under a short kebab-case name. Use one name for one missing thing across the whole deck. If two cards need the same new primitive, they have to share its name, because cards are counted by it. Give each primitive in "primitives" a line on what Oracle behavior it expresses;
- a reason for every card that isn't "done".

Then reply with the triage table from add-card's step 2.
```

## Card

```
You are adding one card, <Card Name>, to Content for /add-enemy-deck in the ModMox repo (/home/jackson/Projects/ModMox). Read CLAUDE.md, .claude/skills/add-card/SKILL.md, and the ledger at <ledger.json path>, which says which primitives this run has built (with their classes) and which are still missing.

1. Fetch the card and check it against the primitives the engine has now ($TOOL primitives). The triage may be out of date, because primitives have been built since then.
2. If anything is still missing, add nothing. Reply with BLOCKED, and for each missing primitive give its ledger name if the ledger already has it, or else a new short kebab-case name and a line on what it expresses. Stop there.
3. Otherwise add the card through add-card's steps 3 (write, compose, art) and 5 (review, then a PRINTED entry in tests/ui/cards/test_ability_text.gd). Give it a behavior test in tests/content/test_card_content.gd only when step 6 says it needs one. Run the card tests:
   GODOT=~/Desktop/Godot_v4.7.2-stable_linux.x86_64 tools/test.sh -gselect=test_ability_text
   GODOT=~/Desktop/Godot_v4.7.2-stable_linux.x86_64 tools/test.sh -gselect=test_card_oracle_data
   (and test_card_content, if you added a test there). Don't run the whole suite, edit docs/waiting_cards.md, or touch content/decks/: the orchestrator does those at the end.

You can't ask the user anything. If the card's play in a one-on-one encounter is unclear, or the review finds a wording you can't settle, reply with QUESTION and say what you need to know.

End your reply with one of these lines: DONE <card file path>, BLOCKED <names>, or QUESTION. Before it, give the tests you ran and how they came out.
```

## Primitive

First message:

```
You are building one missing primitive, "<name>" (<what it expresses>), for /add-enemy-deck in the ModMox repo (/home/jackson/Projects/ModMox). It blocks these cards: <card names, each with its Oracle text>. Read CLAUDE.md, .claude/skills/add-card/SKILL.md (step 4), addons/modmox_rules/docs/conventions.md, the ADRs that bear on it, and the ledger at <ledger.json path>.

Don't write any code yet. Draft add-card's step 4 proposal for this one primitive (class, folder and fields; the Oracle sentence; engine test scenarios; any ADR it touches; its AbilityText words; Reminders and a Keyword Icon if it is a keyword; the AI; any change to the card tool) and reply with it. The user will read it before anything is built. If the cards need it to be general in some way, say which card needs what. If it can't be built without another primitive that is missing too, say so and name that one.
```

After a yes, with `SendMessage` to the same subagent:

```
The user approved the proposal. Their words: "<the user's reply, quoted>". Build it test-first, as the conventions say, including the AbilityText words and any AI or card-tool change in the proposal. Don't add the cards: card subagents will. Run the tests you wrote and the folders you touched. Reply with the class path, a line on what it expresses, any ADR or glossary file you changed, and the tests you ran and how they came out.
```
