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
Whatever answers Pending Decisions on behalf of a player: the human through the GUI, or an AI. Usually the Hero has a Human Agent and the Villain an AI Agent, but either player can be driven by any Agent. A Human Agent is no Agent at all to the Encounter Driver, which stops and waits for the GUI's answer.
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

**Outcome**:
How an encounter ended: the Hero won, the Villain won, or a draw when both players lost at the same moment. The game around the engine reads it at the end of an encounter.
_Avoid_: Result, score, victory (when a draw is possible)

**Decision Log**:
Every accepted answer to a Pending Decision in an encounter, in order, plus any concession. Together with the Encounter Setup it reproduces the encounter exactly.
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
Everything one player may legally see of the game, and nothing more. The GUI only ever reads a Player View. An AI Agent reads the real encounter only through its Player View and its World, and may read Simulation Copies freely.
_Avoid_: Snapshot, visible state

## Triggered abilities

**Pending Trigger**:
A triggered ability that has triggered but has not been put on the stack yet, together with what triggered it ("that player", "that creature") and the card it came from.
_Avoid_: Queued trigger, trigger instance

**Batch**:
Events that happen at the same moment, such as everything state-based actions do at once or all combat damage in a step. Triggers are looked for once, after the whole batch.
_Avoid_: Transaction, group

**Last-Known Information**:
What an object was like the last time it was on the battlefield, kept after it leaves so that "dies" triggers and "its power" still have an answer.
_Avoid_: Ghost, snapshot (in rules talk), LKI (in code)

**Condition**:
Something true or false about the game right now, such as "this permanent is untapped", used for an intervening "if" clause.
_Avoid_: Predicate, check (Filter is the word when a player or object either matches or not)

## Continuous effects

**Continuous Effect**:
A change to characteristics that lasts, such as "white creatures get +1/+1" or "+3/+3 until end of turn". It comes from a static ability, applying to whatever matches right now, or from a resolved spell or ability, applying to what it found when it resolved.
_Avoid_: Buff, modifier, aura (unless an actual Aura is meant)

**Layer**:
One step in the fixed order in which continuous effects apply: copy, control, text, type, color, abilities, then power and toughness (characteristic-defining, setting, modifying).
_Avoid_: Pass, stage

**Timestamp**:
When an object entered its zone or a continuous effect was created. Within a layer, earlier timestamps apply first. An object's ID is its timestamp.
_Avoid_: Creation order, age

**Characteristic-Defining Ability**:
An ability that works out a characteristic, such as "its power and toughness are each equal to the number of non-Wall creatures you control". It works in every zone, and its card shows "*" for that number.
_Avoid_: Variable stats, star ability

## Replacement effects

**Replacement Effect**:
An effect that waits for a particular event and changes it as it would happen, such as "the next time this creature would be destroyed this turn, instead tap it". When several apply to one event, the affected player chooses the order.
_Avoid_: Override, interceptor, hook

**Prevention Effect**:
A replacement effect that stops damage from being dealt: all of it, or up to an amount. Prevented damage is never dealt, so nothing that reacts to damage sees it.
_Avoid_: Damage reduction, absorb, block (blocking is combat)

**Shield**:
A replacement or prevention effect that is used up as it applies, such as "prevent the next 1 damage" or a regeneration shield. The GUI shows what each one has left and the card it came from.
_Avoid_: Buffer, barrier, charge

**Protection**:
"Protection from [quality]": a permanent with it can't be dealt damage, blocked, or targeted by anything with that quality, which is a Filter, such as "black" or "creatures".
_Avoid_: Immunity, ward (a different keyword), hexproof (a different keyword)

**Suspended Batch**:
A batch of events that stopped part-way because a player must choose which replacement effect applies first. It is kept in the game state until they answer, and then carries on.
_Avoid_: Paused event, pending event, interrupted batch

## Combat

**Combat**:
Which creatures are attacking and blocking, which player is defending, and which creatures have already struck first. It is part of the game state, and empty outside the combat phase.
_Avoid_: Battle (a card type in Magic), fight

