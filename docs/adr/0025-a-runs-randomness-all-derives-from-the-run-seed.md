# A run's randomness all derives from the Run Seed

Every random choice the game makes outside an encounter comes from one number, the Run Seed: which Villain a Node gives, which Boss a Stage has, the Spoils of a win, and the Encounter Seed of each encounter. A run is therefore exactly replayable from its Run Seed and the human's choices, as an encounter already is from its Encounter Seed and its decisions (ADR 0006, ADR 0010).

Each attempt at an encounter gets its own Encounter Seed, so a rematch against a Boss is a new game with new shuffles and not a replay of the lost one.

Drawing from the global random number generator wherever a choice is needed was rejected. A run could then not be reproduced to chase a bug, a seed could not be shared, and reloading a save could change which Villain or which Spoils came up, which invites save-scumming, the thing saving RNG state with the encounter was chosen to prevent.

How the Run Seed is split into streams is left to the run system. The rule it must keep is the one ADR 0006 keeps inside an encounter: adding a new kind of random choice must not change the results of the old ones.
