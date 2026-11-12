# A Mod is a game-side item that wraps an engine Modification

A Mod is a resource on the game's side of the boundary. It holds a name, a description, whether it is a Hex, the engine Modification it leaves on a card, and its own rule for which cards it accepts. Applying a Mod appends its Modification to the Run Card (ADR 0004), and the engine never learns a Mod was involved.

A Run Card has three Mod Slots, Hexes included, and a basic land has none. A Mod is applicable to a card when the card has an empty Mod Slot and the Mod's rule accepts it: a Mod that adds a mana symbol, for example, needs a card with a mana cost. Both checks are made game-side. The engine's `MmRunCard` will flatten any number of Modifications and does not know the limit.

A Hex is a Mod like any other in data, but the Hero never holds or applies one. It arrives already on a card and takes a Mod Slot.

The alternative was to ask the engine's Modification whether it can apply to a card, since it knows what it changes. It was rejected because which cards may take an item, how many a card may carry, and whether an item is a Hex are rules of the roguelike, not of Magic, and the engine never refers to the game. Keeping them game-side also lets two Mods share one Modification and differ only in what they accept.