**Summoning Sickness**:
A creature cannot attack or pay {T} until its controller has controlled it continuously since the start of their most recent turn. The engine works this out from when control began; nothing has to clear it.
_Avoid_: Sick (on its own), fresh, exhausted

**Marked Damage**:
Damage dealt to a creature, which stays on it until the cleanup step removes it.
_Avoid_: Wounds, damage counters (counters are something else)

**Damage Division**:
An attacker's controller choosing how its combat damage is split among the creatures blocking it, and with trample the player it attacks. There is no damage assignment order. The GUI shows it as a damage-split popup.
_Avoid_: Damage assignment order (removed from the rules), damage ordering

## Randomness

**Encounter Seed**:
The single number from which all randomness in an encounter is derived, making the encounter exactly replayable from its seed and its decisions.
_Avoid_: Random seed, game ID

**Game RNG**:
The randomness used by the rules themselves (shuffles, random discards, coin flips), hidden from both players.
_Avoid_: RNG (unqualified)

**AI RNG**:
The randomness an AI Agent uses to choose among options and to re-deal Simulation Copies, which never affects the Game RNG. Each decision gets a fresh stream from the Encounter Seed, the player and how many decisions came before, so the same decision gets the same numbers after a save and reload.
_Avoid_: RNG (unqualified)

## AI Agents

**Encounter Driver**:
What runs an encounter by asking each player's Agent for answers, stopping where a player has no Agent and a human must decide.
_Avoid_: Game loop, match runner, controller

**Simulation Copy**:
An engine copied from a real one to look ahead on, as one player might imagine the game: the cards they cannot see are re-dealt at random, the Game RNG is reseeded, and nothing can be undone. Playing on it never changes the real encounter.
_Avoid_: Clone, snapshot, sandbox, lookahead state

**Simulation Source**:
What an Agent is handed with each decision: its AI RNG, its World, and Simulation Copies to play on. Never the real game state.
_Avoid_: Engine handle, oracle (unqualified)

**World**:
The game as an Agent's player might imagine it at one decision: the real game with every card they cannot see re-dealt. Inside a Simulation Copy, the copy itself.
_Avoid_: Belief state, guess

**Board Evaluator**:
What turns a game state into one number from a player's point of view: their side's worth minus the other side's, counting life, cards in hand and permanents as they are now.
_Avoid_: Heuristic (unqualified), fitness, score function

**Combat Oracle**:
What answers "if these attack and these block, what happens?" by running the engine's own combat on a Simulation Copy.
_Avoid_: Combat math, damage predictor

**Timing Tag**:
When a spell or ability is worth considering, worked out from what its effects do: a combat trick only in a fight or a response, removal also in its controller's main phases and the other player's end step. It never decides whether a play is good.
_Avoid_: AI hint, card flag, AILogic

**AI Profile**:
An AI Agent's temperament as a saved, moddable resource: whether it plays first, its mulligan land range, how readily it trades in combat, when its life is in danger, what the Board Evaluator thinks things are worth, and how much more or less than its AI Difficulty it searches.
_Avoid_: Villain Profile, difficulty, personality file

**AI Difficulty**:
A global, game-side setting for how hard the AI plays, as a saved, moddable resource. It only sets how much the AI searches: whether it uses Rollouts, how many candidates and samples. It never adds mistakes or lets the AI cheat.
_Avoid_: Skill level, AI level, handicap

**Rollout**:
One candidate answer played out on a Simulation Copy, by heuristic Agents for both players, through the rest of the Game Turn and the whole next one, then scored by the Board Evaluator. Flat Monte Carlo compares candidates by their Rollouts on the same re-dealt worlds and keeps the one-step pick unless another clearly beats it.
_Avoid_: Playout, simulation (unqualified), search

**Tournament**:
Two AI contenders, each an AI Profile and an AI Difficulty, playing many seeded encounters with the seats swapped on each seed, to measure which plays better. It is how AI settings are tuned.
_Avoid_: Match, ladder, self-play run
