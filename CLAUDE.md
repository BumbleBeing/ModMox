# ModMox

A roguelike RPG around a Magic-style rules engine, in Godot 4.7.2 / GDScript. The GUI (milestone 13, game-side in `ui/`) is built around the rules engine in `addons/modmox_rules/` and the AI Agent that plays it in `addons/modmox_ai/` (ADR 0020); the roadmap says what is next.

## Read before writing engine code

- `addons/modmox_rules/docs/conventions.md`: how engine code is written. Follow it exactly.
- `addons/modmox_rules/GLOSSARY.md`: the domain vocabulary. `GLOSSARY-MAP.md` links it to the game glossary.
- `addons/modmox_rules/docs/adr/`: the design decisions. Don't contradict one without the user's agreement; if one changes, update it.
- `addons/modmox_rules/docs/roadmap.md`: the milestone ladder and where we are.

Game Content (authored `.tres` Card Definitions) lives at `content/cards/`, and decks at `content/decks/`, outside the engine; game-side tests live at `tests/`. Card art lives at `content/art/`: `godot --headless --path . -s res://tools/art/fetch_art.gd` fetches art for any card that lacks it, and `godot --path . res://tools/card_gallery/card_gallery.tscn` shows every card and sets art focus points. Backdrop pictures (320 × 180, named `white.png`, `blue.png`, `black.png`, `red.png` or `green.png`) go in `ui/sprites/backgrounds/Encounters/` and replace that color's placeholder (ADR 0035). Pixel icons live at `ui/sprites/`: `ASEPRITE=~/Projects/aseprite/build/bin/aseprite tools/sprites/build.sh` builds them from a text grid and re-exports any touched up in Aseprite. The game opens on the main menu (`ui/menu/`); `godot --path . -- --hero=red_green --villain=white_black --seed=7` goes straight to an encounter (add `--difficulty=normal`, `--emblems`, `--backdrop=red`, or `--screenshot=/absolute/path.png` to save a picture and quit). The game's own ADRs are in the root `docs/adr/` (ADR 0021 is the GUI's boundary, ADR 0022 how clicks answer decisions). Game-side code conventions are in the conventions' "Game-side code" section. The AI's slow checks run only on request: `MODMOX_SOAK_SEEDS=100 tools/test.sh -gselect=test_soak` (add `MODMOX_SOAK_DIFFICULTY=normal` for Monte Carlo), `MODMOX_FULL_BENCHMARK=1 tools/test.sh -gselect=test_benchmark`, and tournaments with `MODMOX_TOURNAMENT_SEEDS=100 tools/test.sh -gselect=test_tournament` (settings in `test_tournament.gd`).

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
- the ADRs, both the engine's and the game's in the root `docs/adr/`, to `Rules Engine/Decisions/`
- the root `GLOSSARY.md` to `Game Glossary.md`

Then regenerate the wikilinked index `Rules Engine/Design Decisions.md`. The repo copy is the source of truth.
