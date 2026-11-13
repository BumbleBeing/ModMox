# Rules Engine Code Conventions

How code in `addons/modmox_rules/` is written. The goal is that any part of the engine reads like every other part, so a change can be made by following the pattern next to it. The *why* behind the hard rules lives in the ADRs (`docs/adr/`). This file is the *how*.

## Vocabulary

- **American spelling everywhere**: code, comments, docs, test names and Content (`color`, `behavior`, `canceled`, `initialize`, `serialize`). Never British spellings.
- Use the terms in [GLOSSARY.md](../GLOSSARY.md) exactly, in class names, variables, comments and test names. Write `game_object`, never `entity` or `card` when an in-game object is meant.
- Use Comprehensive Rules vocabulary for everything the glossary does not cover (permanent, controller, owner, characteristic, priority).
- A new domain concept gets a glossary entry in the same change that introduces it.

## Files and folders

```
addons/modmox_rules/
  src/
    abilities/   ability kinds (spell, activated, triggered, static and its keywords)
    agents/      the Agent interface, the Encounter Driver and Simulation Sources
    actions/     Actions a player may take while holding priority
    cards/       Card Definitions, Run Cards, Modifications, card types, characteristics
    conditions/  Conditions (true or false questions about the game)
    core/        the engine facade, game state, players, zones, Game Objects, RNG
    costs/       cost parts, such as tapping
    decisions/   Pending Decisions and their kinds
    effects/     effects and the context they resolve in
    events/      the event pipeline and every event type
    filters/     Filters and their all-of, any-of and not combinators
    layers/      continuous effects and the layer engine
    mana/        mana units, mana costs, and the rules for paying them
    replacements/ replacement and prevention effects, and the rules for applying them
    rules/       game procedures: pregame, turns, casting, resolving, combat
    selections/  Selections: who or what an effect applies to
    targets/     Target Requirements
    triggers/    what triggered abilities wait for, detecting them, and pending triggers
    values/      Values (numbers worked out when needed)
    views/       per-player views of the game state
  tests/         mirrors src/ (tests/cards/, tests/core/, ...)
    support/     shared test helpers (preloaded, never class_name'd)
  docs/

addons/modmox_ai/  the AI Agent (ADR 0020): depends on the engine, never the other way round
  src/           one flat folder: the Agent, its planners, the Board Evaluator, Timing Tags
  tests/         AI tests, the benchmark and the soak test
    support/     shared AI test helpers (preloaded, never class_name'd)

content/cards/   game Content: authored Card Definitions (.tres), outside the engine
content/decks/   authored decks, saved as Player Setups (.tres)
content/art/     card art (one image per Card Definition) and its manifest, art.json
assets/          third-party art and fonts, each folder with its credits or license
ui/              the GUI (game-side): ui/cards/ draws Card Faces and Battlefield Faces,
                 ui/encounter/ is the Encounter Screen and its Presenter, ui/menu/ the main menu
docs/adr/        the game's own ADRs, numbered on from the engine's (0021 is the first)
tools/           developer tools: tools/art/ fetches card art, tools/card_gallery/ shows every card
tests/           game-side tests, mirroring ui/ and tools/ (tests/ui/cards/, tests/ui/encounter/, tests/tools/)
```

- One class per file. The file name is the class name in `snake_case`: `MmGameState` → `mm_game_state.gd`, `ZoneChangeEvent` → `zone_change_event.gd`.
- Put a new class in the folder for its domain. Create a new folder only when a new domain appears, such as `filters/` when the first Filter is needed.
- Author Content `.tres` files in the Godot editor, or generate them with `ResourceSaver`, never by hand-writing the file format.

## Naming classes

- **`Mm` prefix** only for the engine's core classes and the generic base classes (ADR 0005): `MmEngine`, `MmGameState`, `MmPlayer`, `MmZone`, `MmGameObject`, `MmEncounterSetup`, `MmPlayerSetup`, `MmCardDefinition`, `MmRunCard`, `MmPendingDecision`, `MmEvent`, `MmModification`, `MmCharacteristics`, `MmCardTypes`, `MmMana`, `MmManaCost`, `MmReference`, `MmSelection`, `MmEffectContext`, `MmRng`, `MmTurn`, `MmAction`, `MmPlayerView`, `MmObjectView`, `MmEffect`, `MmFilter`, `MmValue`, `MmAbility`, `MmCost`, `MmCombat`, `MmTrigger`, `MmCondition`, `MmContinuousEffect`, `MmReplacementEffect`.
- **Specific subclasses** have no prefix and end with their base kind: `ChangeNameModification`, `ZoneChangeEvent`, `KeepOrMulliganDecision`, `DealDamageEffect`, `CreatureFilter`, `CountValue`, `ModifyPowerToughnessContinuousEffect`.
- Test files and test helpers never declare `class_name`.
- Never reuse a name Godot already has as a built-in type or class (`Color`, `Rect2`, `Timer`, ...), even inside a class. It fails to compile. That is why the color enum is `MmCardTypes.CardColor`.

