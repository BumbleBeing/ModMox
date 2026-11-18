# ModMox

A roguelike RPG built around a Magic-style rules engine, made in Godot 4.7.2 with GDScript.

## Layout

- `addons/modmox_rules/`: the rules engine, independent of the game ([glossary](addons/modmox_rules/GLOSSARY.md), [decisions](addons/modmox_rules/docs/adr/), [roadmap](addons/modmox_rules/docs/roadmap.md))
- `addons/gut/`: GUT 9.7.1, the unit test framework (third party, MIT)
- `content/cards/`: the game's authored Card Definitions, starting with the Alpha basic lands
- `tests/`: game-side tests, such as checks on the card files
- `tools/`: developer scripts
- [GLOSSARY-MAP.md](GLOSSARY-MAP.md): how the game and engine vocabularies relate

## Running the tests

The engine's tests run headless from the command line. Point `GODOT` at the Godot 4.7.2 executable if it is not on your `PATH` as `godot`:

```bash
GODOT=~/Desktop/Godot_v4.7.2-stable_linux.x86_64 tools/test.sh
```

This runs the whole suite split across parallel Godot processes (half the cores, at most 8; `--jobs=N` sets it), about 2 minutes instead of 10 in one process. Files are dealt out by how long each took last time (`.godot/test_times.tsv`), and each process gets its own `user://` under `.godot/test_shards/`.

- `tools/test.sh --quick` runs only the tests near what `git status` shows as changed, plus the conventions' checks. Use it while building; run the whole suite before committing.
- `tools/test.sh --serial` runs the whole suite in one process, as it used to.
- Extra GUT options run in one process and are passed through, for example `tools/test.sh -gselect=test_static_typing` to run one test script, or `-gtest=res://path/to/test_x.gd` for one file.

The command exits non-zero when any test fails, or when the run leaks: Godot says at exit that something was never freed (conventions, "The run ends clean").

## Static typing

Untyped declarations are compile errors in all project code except third-party addons (`project.godot`, `debug/gdscript/warnings`). The engine folder is explicitly included, and `test_static_typing.gd` guards that this stays true.
