# Run Cards are a base Card Definition plus a list of Modifications

A Run Card stores a reference to an untouched base Card Definition and an ordered list of Modifications (which may change anything, including the card's name), instead of a duplicated and edited copy of the definition. At the start of an encounter the engine flattens each Run Card into a private, read-only definition and never sees that it was modified.

Base Card Definitions are never mutated at runtime. Godot caches and shares loaded Resources, so editing one in place would change every copy of that card and could overwrite the authored `.tres` file. Keeping Modifications as separate records also makes them displayable, reversible, and robust to later rebalancing of the base card.

Modifications apply strictly in the order they were earned. The flattened result is the card's printed card for every rules purpose: copy effects copy the modified version, name checks see the modified name, and mana value uses the modified cost. No "printed versus modified" distinction exists inside the engine.

The Villain's deck uses the same format, so the engine has a single input shape for both players.