## Naming members

- `snake_case` for variables and functions, `PascalCase` for enums, `CONSTANT_CASE` for constants and enum values.
- Private members start with `_`. Nothing outside a class touches its `_` members, including tests.
- Booleans read as questions: `is_tapped`, `has_kept`, `can_mulligan`.
- Functions are verbs (`draw_cards`, `characteristics_of`); properties are nouns.
- No abbreviations except `id`, `rng` and `gui`. Write `object`, not `obj`. Write `definition`, not `def`.

## Static typing

- Every variable, parameter, return value, loop variable and constant has an explicit type: `var count: int = 0`, not `var count := 0`. Untyped declarations fail to compile (ADR 0005). The one exception is `const Name := preload("...")`, where the inferred script type is more useful than `GDScript`.
- Use typed collections: `Array[MmGameObject]`, `Dictionary[int, MmGameObject]`.
- `Variant` is allowed only where data is genuinely open-ended, such as a Pending Decision's answer. Say why in a comment.
- **Enums that end up in saved files get explicit values and are append-only.** `.tres` files store enum values as plain numbers, so reordering `CardType` would silently turn every saved Land into something else. Write `LAND = 4`, never change or reuse a value, and add new values at the end. This applies to every enum used by an `@export` property.
- **`@export` defaults are part of the save format too.** Godot leaves a property out of a `.tres` file when it equals the default, so Lightning Bolt's "creature" filter is saved with no card type at all. Changing a default would silently change every card relying on it. Never change the default of an `@export` property once Content exists; add a new property instead. Content tests check what cards *do*, not just their fields, to catch this.

## Class layout

Follow the Godot style guide order:

1. `class_name`, then `extends`
2. `##` doc comment saying what the class *is*, in domain terms
3. signals (the engine has none; see below), enums, constants
4. `@export` properties, then public properties, then private properties
5. `_init`, then public methods, then private methods

## Comments

- Every class and every public method has a `##` doc comment.
- Copyable classes (the game state and the procedures) provide a `duplicate_*()` or `copy_for()` method. A new field must be copied there too, or undo will silently lose it.
- When code implements a rule, cite it: `# CR 103.5: each player decides in turn order.`
- When code exists because of an ADR, cite it: `# ADR 0008: a zone change creates a new object.`
- When code deliberately leaves out a rule until a later milestone, leave a `# Later (milestone N):` note saying what is missing.
- Comments explain *why*. Don't narrate what the next line does.

## Hard rules for engine code

These are what keep the engine predictable. A violation is a bug even if the tests pass.

1. **State changes only through events (ADR 0007).** Rules code builds an `MmEvent` and calls `MmGameState.perform(event)`. Only an event's `apply` method may call a mutating method on a zone, player or object. Effects never perform anything: `next_batch()` returns the events of each step, and its numbers come from `numbers()`, worked out once as the effect begins (ADR 0019). Code that may need a replacement choice performs with `perform_resumably()`, then stops and returns `replacement_decision()` while `is_batch_suspended()`, and carries on from where it was once the choice is answered. Everything else uses `perform()` or `perform_together()`, which assert that no choice was needed.
2. **Characteristics only through the query (ADR 0009).** Ask `MmGameState.characteristics_of(object)`. Never read `object.definition.<field>` in rules code.
3. **Players are relative (ADR 0005).** Rules code says controller, owner, active player or opponent of. `hero()` and `villain()` exist only on the engine facade, for setup and presentation.
4. **Randomness only from the Game RNG (ADR 0006).** No `randi()`, `randf()`, `randomize()`, `Array.shuffle()` or `Array.pick_random()`. No reading the clock (`Time`, `OS.get_ticks_*`). A test scans `src/` for these.
5. **Deterministic iteration.** Iterate in a defined order (turn order, zone order, ascending ID). Never let the result depend on hash order or object instance IDs.
6. **No `await`, no signals, no Nodes (ADR 0003).** The engine runs until it needs a decision and then returns. The event log is how the outside world learns what happened.
7. **Never mutate a loaded Resource.** Card Definitions and Run Cards from disk are read-only at runtime. Flattening works on a `duplicate_deep()` copy (ADR 0004).
8. **Effects never hold targets (ADR 0014).** Every effect names who or what it affects through a Selection.
9. **Identity by ID.** References to Game Objects and players are by their integer IDs in anything that is stored, logged or answered. A changed ID means a different object (ADR 0008).
10. **No strong reference cycles.** Engine classes are `RefCounted`, and two objects holding each other are never freed. When a child needs to reach its owner (a Game Object finding its zone), the child holds a `WeakRef` behind a typed accessor, as in `MmGameObject.zone()`. The test run must end without "ObjectDB instances were leaked".

