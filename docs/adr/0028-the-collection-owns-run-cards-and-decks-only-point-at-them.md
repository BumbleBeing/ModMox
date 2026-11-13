# The Collection owns Run Cards and Decks only point at them

The Hero's Collection holds every Run Card they own in the run, and it is the only thing that holds them. A Deck is a name and a list of pointers into the Collection, each Run Card at most once, plus a count of each basic land. So one Run Card can be in several Decks, and a Mod applied to it shows in every one of them, because there is only one card to change. Two copies of a card are two Run Cards, each with its own Mods, and the deckbuilder shows and handles every card as its own: nothing is stacked or counted as copies.

Because Decks point rather than hold, each Run Card needs an identity that lasts the run and survives saving, which the Collection gives it. A saved Deck stores those identities, never the cards.

Basic lands are the exception. They are free and unlimited and are not in the Collection, so a Deck only needs to know how many of each it has. That holds until a basic land takes its first Mod (A558). It has Mod Slots like any card, and a Mod is applied to one by selecting it in the Deck. At that moment that one copy becomes a kept, countable Run Card: the Collection adopts it and gives it an identity, it shows in the Collection, it can be in several Decks, and taking it out of a Deck returns it to the Collection instead of discarding it. The supply stays unlimited because only unmodified basic lands come from it. A modified one has a name of its own (ADR 0029), such as "Ancient Plains", so the count of Plains in a Deck is the count of cards named exactly Plains. A Deck that is left unsaved after one of its basic lands was modified still counts that land as a free one, and the modified card is simply in the Collection.

Applying a Mod changes the Collection, not the Deck being edited. That is why it is final once confirmed and is not undone by leaving the deckbuilder without saving: the Working Deck is only the unsaved name and contents of one Deck. Otherwise leaving without saving would be a free undo, and the Workshop's paid removal would mean nothing.

A Deck is legal at 40 cards or more. It has no maximum size (A540), and there is no copy limit: copies are limited only by how many Run Cards the Hero owns (A541). A limit can be added later as one more legality rule if a card proves abusive. An illegal Deck can be saved, and the Active Deck can become illegal when a card leaves the Collection. Legality is enforced in one place only, the Start button of the Deckbox that opens before an encounter (ADR 0037).

When a Run Card is sold or lost it drops out of every saved Deck at once, since a pointer to a card that is gone cannot stay (A542). The warning comes before the sale, where the Hero can still back out: it names the Decks the card is in and marks the Active Deck with "(Active)". It does not say whether a Deck would become illegal.

There is no undo for moves within the Working Deck (A545). Every move is reversed by one drag or double-click, and leaving without saving discards them all.

How the Collection and the Deckbox are saved, and where a Run Card's identity comes from in a real run, are left to the first run milestone (A548). What is fixed now is that deckbuilder edits and Mod applications are saved as run state. They are not logged decisions: the decision log of ADR 0010 replays an encounter, and deckbuilding happens outside one. Building the encounter's setup from the Active Deck is also that milestone's (A549).

The engine is unchanged and still takes an `MmPlayerSetup` that holds Run Cards directly (ADR 0004). When an encounter starts, the game builds that setup from the Active Deck: the Run Cards it points at, and a fresh Run Card for each basic land. Villain decks stay as they are, setups that hold their own cards, since a Villain has no Collection.

The alternative was for each Deck to hold its own Run Cards, as the files in `content/decks/` do. It needs no identities and no step to build a setup. It was rejected because the same owned card in two Decks would be two records that could carry different Mods, and something would have to keep them in step.

A Deck's layout in the deckbuilder is not part of it. Cards can be piled into any column while building, but only membership is saved, and a Deck reopens with every card in its own mana value column.
