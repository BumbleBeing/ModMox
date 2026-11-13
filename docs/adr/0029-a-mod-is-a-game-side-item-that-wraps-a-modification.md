# A Mod is a game-side item that wraps an engine Modification

A Mod is a resource on the game's side of the boundary. It holds a name, a description, whether it is a Hex, the engine Modification it leaves on a card, and its own rule for which cards it accepts. Applying a Mod appends its Modification to the Run Card (ADR 0004), and the engine never learns a Mod was involved.

Every card has three Mod Slots, Hexes included. A basic land has them too, and its first Mod makes it a Run Card of the Collection's (A558, ADR 0028). A Mod is applicable to a card when the card has an empty Mod Slot and the Mod's rule accepts it: a Mod that adds a mana symbol, for example, needs a card with a mana cost. The same rule holds for every card, with no list of its own for basic lands. Both checks are made game-side. The engine's `MmRunCard` will flatten any number of Modifications and does not know the limit.

**A Mod's name goes in front of the card's** (A559). A Grizzly Bears with a Mod named Violent is named Violent Grizzly Bears, and a Plains with one named Ancient is Ancient Plains. For now the rule is the simplest one: the name of each Mod and Hex on the card, in slot order, then the card's own name. The user has a fuller list of naming rules, to be agreed later. The name is built game-side from the Mods on the card, and the engine's Modification is unchanged. Whether the engine should see the new name is left open until then: no card in the game cares about a name yet (ADR 0001).

**Mods are applied only in the deckbuilder** (A544). The Workshop and Spoils hand Mods out, and the Workshop removes them, but there is one place, one pop-up and one "are you sure" for putting a Mod on a card.

A Hex is a Mod like any other in data, but the Hero never holds or applies one. It arrives already on a card and takes a Mod Slot.

The alternative was to ask the engine's Modification whether it can apply to a card, since it knows what it changes. It was rejected because which cards may take an item, how many a card may carry, and whether an item is a Hex are rules of the roguelike, not of Magic, and the engine never refers to the game. Keeping them game-side also lets two Mods share one Modification and differ only in what they accept.
