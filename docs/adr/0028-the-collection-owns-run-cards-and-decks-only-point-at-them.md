# The Collection owns Run Cards and Decks only point at them

The Hero's Collection holds every Run Card they own in the run, and it is the only thing that holds them. A Deck is a name and a list of pointers into the Collection, each Run Card at most once, plus a count of each basic land. So one Run Card can be in several Decks, and a Mod applied to it shows in every one of them, because there is only one card to change. Two copies of a card are two Run Cards, each with its own Mods, and the deckbuilder shows and handles every card as its own: nothing is stacked or counted as copies.

Because Decks point rather than hold, each Run Card needs an identity that lasts the run and survives saving, which the Collection gives it. A saved Deck stores those identities, never the cards.

Basic lands are the exception. They are free and unlimited, are not in the Collection, and cannot take a Mod, so a Deck only needs to know how many of each it has. The moment a basic could be modded it would have to become a kept, countable Run Card, and "unlimited" would stop being true.

Applying a Mod changes the Collection, not the Deck being edited. That is why it is final once confirmed and is not undone by leaving the deckbuilder without saving: the Working Deck is only the unsaved name and contents of one Deck. Otherwise leaving without saving would be a free undo, and the Workshop's paid removal would mean nothing.

The engine is unchanged and still takes an `MmPlayerSetup` that holds Run Cards directly (ADR 0004). When an encounter starts, the game builds that setup from the Active Deck: the Run Cards it points at, and a fresh Run Card for each basic land. Villain decks stay as they are, setups that hold their own cards, since a Villain has no Collection.

The alternative was for each Deck to hold its own Run Cards, as the files in `content/decks/` do. It needs no identities and no step to build a setup. It was rejected because the same owned card in two Decks would be two records that could carry different Mods, and something would have to keep them in step.

A Deck's layout in the deckbuilder is not part of it. Cards can be piled into any column while building, but only membership is saved, and a Deck reopens with every card in its own mana value column.
