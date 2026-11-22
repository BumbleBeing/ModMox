# ModMox

A roguelike RPG around a Magic-style rules engine, in Godot 4.7.2 / GDScript. The GUI (milestone 13, game-side in `ui/`) is built around the rules engine in `addons/modmox_rules/` and the AI Agent that plays it in `addons/modmox_ai/` (ADR 0020); the roadmap says what is next.

## Read before writing engine code

- `addons/modmox_rules/docs/conventions.md`: how engine code is written. Follow it exactly.
- `addons/modmox_rules/GLOSSARY.md`: the domain vocabulary. `GLOSSARY-MAP.md` links it to the game glossary.
- `addons/modmox_rules/docs/adr/`: the design decisions. Don't contradict one without the user's agreement; if one changes, update it.
- `addons/modmox_rules/docs/roadmap.md`: the milestone ladder and where we are.

Game Content (Card Definitions, each a real Magic card held to its Oracle Data in `content/cards/oracle.json`) lives at `content/cards/` and is added with `/add-card` (`.claude/skills/add-card/`, game ADR 0040); decks at `content/decks/`, outside the engine, and a Villain's whole deck list is added with `/add-enemy-deck` (`.claude/skills/add-enemy-deck/`); authored Emblems live at `content/emblems/` and Potions at `content/potions/` (engine ADR 0036); Mods and Hexes live at `content/mods/` and are added with `/add-mod` (`.claude/skills/add-mod/`, game ADR 0029); Token Definitions, what a token is made from, live at `content/tokens/` (engine ADR 0044), and `fetch_art.gd` fetches their art too; game-side tests live at `tests/`. Card art lives at `content/art/`: `godot --headless --path . -s res://tools/art/fetch_art.gd` fetches art for any card that lacks it, and `godot --path . res://tools/card_gallery/card_gallery.tscn` shows every card and sets art focus points. `godot --path . res://tools/breath_lab/breath_lab.tscn` shows a Portrait breathing and blinking and saves each Portrait's Breath Rate and Breath Intensity. Emblem art goes in `content/art/emblems/` by hand, named after the Emblem's file, with its credit in the manifest there; a Potion's 32 × 32 icon is built into `ui/sprites/potions/` (ADR 0033). Backdrop pictures (320 × 180, named `white.png`, `blue.png`, `black.png`, `red.png` or `green.png`) go in `ui/sprites/backgrounds/encounters/` and replace that color's placeholder (ADR 0035). A Stage's Map Backdrop (320 × 560) goes in `ui/sprites/backgrounds/stage_maps/` and is set on its Stage resource in `content/stages/`, with its Stage Intro color and its Scenery Ground, a mask of the same size opaque where Scenery may stand (ADR 0038). Scenery sprites are built into `ui/sprites/scenery/` from `tools/sprites/scenery_16.txt` and `scenery_32.txt`. Pixel icons live at `ui/sprites/`: `ASEPRITE=~/Projects/aseprite/build/bin/aseprite tools/sprites/build.sh` builds them from a text grid and re-exports any touched up in Aseprite. A Keyword Icon is drawn in the style of the others with `/draw-keyword-icon <keyword> <description>` (`.claude/skills/draw-keyword-icon/`). A Potion Icon is drawn from one of the empty bottles in `tools/sprites/potion_templates/` with `/draw-potion-icon <name> <what it evokes> <shape>` (`.claude/skills/draw-potion-icon/`). An Armor Icon is drawn in the shape of its Armor Slot's template in `tools/sprites/armor_templates/`, the faint outline an empty Armor Slot shows, with `/draw-armor-icon <name> <description> <helm | cuirass | greaves>` (`.claude/skills/draw-armor-icon/`). A Villain's Portrait, Pain Portrait and Blink Portrait are drawn after a Magic card's art with `/draw-portrait <card name>` (`.claude/skills/draw-portrait/`), from grids in `tools/sprites/portraits/`. The game opens on the main menu (`ui/menu/`); `godot --path . -- --hero=red_green --villain=white_black --seed=7` goes straight to an encounter (add `--difficulty=normal`, `--emblems`, `--potions`, `--backdrop=red`, or `--screenshot=/absolute/path.png` to save a picture and quit). `godot --path . -- --stage-map --run-seed=7 --stage=red` opens the Stage Map of a debug run (with `--screenshot=` too). `godot --path . -- --spoils --run-seed=2 --stage=red --rank=boss` opens the Spoils screen of a win in one (`--rank=lesser` or `elite` too, and `--screenshot=`); `--tier=N` with either walks the debug run up to Tier N. `godot --path . -- --run-won --run-seed=7` and `--run-lost --run-seed=7 --tier=3` open the end of a debug run, and `godot --path . -- --credits` the Credits (`--page=art` for Art Attribution); each honors `--screenshot=`. The Credits' roll is authored in `content/credits/credits.txt`. A run is saved to `user://saves/run.json` and its Run Log written to `user://run_logs/`; `godot --headless --path . -s res://tools/run_log/replay.gd -- <log>` replays a Run Log and names the first line that does not hold. The Tier Track's medallions are drawn by `python3 -I tools/sprites/tier_medallions.py`, and every `build.sh` run gathers the Portrait grids' credit lines into `ui/sprites/portraits/art.json` for Art Attribution. The game's own ADRs are in the root `docs/adr/` (ADR 0021 is the GUI's boundary, ADR 0022 how clicks answer decisions). Game-side code conventions are in the conventions' "Game-side code" section. The AI's slow checks run only on request: `MODMOX_SOAK_SEEDS=100 tools/test.sh -gselect=test_soak` (add `MODMOX_SOAK_DIFFICULTY=normal` for Monte Carlo, and `MODMOX_SOAK_HELD=1` to play them all with the Boons and a Potion as well), `MODMOX_FULL_BENCHMARK=1 tools/test.sh -gselect=test_benchmark`, and tournaments with `MODMOX_TOURNAMENT_SEEDS=100 tools/test.sh -gselect=test_tournament` (settings in `test_tournament.gd`); Stage Maps over many seeds with `MODMOX_MAP_SEEDS=2000 tools/test.sh -gselect=test_stage_map_soak`.

