# ModMox Rules Engine

The rules engine that runs a single game of Magic-style cards between the player and one foe, following the structure of the Magic Comprehensive Rules so that unofficial and player-modified cards behave predictably.

## Cards

**Card Definition**:
The base design of a card: its name, costs, types, characteristics, and abilities, as authored by the game designer.
_Avoid_: Card template, prototype, blueprint

**Run Card**:
A specific copy of a card owned by the player during a run, carrying any modifications earned outside of encounters.
_Avoid_: Deck card, upgraded card, card instance

**Modification**:
A single permanent change applied to a Run Card outside of an encounter, such as a new cost, name, or ability parameter.
_Avoid_: Upgrade, buff, patch, mod

**Game Object**:
An object inside an encounter (a card in a zone, a spell on the stack, a permanent, a token, an ability on the stack), including everything currently affecting it in that game.
_Avoid_: Card (when an in-game object is meant), entity

**Printed Characteristics**:
The characteristics a card has before anything in an encounter affects it, worked out from its Card Definition alone. Deck and reward screens show these, and in-game characteristics start from them.
_Avoid_: Base stats, card data

**Card Identity**:
The identity of a physical card, which survives every zone change even though each move creates a new Game Object. Used only to relate Game Objects back to their Run Card, never by the rules.
_Avoid_: Card ID (when an object is meant), instance ID

## Play

**Encounter**:
One complete game of Magic between the Hero and exactly one Villain. Run Cards cannot change during an encounter.
_Avoid_: Match, battle, duel

**Encounter Setup**:
The starting conditions of an encounter: both decks, starting life totals, opening hand sizes, free mulligans, who goes first, and the encounter seed.
_Avoid_: Game config, match settings

**Free Mulligan**:
A mulligan that puts no cards on the bottom of the library. A player's first mulligans are free, up to the number granted in the Encounter Setup.
_Avoid_: Bonus mulligan, mulligan charge

**Emblem**:
A Game Object in the command zone that has abilities but no other characteristics, used to give an encounter or a player rules that last the whole game.
_Avoid_: Encounter rule, modifier, aura (unless an actual Aura is meant)

**Hero**:
The player in an encounter who represents the human's character.
_Avoid_: Player (when this specific player is meant), user, human

**Villain**:
The player in an encounter who represents the adversary.
_Avoid_: Opponent (when this specific player is meant), enemy, foe, AI

**Agent**:
Whatever answers Pending Decisions on behalf of a player: the human through the GUI, or an AI. Usually the Hero has a Human Agent and the Villain an AI Agent, but either player can be driven by any Agent.
_Avoid_: Controller, input, brain

**Target Requirement**:
One instance of the word "target" on a spell or ability, with a Filter saying what may be chosen for it.
_Avoid_: Target slot, targeting rule

**Selection**:
Who or what an effect applies to: the target chosen for a Target Requirement, each player or permanent matching a Filter, or the controller.
_Avoid_: Target (unless an actual target is meant), recipient list, scope

**Filter**:
A condition a player or Game Object either meets or does not, such as "untapped land". Filters combine with all-of, any-of and not.
_Avoid_: Predicate, query, condition

**Pending Decision**:
A point where the engine has stopped because a player must make a choice, together with the legal options for that choice.
_Avoid_: Prompt, callback, request

**Action**:
Something a player may do while holding priority, such as passing, playing a land or casting a spell. A priority decision offers the legal Actions as its options.
_Avoid_: Move, play, command

**Turn Number**:
How many turns a particular player has begun this encounter; shown to people as "<name>'s Turn 3". A player who has not had a turn yet is on Turn Number 0.
_Avoid_: Game Turn (when one player's count is meant), round

**Game Turn**:
How many turns have begun in the encounter across both players. Rules that speak of "the first turn of the game" use it.
_Avoid_: Turn Number (when the overall count is meant), round

**Decision Log**:
Every accepted answer to a Pending Decision in an encounter, in order. Together with the Encounter Setup it reproduces the encounter exactly.
_Avoid_: Input history, move list, replay

**Undo Barrier**:
A point in an encounter that decisions cannot be undone past: when hidden information is revealed, randomness is used, something leaves the stack, or the other player gets a decision.
_Avoid_: Commit point, save point

**Event**:
A single change to the game, such as a card moving zones or a library being shuffled. It is proposed, offered to replacement effects, applied, and then recorded.
_Avoid_: Action, change, signal

**Event Log**:
Every Event performed in an encounter, in order. Triggers and the GUI learn what happened from it.
_Avoid_: History, game log

**Player View**:
Everything one player may legally see of the game, and nothing more. Agents and the GUI only ever read a Player View.
_Avoid_: Snapshot, visible state

## Randomness

**Encounter Seed**:
The single number from which all randomness in an encounter is derived, making the encounter exactly replayable from its seed and its decisions.
_Avoid_: Random seed, game ID

**Game RNG**:
The randomness used by the rules themselves (shuffles, random discards, coin flips), hidden from both players.
_Avoid_: RNG (unqualified)

**AI RNG**:
The randomness an AI Agent uses to choose among options, which never affects the Game RNG.
_Avoid_: RNG (unqualified)
