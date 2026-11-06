# Follow the Comprehensive Rules architecture, cut scope by mechanic

The engine models the real structure of the Magic Comprehensive Rules (priority, the stack, state-based actions, the layer system with timestamps and dependencies, replacement effects, triggered abilities waiting to be put on the stack) from the start, even though the first card pool is a small subset of Alpha. Scope is reduced by leaving out whole mechanics, never by simplifying the architecture, because player-modified cards will combine in unforeseen ways and only the real structure keeps those interactions predictable as new mechanics are added.

The rules followed are the current Comprehensive Rules and current Oracle wording, even for Alpha-era cards (so, for example, there is no mana burn and no damage assignment order). Any older rule that is wanted for flavour is added as an explicit, named house rule, never mixed into the core.

Rules that only matter for a particular mechanic are not implemented until that mechanic enters the game. The architecture must leave room for them, but code for absent mechanics is not written ahead of time.

Encounters are strictly 1v1. The engine does not need to support more than two players.
