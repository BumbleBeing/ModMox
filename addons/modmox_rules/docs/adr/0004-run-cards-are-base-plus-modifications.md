# Run Cards are a base Card Definition plus a list of Modifications

A Run Card stores a reference to an untouched base Card Definition and an ordered list of Modifications (which may change anything, including the card's name), instead of a duplicated and edited copy of the definition. At the start of an encounter the engine flattens each Run Card into a private, read-only definition. The one thing that definition keeps of its base is a reference to it, its Original.

Base Card Definitions are never mutated at runtime. Godot caches and shares loaded Resources, so editing one in place would change every copy of that card and could overwrite the authored `.tres` file. Keeping Modifications as separate records also makes them displayable, reversible, and robust to later rebalancing of the base card.

Modifications apply strictly in the order they were earned. The flattened result is the card's printed card for every rules purpose: copy effects copy the modified version, and mana value uses the modified cost. No "printed versus modified" distinction exists among the characteristics.

**The Original is the exception.** Each flattened definition points to the base it was flattened from. The Original is not a characteristic, so nothing in an encounter changes it, and only a rule that asks for it by name reads it. The first is a name check: a printed "named Charmed Stray" means "originally named Charmed Stray" in this game (`HasOriginalNameFilter`), which departs from CR 201.2. A card goes by its Original's name whatever Modifications have made of its own, so a Violent Charmed Stray counts, as does one renamed outright, and a different card renamed "Charmed Stray" does not. An object with no Original goes by its current name, matched exactly.

A reference to the whole base was chosen over a copy of its name so that a later rule about any original characteristic needs nothing new. Matching the current name by what it contains or ends with was rejected: it catches unrelated cards whose names overlap, and it breaks on a rename.

Tokens are not in the game yet (ADR 0001). When they are, a token that is a copy has the Original of what it copied, and any other token has none, so it goes by its current name.

The Villain's deck uses the same format, so the engine has a single input shape for both players.
