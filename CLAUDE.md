# ModMox

A roguelike RPG around a Magic-style rules engine, in Godot 4.7.2 / GDScript. Right now the work is the rules engine in `addons/modmox_rules/`.

## Read before writing engine code

- `addons/modmox_rules/docs/conventions.md`: how engine code is written. Follow it exactly.
- `addons/modmox_rules/GLOSSARY.md`: the domain vocabulary. `GLOSSARY-MAP.md` links it to the game glossary.
- `addons/modmox_rules/docs/adr/`: the design decisions. Don't contradict one without the user's agreement; if one changes, update it.
- `addons/modmox_rules/docs/roadmap.md`: the milestone ladder and where we are.

Game Content (authored `.tres` Card Definitions) lives at `content/cards/`, outside the engine; game-side tests live at `tests/`.

## How work proceeds

- One milestone at a time. At the start of a milestone, agree its scope and test scenarios with the user before writing code.
- Test-first. A milestone is done when every test passes.
- Don't implement rules for mechanics that aren't in the game yet (ADR 0001).

## Running tests

Godot is not on PATH. Run from the repo root:

```bash
GODOT=~/Desktop/Godot_v4.7.2-stable_linux.x86_64 tools/test.sh
```

## Keeping docs in sync

Whenever the glossaries, an ADR, the roadmap or the conventions change, copy them into the user's Obsidian vault at `~/Documents/PrimaryVault/ModMox/`:
- the engine glossary to `Rules Engine/Glossary.md`
- the roadmap to `Rules Engine/Roadmap.md`
- the conventions to `Rules Engine/Conventions.md`
- the ADRs to `Rules Engine/Decisions/`
- the root `GLOSSARY.md` to `Game Glossary.md`

Then regenerate the wikilinked index `Rules Engine/Design Decisions.md`. The repo copy is the source of truth.
