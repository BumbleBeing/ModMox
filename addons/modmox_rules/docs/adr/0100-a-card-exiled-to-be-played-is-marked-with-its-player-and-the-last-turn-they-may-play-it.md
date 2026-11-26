# A card exiled to be played is marked with its player and the last turn they may play it

Clockwork Percussionist says "When this creature dies, exile the top card of your library. You may play it until the end of your next turn." It is the first card that lets a player play a card from exile other than an Adventurer card on an adventure (ADR 0078).

**"Exile the top card of your library" is `ExileTopOfLibraryEffect`**, as `MillEffect` is for the graveyard: each selected player exiles the top cards of their library, face up, top card first, and the ability remembers them for `MovedCardsSelection` (ADR 0080), so the next effect can say "it".

**"You may play it until the end of your next turn" is `MayPlayExiledEffect`.** It marks each card it selects in exile with the player who may play it, the ability's controller, and the last Game Turn they may: `MmGameObject.playable_by_player_id` and `playable_through_game_turn`, set by a `PlayPermittedEvent`. "Your next turn" is two Game Turns on when it is that player's turn now and the next one otherwise, since two players take turns about. With `duration` THIS_TURN it is "You may play it this turn", the Game Turn it resolves in. Nothing ends the mark: once its turn is past it permits nothing, and a card that leaves exile is a new object without it (ADR 0008).

Marking the card was chosen over keeping a list of permissions in the game state. It is how an Adventurer card on an adventure is marked, the card is what the player looks at, and a copy of the state copies it with the object.

**`TurnProcedure` offers a marked card to its player as it would offer one in the hand.** A land is a land play, offered after the hand's and only while they have a land play left (CR 305.2); anything else is a cast, after the cards on an adventure, with its usual timing and for its mana cost, less any reduction. Neither changes the index of an action offered before, so a Decision Log replays as it did (ADR 0010, 0012). The other player is never offered it.

**The views show the mark**, since exile is public: `MmObjectView.playable_by_player_id` and `playable_through_game_turn`. The Encounter Screen clicks the card in the Exile window and says until when (game ADR 0101).

**The Agent needs nothing new.** A marked card is one more cast or land play among its priority actions, and its Timing Tags come from the card as they would in the hand.

`AbilityText` says "exile the top card of your library" and "You may play it until the end of your next turn" (or "this turn").

Left out until a card needs them: a card of another player's played this way, which would enter under its player's control (CR 108.3); "cast" rather than "play"; and paying a cost other than the card's mana cost.
