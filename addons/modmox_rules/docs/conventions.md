# Rules Engine Code Conventions

How code in `addons/modmox_rules/` is written. The goal is that any part of the engine reads like every other part, so a change can be made by following the pattern next to it. The *why* behind the hard rules lives in the ADRs (`docs/adr/`). This file is the *how*.

## Vocabulary

- Use the terms in [GLOSSARY.md](../GLOSSARY.md) exactly, in class names, variables, comments and test names. Write `game_object`, never `entity` or `card` when an in-game object is meant.
- Use Comprehensive Rules vocabulary for everything the glossary does not cover (permanent, controller, owner, characteristic, priority).
- A new domain concept gets a glossary entry in the same change that introduces it.

## Files and folders

```
addons/modmox_rules/
  src/
    cards/       Card Definitions, Run Cards, Modifications, characteristics
    core/        the engine facade, game state, players, zones, Game Objects, RNG
    events/      the event pipeline and every event type
    decisions/   Pending Decisions and their kinds
    rules/       game procedures (pregame, and later turn structure, combat, ...)
    views/       per-player views of the game state
  tests/         mirrors src/ (tests/cards/, tests/core/, ...)
    support/     shared test helpers (preloaded, never class_name'd)
  docs/
```

- One class per file. The file name is the class name in `snake_case`: `MmGameState` → `mm_game_state.gd`, `ZoneChangeEvent` → `zone_change_event.gd`.
- Put a new class in the folder for its domain. Create a new folder only when a new domain appears, such as `effects/` in milestone 5.

## Naming classes

- **`Mm` prefix** only for the engine's core classes and the generic base classes (ADR 0005): `MmEngine`, `MmGameState`, `MmPlayer`, `MmZone`, `MmGameObject`, `MmEncounterSetup`, `MmPlayerSetup`, `MmCardDefinition`, `MmRunCard`, `MmPendingDecision`, `MmEvent`, `MmModification`, `MmCharacteristics`, `MmRng`, `MmPlayerView`, `MmObjectView`, `MmEffect`, `MmFilter`, `MmValue`, `MmAbility`, `MmCost`.
- **Specific subclasses** have no prefix and end with their base kind: `ChangeNameModification`, `ZoneChangeEvent`, `KeepOrMulliganDecision`, `DealDamageEffect`, `CreatureFilter`, `CountValue`.
- Test files and test helpers never declare `class_name`.

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

## Class layout

Follow the Godot style guide order:

1. `class_name`, then `extends`
2. `##` doc comment saying what the class *is*, in domain terms
3. signals (the engine has none; see below), enums, constants
4. `@export` properties, then public properties, then private properties
5. `_init`, then public methods, then private methods

## Comments

- Every class and every public method has a `##` doc comment.
- When code implements a rule, cite it: `# CR 103.5: each player decides in turn order.`
- When code exists because of an ADR, cite it: `# ADR 0008: a zone change creates a new object.`
- When code deliberately leaves out a rule until a later milestone, leave a `# Later (milestone N):` note saying what is missing.
- Comments explain *why*. Don't narrate what the next line does.

## Hard rules for engine code

These are what keep the engine predictable. A violation is a bug even if the tests pass.

1. **State changes only through events (ADR 0007).** Rules code builds an `MmEvent` and calls `MmGameState.perform(event)`. Only an event's `apply` method may call a mutating method on a zone, player or object.
2. **Characteristics only through the query (ADR 0009).** Ask `MmGameState.characteristics_of(object)`. Never read `object.definition.<field>` in rules code.
3. **Players are relative (ADR 0005).** Rules code says controller, owner, active player or opponent of. `hero()` and `villain()` exist only on the engine facade, for setup and presentation.
4. **Randomness only from the Game RNG (ADR 0006).** No `randi()`, `randf()`, `randomize()`, `Array.shuffle()` or `Array.pick_random()`. No reading the clock (`Time`, `OS.get_ticks_*`). A test scans `src/` for these.
5. **Deterministic iteration.** Iterate in a defined order (turn order, zone order, ascending ID). Never let the result depend on hash order or object instance IDs.
6. **No `await`, no signals, no Nodes (ADR 0003).** The engine runs until it needs a decision and then returns. The event log is how the outside world learns what happened.
7. **Never mutate a loaded Resource.** Card Definitions and Run Cards from disk are read-only at runtime. Flattening works on a `duplicate_deep()` copy (ADR 0004).
8. **Identity by ID.** References to Game Objects and players are by their integer IDs in anything that is stored, logged or answered. A changed ID means a different object (ADR 0008).
9. **No strong reference cycles.** Engine classes are `RefCounted`, and two objects holding each other are never freed. When a child needs to reach its owner (a Game Object finding its zone), the child holds a `WeakRef` behind a typed accessor, as in `MmGameObject.zone()`. The test run must end without "ObjectDB instances were leaked".

## Errors

- **Bad input from outside** (an illegal decision answer, an invalid setup) is expected: return a reason string or result, leave the state unchanged, and never "fix" the input.
- **Broken engine invariants** are programmer errors: `assert()` with a message, or `push_error()` where execution must continue.

## Tests

- Test-first: write the failing scenario, then the code (roadmap).
- Mirror `src/`: `src/core/mm_zone.gd` is tested in `tests/core/test_mm_zone.gd`. Rules behaviours that span classes go in a file named for the behaviour, such as `tests/rules/test_mulligans.gd`.
- Test names describe the behaviour in words: `test_london_mulligan_with_one_free_mulligan_keeps_six`.
- Tests go through the public API (the `MmEngine` facade where possible) and check the outcome: the state, the views and the event log.
- Arrange, act, assert, separated by a blank line. Build scenarios with `tests/support/` helpers rather than repeating setup code.
- Name the rule being tested in the test's comment when there is one.

## Formatting

- Tabs for indentation (Godot default). Two blank lines between functions.
- Lines up to about 100 characters. Break long calls after an opening parenthesis.
- Use `"double quotes"` for strings.
