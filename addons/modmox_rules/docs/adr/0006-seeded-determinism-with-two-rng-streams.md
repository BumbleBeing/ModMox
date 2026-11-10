# Encounters are deterministic, with separate Game RNG and AI RNG

Every encounter is exactly reproducible from its Encounter Setup (including the Encounter Seed) and the sequence of decisions made. Gameplay is still random: both streams are derived from the Encounter Seed. The Game RNG belongs to the game state, is used only by the rules, and is hidden from every player's view. The AI RNG belongs to the AI Agent and never touches the game state.

If the two shared one stream, tuning the AI would change shuffles and break replays, and an AI simulating ahead on a copy of the state could predict real shuffles exactly. Because RNG state is saved with the game, reloading a mid-encounter save reproduces the same random results, which prevents save-scumming.

The AI RNG is not one running stream. Each AI decision gets a fresh stream, seeded from the Encounter Seed, the deciding player and the number of decisions made so far (milestone 11, ADR 0020). Saves hold only the setup and the decision log (ADR 0010), so a running AI stream would restart on reload and the AI would answer differently. With fresh streams, the same decision gets the same numbers after any reload, and two AI players never share numbers. A Simulation Copy's own Game RNG is reseeded from the AI RNG, so lookahead never predicts the real shuffles or draws.
