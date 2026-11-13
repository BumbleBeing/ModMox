# The Deckbox is the door to the deckbuilder, and only its Start button checks legality

The Hero never opens the deckbuilder directly. It is reached only through the Deckbox, the screen that lists the saved Decks and sets the Active Deck (A543). The Deckbox opens in two ways. From Stage Navigation the Hero can open it at any time between Nodes, change the Active Deck, edit a Deck and apply Mods, and leave by a plain Close that checks nothing. And it opens by itself when the Hero enters an encounter, after the Villain is revealed. There it gives the same full access, so the Hero can pick or rebuild a Deck knowing who they face, and in place of Close it has a Start button. Neither the Deckbox nor the deckbuilder can be opened during an encounter.

Start is disabled while the Active Deck is illegal (A540). That is the only place legality is enforced. An illegal Deck can be saved, a Deck can become illegal when a card is sold or lost (ADR 0028), and nothing stops either: the Hero meets the problem at the one moment it matters, in the screen where it can be fixed by choosing another Deck or editing this one.

The alternatives were to open the deckbuilder from anywhere on the map, or only at certain Nodes. Opening it straight from the map leaves two screens that can change which Deck is played. Tying it to Nodes adds friction and takes away the answer to a revealed Villain, which is much of the fun of building a Deck in a run. Checking legality in more places (at saving, at a Store's sale, when setting the Active Deck) was also turned down: each check would need its own way out, and the one before an encounter would still be needed.

Mods are applied only in the deckbuilder (ADR 0029), so the Deckbox is also the only way to a Mod's use. The deckbuilder's inspector shows cards and Mods only; Potions and other Items belong to whichever screen shows what the Hero holds (A546).

The Deckbox screen does not exist yet. It is built with the deckbuilder's port into production code, in the first run milestone (A539, A551).
