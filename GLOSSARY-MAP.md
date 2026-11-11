# Glossary Map

## Contexts

- [Game](./GLOSSARY.md): the roguelike around the engine; runs, characters, Statuses
- [Rules Engine](./addons/modmox_rules/GLOSSARY.md): runs a single encounter between the Hero and a Villain. Its glossary also holds the AI Agent's terms (`addons/modmox_ai/`), whose ADRs share the engine's numbering

## Relationships

- **Game → Rules Engine**: The game hands the engine an Encounter Setup (decks of Run Cards, final starting numbers, Emblems derived from Statuses) and receives the event log and the Outcome. The engine never refers to the game.
- **Game → Rules Engine, in the GUI**: Only the Encounter Presenter holds the engine and the Encounter Driver. The Encounter Screen is handed snapshots built from the Hero's Player View, never the engine or the game state (ADR 0021, in the root `docs/adr/`, which shares the engine ADRs' numbering).
- **Game → AI Agent**: The game gives each Villain an AI Profile, sets one global AI Difficulty, and runs the encounter with an Encounter Driver, holding no Agent for the Hero so it stops for the GUI. The AI depends on the engine; the engine never refers to the AI.
