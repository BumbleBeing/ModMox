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
- **Pixel icons come from `tools/sprites/build.sh`**: each set is a text grid (`tools/sprites/keyword_icons.txt`) that the script turns into an `.aseprite` file and a PNG for each icon, and a contact sheet in `tools/sprites/preview/`. Once an `.aseprite` file is edited by hand it is the source of truth; the script keeps it and only exports its PNG again, unless told `--force`.
- **Card art comes from `tools/art/fetch_art.gd`**, never by hand: it downloads the first printing's art for any card without it and records its credits in `content/art/art.json`. Set focus points with the card gallery tool.
- **Only the Encounter Presenter touches the engine** (ADR 0021). Nothing else in `ui/` or `tools/` may mention `MmEngine`, `MmGameState` or `MmEncounterDriver`; a test scans for them. A screen draws from the snapshot it was handed, and asks the presenter to answer, pass, undo, cancel or concede.
- **Never read the engine while the Villain is thinking.** Its Agent runs on a worker thread that is changing the game. The presenter makes its snapshot before starting the task and refuses commands until it has finished; new presenter code must keep that order.
- **An effect on a thing's border is a child of that thing** (`BorderEffects`): the Glow, a pointer outline, anything later. It then turns, moves and resizes with a fanned or tapped card. Never draw one beside its host from a remembered rectangle.
- **What a click answers is worked out in `DecisionClicks`, and nowhere else** (ADR 0022). The Glow is drawn from the same object. A new input for a decision kind adds its answers there, with tests, and deletes that kind's Debug Decision Panel form.
- **A decision answered all at once is built in a selection** (`CombatSelection`, ADR 0022). Its clicks change the selection and redraw; only the confirm button answers. The screen holds the selection, never a node it redraws, and replaces it only when the decision itself changes. A new input of this kind follows the same shape: a pure class with `click`, `undo`, `is_complete` and `answer`.
- **A thing takes the mouse only through a `ClickCatcher`.** Faces and panels are made ignoring the mouse; the screen adds a catcher to each one that has an answer. Never set a face's own `mouse_filter` to take clicks, and never show an error for a click on something that answers nothing.
- **Anything that opens over the board closes on a redraw** (the Option Menu), because the board it was opened on is gone. State that must outlive a redraw lives outside the redrawn nodes.
- **Pausing means the presenter stops collecting**, not that anything is stopped. Screen code that acts on the encounter checks `is_paused()` first; the presenter refuses the Hero's answers while paused whatever the screen does.
- **Set a `Label`'s `autowrap_mode` before its text and size**, and do not combine it with `clip_text`: a wrapped label set up in the other order grows as wide as its longest line, and a clipped one loses every line after the first.
- **A redraw frees what it replaces with `queue_free()`**, never `free()`, because the redraw is often running inside a signal from one of the nodes being replaced. A test that redraws waits two frames in `after_each()` so nothing is left as an orphan.
- **Scenes that lead elsewhere take a `navigate` Callable** (and `quit`, for the menu), which a test replaces, so a test never changes the running scene.
- **Every sub-milestone of the GUI starts with a throwaway prototype** in `prototypes/<sub-milestone>/`, which the user signs off on. Prototypes skip these conventions and tests, and are deleted when the real build lands.

## Formatting

- Tabs for indentation (Godot default). Two blank lines between functions.
- Lines up to about 100 characters. Break long calls after an opening parenthesis.
- Use `"double quotes"` for strings.
