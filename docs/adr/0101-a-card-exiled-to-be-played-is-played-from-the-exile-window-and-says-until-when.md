# A card exiled to be played is played from the Exile window, and says until when

Clockwork Percussionist's card exiled to be played (engine ADR 0100) needed two things on screen. Both follow what an Adventurer card on an adventure already does (game ADR 0079), so the user agreed them without a prototype, and chose every word below.

**It is played from the Exile window.** The Hero's exile pile glows green while it can be played, and in the window the card glows and one click plays it: "Cast Spark from exile" for a spell, as an adventure's reads, and "Play Mountain from exile" for a land. `DecisionClicks` treats a card marked for the viewer as it treats one on an adventure, with the verb a land play has.

**Its State Information says until when**: "May be played", then "May be played until the end of your next turn.", or "May be played until the end of this turn." in the last Game Turn it may be played, worked out from the snapshot's Game Turn. Once that turn is past it says nothing. A Villain's marked card says the same in their exile, with no Glow.