## Errors

- **Bad input from outside** (an illegal decision answer, an invalid setup) is expected: return a reason string or result, leave the state unchanged, and never "fix" the input.
- **Broken engine invariants** are programmer errors: `assert()` with a message, or `push_error()` where execution must continue.

## Tests

- Test-first: write the failing scenario, then the code (roadmap).
- Mirror `src/`: `src/core/mm_zone.gd` is tested in `tests/core/test_mm_zone.gd`. Rules behaviors that span classes go in a file named for the behavior, such as `tests/rules/test_mulligans.gd`.
- Test names describe the behavior in words: `test_london_mulligan_with_one_free_mulligan_keeps_six`.
- Tests go through the public API (the `MmEngine` facade where possible) and check the outcome: the state, the views and the event log.
- Arrange, act, assert, separated by a blank line. Build scenarios with `tests/support/` helpers rather than repeating setup code.
- Name the rule being tested in the test's comment when there is one.
- Give private test helpers descriptive names (`_pass_priority`, not `_pass`). `GutTest` defines its own `_pass`, `_fail` and similar methods, and a helper with the same name silently replaces them.
- When a scenario needs particular cards in hand, find a seed that deals them with `Scenario.find_engine()`. Never bypass the shuffle.
- Drive a game forward with `Scenario.autoplay()` and its shortcuts (`keep_all`, `play_until_game_turn`, `play_until_step`) rather than submitting long answer lists by hand.
- Play an encounter to its end with `Scenario.play_until_over()`.
- Get permanents onto the battlefield on the first two turns and stop at any later step with `Scenario.permanents_ready_with()`. Let everything on the stack resolve with `Scenario.resolve_stack()`.
- Set up a combat with `Scenario.combat_ready()`: free creatures cast on the first two turns, stopped at the Hero's attackers decision. Cast a card that has a cost for free in a scenario with `Scenario.free_copy()`. A free copy is colorless, because color comes from the mana cost, so a test that needs a colored source pays real mana or uses a Filter on something else, such as a subtype.
- Activate an ability with `Scenario.activate()`, reach a replacement choice with `Scenario.pass_to_replacement_choice()`, and answer it by its source card with `Scenario.choose_replacement_from()`.
- Put "target spell" on a card with `Scenario.target_spell()` and counter with `Scenario.counter()` or a `Scenario.free_counter()`; `Scenario.stack_ids()` lists the stack top first. A creature spell is cast at sorcery speed, so cast it before anything else when a test needs it on the stack.
- Anything leaving the stack is an undo barrier (ADR 0015), so a test can undo casting a counter but never the countering.
- Put "target card in a graveyard" on a card with `Scenario.target_graveyard_card()` (`your_dead_creature()` for a creature card in its controller's) and "target activated or triggered ability" with `Scenario.target_ability()`; `free_raise()` and `free_stifle()` are the two as instants costing {0}, and `card_in_graveyard()` finds a card by name. A free raise is an instant, unlike Raise Dead, so that one can answer another.
- A card that changes zones is a new object, so find it again after every move: `card_in_graveyard()` after it dies, the hand after it returns.
- The engine asks which replacement effect applies first only when the effects differ: two shields with the same amount left are applied without asking, so give them different amounts.

## The AI addon

`addons/modmox_ai/` follows every rule above, with these differences:

- Classes take the **`Ai` prefix** (`AiAgent`, `AiProfile`, `AiBoardEvaluator`), never `Mm`.
- **The AI never reads the real game state** (ADR 0020). It reads its Player View, the decision, and its World from the Simulation Source, and may read Simulation Copies freely. Never keep or pass on a reference to an `MmEngine` that is not a Simulation Copy.
- **Randomness only from the AI RNG** (ADR 0006), taken once per decision from `MmSimulationSource.ai_rng()`. Compare candidates on the same re-dealt world by giving every candidate's copy the same seed.
- **Budgets are counts, never time** (A159). The clock may only produce a warning about a slow decision. A test scans `src/` for both.
- **A FULL Agent may simulate; a CHEAP one never does** (A178). Anything run inside a simulation must use CHEAP Agents.
- **Search budgets belong to `AiDifficulty`; temperament belongs to `AiProfile`** (A195). A profile only scales the difficulty's samples, by `search_budget_percent`. Scale a sample count with `AiDifficulty.scaled()`, which never returns less than one.
- **No card names and no authored hints.** Work out what a card does from its characteristics and effects, so a Modification that rewrites a card changes how the AI plays it.
- A `Callable` to a method does not keep its object alive. Hold the object in a variable for as long as the Callable is used.
- `pass` is a GDScript keyword and cannot name a variable.

## Agents in tests

- In GUI tests, drive an encounter through `EncounterPresenter` with a test Agent for the Villain, and call `wait_until_idle()` after each answer. `tests/ui/encounter/support/` has `slow_agent.gd` (takes 300 ms, records its thread) and `responding_agent.gd` (answers the Hero's first spell with one of its own). To know what is hidden from the Hero, start a second engine from the same setup: the same seed deals the same cards.
- The presenter passes for the Hero whenever their own spell or ability goes on top of the stack, even with auto-pass off. A GUI test that needs something to stay on the stack sets `is_hold_key_down` first, and sets it only once everything that should resolve has. With the key down nothing at all is passed for the Hero, auto-pass and a Yield included, so a test that leaves it down is asked at every priority.
- **Whatever passes for the Hero is decided in `_passes_for_hero()`, and the Hold Key is checked last, once a pass is due.** A new reason to pass goes before that check, never after it. `AutoPass` holds the rules themselves (`passes()`, `yields()`), which are tested without a presenter.
- A free copy of an authored card has no file behind it, so it has no art. Use the authored card when a picture matters.
- After adding a test file, check the run printed exactly one `SCRIPT ERROR` (the one `test_static_typing` expects). A test file that fails to parse is skipped without failing the run.
- Drive a whole encounter with `MmEncounterDriver` and test Agents from `tests/support/`: `default_answer_agent.gd` answers like `Scenario.autoplay()`, and `illegal_answer_agent.gd` never answers legally. `Scenario.default_answer()` gives autoplay's answer to any one decision.
- In AI tests, `AiScenario.ask()` gets an Agent's answer to the pending decision without submitting it, and `AiScenario.ready_with()` sets up both battlefields, with an optional starting life for the Villain.
- A free copy has mana value 0, so the Board Evaluator values it as a card costing nothing. Use real cards and lands when a test depends on what a card in hand is worth.
- A flying attacker that no creature can block gets no blockers decision at all, so check that none is asked rather than waiting for one.
- `AiAgent.new()` plays at Normal, with Flat Monte Carlo. A test about one-step simulation's own reasons (`BEST_SCORE`, `SCORES_WORSE_THAN_PASS`) uses `AiDifficulty.easy()`. `rollout_count()` says how many Rollouts the last answer played.
- The hand in an `AiScenario.ready_with()` setup holds every copy its cycled deck dealt, so count Monte Carlo candidates from `explain_detail()` rather than assuming one per card named.
- A whole encounter takes seconds at Easy and much longer at Normal. Slow checks run at Easy by default, and only on request at other levels: the soak with `MODMOX_SOAK_DIFFICULTY`, tournaments with `MODMOX_TOURNAMENT_SEEDS` (see `test_tournament.gd`). A tournament can be split across processes with `MODMOX_TOURNAMENT_FIRST_SEED`.

## Game-side code

`ui/` and `tools/` follow every rule above that is not about the engine's internals, with these differences:

- Classes have **no prefix** and end with their kind where they have one: `CardFace`, `FrameSpec`, `FrameBaker`, `KeywordChips`.
- **The GUI reads only what a player may see** (ADR 0005): a Player View in an encounter, printed characteristics outside one. Both become a `CardLook`, which is all a face is drawn from, so a deck screen and the battlefield draw an unaffected card the same way (ADR 0009).
- **Nodes, signals and `await` are fine here.** They are banned only in the engine.
- **Keep what can be tested headless out of Nodes.** Work out frames, layouts, crops and fits in pure static functions or `RefCounted` classes, and test those. Nodes only place what they work out.
- **Images the code composites are imported as `Image`**, not textures (set `importer="image"` in their `.import` file), so baking works headless and tests can check real pixels. Images that are only drawn import as textures, with mipmaps. Pixel art is the exception: it imports without mipmaps (`mipmaps/generate=false`) and is drawn with `TEXTURE_FILTER_NEAREST`, at whole multiples of its size.
- **Never change a loaded `Image`.** Resize or edit a `duplicate()`.
- **Never author rules text (ADR 0023).** `AbilityText` generates it from abilities. A new effect, cost, trigger, filter, selection, value or keyword gets its words there in the same change, with a line in `test_ability_text.gd`; until it does, it prints as its class name in square brackets and the test over every authored card fails.
- **A decision answered all at once keeps its half-made answer on the screen, outside the redrawn nodes**, in a pure class with `covers()`, `is_for()`, `is_active()`, `answer()` and `undo()`: `CombatSelection` for combat, `TriggerOrder` for triggers, `CardPicks` for cards put on the bottom or discarded. The pass button confirms it (the overlay's own Confirm button for cards put on the bottom) and undo takes back one step of it before anything else.
- **Something drawn on a face for a moment is a child of that face and is taken off again**, as a Stack Mark is. Whatever marks a player's portrait must be cleared at the start of a redraw, because the portrait is not redrawn.
- **Pixel icons come from `tools/sprites/build.sh`**: each set is a text grid (`tools/sprites/keyword_icons.txt`) that the script turns into an `.aseprite` file and a PNG for each icon, and a contact sheet in `tools/sprites/preview/`. Once an `.aseprite` file is edited by hand it is the source of truth; the script keeps it and only exports its PNG again, unless told `--force`.
- **Card art comes from `tools/art/fetch_art.gd`**, never by hand: it downloads the first printing's art for any card without it and records its credits in `content/art/art.json`. Set focus points with the card gallery tool.
- **Only the Encounter Presenter touches the engine** (ADR 0021). Nothing else in `ui/` or `tools/` may mention `MmEngine`, `MmGameState` or `MmEncounterDriver`; a test scans for them. A screen draws from the snapshot it was handed, and asks the presenter to answer, pass, undo, cancel or concede.
- **Never read the engine while the Villain is thinking.** Its Agent runs on a worker thread that is changing the game. The presenter makes its snapshot before starting the task and refuses commands until it has finished; new presenter code must keep that order.
- **An effect on a thing's border is a child of that thing** (`BorderEffects`): the Glow, a pointer outline, anything later. It then turns, moves and resizes with a fanned or tapped card. Never draw one beside its host from a remembered rectangle.
- **What a click answers is worked out in `DecisionClicks`, and nowhere else** (ADR 0022). The Glow is drawn from the same object. A new input for a decision kind adds its answers there, with tests. An object has every kind of thing it offers (`kinds_of()`), and its Glow the colors of the first two (`colors_of()`): draw a Glow that may have two with `BorderEffects.add_glow_of()` or `set_glow_of()`, and read it with `glow_colors()`.
- **Every kind of decision the engine can ask is listed in `DecisionInputs`**, beside what answers it. `test_decision_inputs.gd` scans the engine's decision classes and fails when one is not listed, so a new kind cannot ship with nothing to click: there is no Debug Decision Panel any more for it to fall through to. `InfoPrompt` raises an error for a decision no input covers.
- **A decision answered all at once is built in a selection** (`CombatSelection`, ADR 0022). Its clicks change the selection and redraw; only the confirm button answers. The screen holds the selection, never a node it redraws, and replaces it only when the decision itself changes. A new input of this kind follows the same shape: a pure class with `click`, `undo`, `is_complete` and `answer`.
- **A handler for the cursor leaving a thing must do nothing while that thing is being removed.** Taking a node from under the cursor emits `mouse_exited` in the middle of `remove_child()`, and adding or removing a child of it then is an error Godot prints on every real click. Guard such a handler with a flag set around the removal and check `is_inside_tree()`, or better, have no handler on what is rebuilt. Only a test through the real input pipeline, with the cursor resting on the thing before the click, shows it.
- **Where things overlap and one is drawn in front, work out what the cursor is on yourself.** Godot picks by the order of the nodes; `z_index` changes what is drawn in front and nothing about what takes the mouse. The opening-hand overlay makes its cards ignore the mouse, every part of them, and finds the card from where each is drawn (`card_at()`): the one already under the cursor first, then the one on top. A `CardFace` builds some of its parts on entering the tree, so they are told to ignore the mouse after `add_child()`, never before.
- **Ask where the cursor is each frame; do not wait for it to move.** The overlay's hover is worked out in `_process()` from `gui_get_hovered_control()` and `get_local_mouse_position()` (`follow_cursor()`), as the hand's spread is. Motion events pushed into a test viewport never reached the overlay's `_gui_input()` although presses did, and the reason was not found; asking each frame works in a test and under a real mouse, and also finds what slides under a cursor that is resting.
- **`ease` is a built-in function.** A method cannot be called that; the script fails to parse (`ease_cards()`).
- **What is placed by hand eases; what a container places snaps.** The triggers being ordered are children of a plain Control (`TriggerList`) that sets each one's place every frame, so they ease to a new order and one can be held outside its slot. Do not put something that must ease, or be dragged, in a `VBoxContainer`.
- **A click on a card of the hand is a press let go where it was made**, counted in `release_hand()`, so it can never take a drag away: a press that moves three pixels is a drag whatever the decision. It means something only while cards are being chosen to discard (`_click_hand()`).
- **A thing takes the mouse only through a `ClickCatcher`.** Faces and panels are made ignoring the mouse; the screen adds a catcher to each one that has an answer. Never set a face's own `mouse_filter` to take clicks, and never show an error for a click on something that answers nothing.
- **Anything that opens over the board closes on a redraw** (the Option Menu), because the board it was opened on is gone. State that must outlive a redraw lives outside the redrawn nodes.
- **The board is still rebuilt from every snapshot; Face Motion makes it move** (ADR 0027). Draw a permanent's face at its place as before and let `_move_faces()` hand that place to the `FaceMotion`. Never tween a redrawn node yourself: the next redraw frees it. Anything that must be read from where a face *belongs*, such as whether it is scrolled out of sight, uses its place (`_rest`), and anything drawn to where it *is*, such as a block line, uses `_drawn_rect()`.
- **Pacing and Face Motion are off unless the screen turns them on** (`use_game_pace`). A presenter or screen made in a test waits for nothing and moves nothing, so a test reads a face at its place straight after a redraw. A test of motion sets `face_motion().seconds` and steps time with `advance_motion()` in frames of a hundredth of a second; a test of Pacing hands the presenter its own `clock` and waits for `is_villain_answer_ready()` before it polls.
- **A card that changes zones flies; never fade it yourself** (ADR 0027). `CardFlights` works out the routes from the snapshot's zone-change events and the screen draws a `FlightCard` for each. A new zone, or a new place a zone is drawn, gets its place in `_flight_place()`, which reads what is on the screen right now. Whatever a card lands on is remembered in `_faces` by its object ID, so that it shows nothing until the card arrives. A test of flights sets `card_flights().seconds`, turns the screen's own `_process` off so that waiting a frame lets no time go by, and steps time with `advance_motion()`.
- **The opening-hand overlay's cards are placed every frame from `OpeningMotion`** (ADR 0030), never tweened: the overlay rebuilds them on each redraw, and `_pose_cards()` puts each where its move has got to, the card under the cursor higher and larger. A pose's center there is the middle of the card's bottom edge. A test of these moves turns the overlay's own `_process` off as well as the screen's, sets `opening_overlay().motion().seconds`, and steps time with `advance()` and `ease_cards()`; a snapshot rebuilds the overlay, so take a node from it only after the press that causes one.
- **A button that should look made is shaded with `ButtonShading.apply()`**, after its size is set: the box is painted for that height. So far only the overlay's buttons are.
- **Every time the game waits or moves goes through `GameSpeed`** (`_apply_speed()` on the screen). A new wait or move gets its number in `Pacing` and its line there, so that every Game Speed scales it and a screen that is not paced never has it.
- **A presenter pays nothing for the Hero until it is told to** (`set_auto_tapping()`, ADR 0031). Auto-tap is on for a player, from the settings, and off in a presenter a test makes, so a test that casts through a presenter still pays by hand. A new thing the presenter does for the Hero follows the same shape: off in the presenter, on in `GameSettings`, given to the presenter in `use_settings()`.
- **What the Tap Preview shows is asked of the presenter, a plan at a time** (`payment_plan(answer)`). It is the one thing the screen reads that is not in the snapshot, because working out every plan for every snapshot cost a frame or two. Never work a plan out any other way than by paying on a copy of the game with the planner that then pays: a second rule would let the preview disagree with the payment.
- **The preview changes Glows on the faces that exist** (`follow_preview()`), and a redraw draws it again from `_previewed`. A new kind of thing the cursor can ask about gets its answer in `_hovered_answer()`, worked out from where things are drawn, never from `gui_get_hovered_control()`, which is stale on a board just rebuilt.
- **A screen made in a test reads and saves no settings.** `settings_path` is empty unless the screen starts itself; a test of settings gives it a file of its own under `user://` and removes it afterwards.
- **Never put a character the game's font lacks on something that is built or restyled often.** Open Sans has no "◀", "▲", "☑", "⛨" or "→"; Godot finds each in a fallback font, and that takes about a millisecond every time the text is laid out, with several layouts for each build. Eight such arrows were a third of every redraw. Draw the shape (`ScrollRow.arrowhead()`), or keep the node and leave its text alone. A dash, an ellipsis, "−", "×" and "·" are in the font and cost nothing.
- **The player panels are built once and updated, unlike the board.** `PlayerPanel.show_snapshot()` changes only what shows differently, and restyles a button only when its look changes. A new thing on a panel is made in `_build()` and given its state in `show_snapshot()`. Whatever the screen draws on a portrait is cleared by the panel on the next snapshot.
- **Measure a redraw before and after touching it.** A redraw of a mid-game board should take well under a frame: about 7 ms at the median in play (it was 44 ms before the two rules above). Building a Card Face or a Battlefield Face costs 0.1 to 0.2 ms; a `Button` with text and four style overrides costs about the same; anything that costs a whole millisecond is worth a look.
- **Nothing is rebuilt while a card is held** (ADR 0022). A redraw takes several milliseconds, and took 40 when this rule was made, which under the cursor is a stutter. Between pickup and release, move nodes that exist (`_lift`, `_lay_out_hand`, `_put_down`); never call `_redraw()` because the cursor moved. A redraw that the game causes mid-drag draws the held card again from the `DragCard`.
- **A card in hand has play options, not click options.** `DecisionClicks.hand_options_of()` says how a card can be cast or played, and then any ability it has that is used from the hand; `options_of()` stays empty for it, so it gets no `ClickCatcher` and one click does nothing. The hand's cards are known by Card Identity (`card_id`), never by object ID, which changes when a card leaves the hand and comes back.
- **The screen never takes a mouse press in `_unhandled_input()`.** The screen is a Control that stops the mouse, so a press is used up there and `_unhandled_input()` never sees it; only keys arrive that way. A press on the empty board is taken in `_gui_input()`, which only gets a press that no window, button or `ClickCatcher` took. The first build of 13e-1 passed every test and did nothing under a real mouse, because its tests called the handler directly.
- **A press on a card of the hand is taken in `_input()`, before anything under the card.** A card that rises under the cursor lies over the Hero's lands, and a land's `ClickCatcher` would take a press on the card's top edge, which is where a card is grabbed. Whatever is drawn over the hand still comes first: a new window or menu that can cover the hand must be added to `_is_covered()`, as the opening-hand overlay is while it is open and not fading away.
- **Every new mouse input gets one test through the real pipeline.** Open the screen in a `SubViewport` and `push_input()` the events (`_open_in_a_viewport()` in `test_screen_hand.gd`): Godot then picks what is under the mouse itself, clear of the test runner's own windows. Calling `press_hand()` or `_gui_input()` proves what the handler does, never that the event gets to it.
- **A press is tested against where the cursor is sending a thing, not only where it is drawn.** Whatever eases toward the cursor is drawn late, and later still in a slow frame, so a press made on arriving would miss it (`hand_card_at()` accepts both places). For the same reason easing takes its weight from the frame's length (`EncounterLayout.ease_weight()`), never a fixed share per frame.
- **Never let a double-click swallow a press.** Two quick tries at a drag arrive as a double-click. Where a double-click has nothing to do, it is a press like any other.
- **A test drags with `press_hand()`, `drag_to()` and `release_hand()`**, in the screen's coordinates. A card that was just put down is still easing to its place, so step the hand (`_spread_hand(0.3)` a few dozen times) before pressing a card again. The same goes for a trigger: after a real drag, wait for the list to ease before pressing where an entry will be, and in a viewport take the cursor off the hand before working out where a card rests, because the hand parts around wherever the cursor last was.
- **A test that hovers through the real pipeline takes the cursor away again before it ends**, and waits a few frames. Whatever the hover put on a face is taken off with `queue_free()` when the cursor leaves, and a test that ends first reports it as an orphan.
- **Pausing means the presenter stops collecting**, not that anything is stopped. Screen code that acts on the encounter checks `is_paused()` first; the presenter refuses the Hero's answers while paused whatever the screen does.
- **Set a `Label`'s `autowrap_mode` before its text and size**, and do not combine it with `clip_text`: a wrapped label set up in the other order grows as wide as its longest line, and a clipped one loses every line after the first.
- **A redraw frees what it replaces with `queue_free()`**, never `free()`, because the redraw is often running inside a signal from one of the nodes being replaced. A test that redraws waits two frames in `after_each()` so nothing is left as an orphan.
- **Scenes that lead elsewhere take a `navigate` Callable** (and `quit`, for the menu), which a test replaces, so a test never changes the running scene.
- **A pile's window is a `PileWindow`, filled when it opens** (ADR 0032). A redraw fills only the ones that are open, and `show_cards()` rebuilds nothing unless what it shows has changed, so a closed window costs a redraw nothing. A new kind of zone to look into gets an arrangement there, never a list of faces built by the screen.
- **Which pile windows the game opened is kept in `PileWindows`**, outside the redrawn nodes. `DecisionClicks.piles()` says which piles hold an answer and `is_only_in_piles()` whether nothing on the board answers; a new zone a decision can reach is found there (`_find_piles()`), and its window then opens, glows and closes by the same rules.
- **A player is named through `PlayerNames`, from the snapshot** (`snapshot.names`). Never write "Hero" or "Villain" into text the player reads: use `of()` for a label, `the()` or `starting()` in a sentence, and `possessive()` for a title. A pure class that words things takes the names as its last, optional argument, so a test that does not care gets the parts.
- **A test may show the screen a decision the engine cannot ask yet** by changing a snapshot's `decision` and emitting the presenter's `changed` with it. Use it only to test how something is drawn; nothing it leads to can be answered.
- **Cards are found in every set's folder under `content/cards/`**, not only `alpha/`. A card that is not from Alpha goes in a folder named for its first set.
- **The Inspector draws what it is handed** (ADR 0033). A card's Original, its Rarity and a permanent's State List are made by the presenter and carried on the snapshot. A new thing to say of a permanent is a new entry in `StateList`, with a test; the Inspector is not touched. A new keyword gets its sentence in `Reminders` in the same change as its Keyword Icon, with no mana or tap symbols, because a plain label draws it.
- **What a right-click pins is found in `inspectable_at()`**, from where things are drawn, as `_hovered_answer()` is. A new place a known card is drawn, such as a new window, is added there and to `_pin_host_now()`, so that it can be pinned and ringed. Never give a face a click handler for it. Hovering shows nothing in the Inspector (A472).
- **Which card is pinned is kept in `Inspection`**, outside the redrawn nodes. The screen tells it of right-clicks; it knows nothing of nodes. A test of it through the screen calls `right_click_at()`, and the real pipeline is tested once with `push_input()`.
- **A Backdrop is made by `Backdrops.make()` from its name, and the screen never dims or fits one itself** (ADR 0035). A picture is 320 × 180, goes in `ui/sprites/backgrounds/Encounters/` as `<name>.png`, and then replaces that name's placeholder with no code changed; a new Backdrop is a new name in `Backdrops.NAMES` with a picture or a `kind` in the shader. The game is always drawn at 1920 × 1080 and scaled (stretch aspect `keep`), so nothing new needs to handle another shape of screen.
- **Every sub-milestone of the GUI starts with a throwaway prototype** in `prototypes/<sub-milestone>/`, which the user signs off on. Prototypes skip these conventions and tests, and are deleted when the real build lands.

## Formatting

- Tabs for indentation (Godot default). Two blank lines between functions.
- Lines up to about 100 characters. Break long calls after an opening parenthesis.
- Use `"double quotes"` for strings.
