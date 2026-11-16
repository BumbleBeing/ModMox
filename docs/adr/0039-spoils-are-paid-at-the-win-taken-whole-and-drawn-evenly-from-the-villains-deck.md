# Spoils are paid at the win, taken whole, and drawn evenly from the Villain's deck

A won encounter pays Spoils: gold, and cards from the Villain's own deck. Three choices about them are easy to undo by mistake, so they are written down here. The numbers themselves (how many cards at each Rank, the gold's ranges) are tunable constants and live in the code and the roadmap, not here.

**They are paid when the win is counted, and the Spoils screen only shows them.** Rolling the gold and the cards and handing them to the run happen in one step, when the run records the win, before any screen opens. The Spoils screen is a display of what was already won, with nothing to choose. So there is never a moment when the run holds Spoils not yet paid: quitting on the Spoils screen, once runs are saved (milestone 20), can neither lose them nor roll them again. Rolling at the win and paying when the screen closed was rejected for that reason; it would put half-paid state into every save.

**The Hero takes all of it.** There is no picking one card of several and no Skip. A pick protects a deck from being diluted, but won cards join the Collection, not a Deck (ADR 0028), and the Hero builds Decks from the Collection freely in the deckbuilder; an unwanted card is sold at the Store. With nothing to protect, a pick would only be a click.

**The cards are drawn evenly, one ticket for each copy.** The draw is from the Villain's setup for the Stage's Tier, and every copy in it that is not a basic land is one equal ticket, drawn without replacement: a card the deck runs three of is three times as likely as a one-of and can be paid more than once, but no one copy is paid twice. Weighting the draw by Rarity, with higher Ranks and Tiers leaning toward the rarer cards, was considered and rejected. The decks already do that work: a tougher Villain is built with more uncommons, rares and mythics, so the quality of its Spoils follows from its deck, and a deck is tuned in one place rather than against a second table. Basic lands are left out because the Hero has them free and unlimited (ADR 0028); nonbasic lands are drawn like any other card.

Each card arrives as a plain Run Card, its base alone, whatever Modifications the Villain's copy may carry. A Mod is a game-side Item that wraps a Modification (ADR 0029), so a Modded card in Spoils is a Run Card with Mods attached, which waits for real Mods.

The gold and the cards each draw from a stream of their own of the Run Seed (ADR 0025), so retuning the gold never changes which cards a run is paid.