## How work proceeds

- One milestone at a time. At the start of a milestone, agree its scope and test scenarios with the user before writing code.
- Cards are added between milestones, on the roadmap's card track: `/add-card` adds those the engine can already express, and the user agrees each new primitive a card needs before it is built.
- Test-first. A milestone is done when every test passes.
- Don't implement rules for mechanics that aren't in the game yet (ADR 0001).

## Running tests

Godot is not on PATH. Run from the repo root:

```bash
GODOT=~/Desktop/Godot_v4.7.2-stable_linux.x86_64 tools/test.sh
```

That runs the whole suite in parallel processes (about 2 minutes). While building, run the tests near the change: `tools/test.sh --quick` (picked from `git status`), or one file with `-gtest=res://…/test_x.gd`. Run the whole suite before committing and before calling a milestone done. Don't run two whole suites at once; they share the cores. When an agent runs tests, it runs them through `tools/guarded.sh` (`GODOT=... tools/guarded.sh tools/test.sh --jobs=4`), which caps the memory, the cores and the time of everything the run starts and refuses to start beside another run: a hung run left going under more runs once took the machine down. `tools/test.sh -gtest=...` runs the whole suite in one process, not one file. `--serial` runs it in one process as before.

## Keeping docs in sync

Whenever the glossaries, an ADR, the roadmap or the conventions change, copy them into the user's Obsidian vault at `~/Documents/PrimaryVault/ModMox/`:
- the engine glossary to `Rules Engine/Glossary.md`
- the roadmap to `Rules Engine/Roadmap.md`
- the conventions to `Rules Engine/Conventions.md`
- the ADRs, both the engine's and the game's in the root `docs/adr/`, to `Rules Engine/Decisions/`
- the root `GLOSSARY.md` to `Game Glossary.md`

Then regenerate the wikilinked index `Rules Engine/Design Decisions.md`. The repo copy is the source of truth.
