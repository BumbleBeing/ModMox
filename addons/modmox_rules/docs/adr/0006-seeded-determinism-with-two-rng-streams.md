# Encounters are deterministic, with separate Game RNG and AI RNG

Every encounter is exactly reproducible from its Encounter Setup (including the Encounter Seed) and the sequence of decisions made. Gameplay is still random: both streams are derived from the Encounter Seed. The Game RNG belongs to the game state, is used only by the rules, and is hidden from every player's view. The AI RNG belongs to the AI Agent and never touches the game state.

If the two shared one stream, tuning the AI would change shuffles and break replays, and an AI simulating ahead on a copy of the state could predict real shuffles exactly. Because RNG state is saved with the game, reloading a mid-encounter save reproduces the same random results, which prevents save-scumming.
