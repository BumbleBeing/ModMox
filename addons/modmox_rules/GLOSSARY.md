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

## Play

**Encounter**:
One complete game of Magic between the player and exactly one foe. Run Cards cannot change during an encounter.
_Avoid_: Match, battle, duel

**Pending Decision**:
A point where the engine has stopped because a player must make a choice, together with the legal options for that choice.
_Avoid_: Prompt, callback, request
