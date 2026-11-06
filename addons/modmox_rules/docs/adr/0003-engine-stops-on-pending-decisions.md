# The engine stops on Pending Decisions instead of awaiting input

Whenever a choice is needed, the engine stops and returns a Pending Decision listing the legal options, then resumes when given an answer. Rules code never `await`s a signal or calls into the GUI or AI. The GUI (zone popups, highlighted legal targets, blocker declaration) and the foe's AI both answer the same decisions, which keeps the engine testable headless and lets the AI simulate ahead on a copy of the game state.

Pending Decisions come in a fixed set of typed kinds (choose targets, declare blockers, choose from a zone, and so on) that describe what is being chosen and from where. They contain no GUI hints: the GUI maps each kind to its own widget.

The engine gives priority at every point the rules require and never skips any. MTG Arena-style auto-passing (configurable stops, skipping steps where no meaningful action is possible) is decided by whoever answers the decision, not by the engine.

Purely presentational choices never reach the engine. The order of cards in a hand is one: the engine keeps a stable order, the GUI lets the player rearrange its own display, and decisions refer to cards by object ID rather than position, so rearranging never affects rules, replays or saves.

Likewise, paying a cost is always a Pending Decision (which mana abilities to activate and which mana pays which part of the cost). Arena-style auto-tapping is Agent policy: the Human Agent proposes a payment the human can override, and the AI Agent chooses its own.
