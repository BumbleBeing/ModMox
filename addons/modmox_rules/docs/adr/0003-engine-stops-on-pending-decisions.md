# The engine stops on Pending Decisions instead of awaiting input

Whenever a choice is needed, the engine stops and returns a Pending Decision listing the legal options, then resumes when given an answer. Rules code never `await`s a signal or calls into the GUI or AI. The GUI (zone popups, highlighted legal targets, blocker declaration) and the foe's AI both answer the same decisions, which keeps the engine testable headless and lets the AI simulate ahead on a copy of the game state.

Pending Decisions come in a fixed set of typed kinds (choose targets, declare blockers, choose from a zone, and so on) that describe what is being chosen and from where. They contain no GUI hints: the GUI maps each kind to its own widget.

The engine gives priority at every point the rules require and never skips any. MTG Arena-style auto-passing (configurable stops, skipping steps where no meaningful action is possible) is decided by whoever answers the decision, not by the engine.
