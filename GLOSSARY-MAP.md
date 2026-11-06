# Glossary Map

## Contexts

- [Game](./GLOSSARY.md): the roguelike around the engine; runs, characters, Statuses
- [Rules Engine](./addons/modmox_rules/GLOSSARY.md): runs a single encounter between the Hero and a Villain

## Relationships

- **Game → Rules Engine**: The game hands the engine an Encounter Setup (decks of Run Cards, final starting numbers, Emblems derived from Statuses) and receives the event log and the Outcome. The engine never refers to the game.
