# ModMox

A roguelike RPG built around a Magic-style rules engine, made in Godot 4.7.2 with GDScript.

## Layout

- `addons/modmox_rules/`: the rules engine, independent of the game ([glossary](addons/modmox_rules/GLOSSARY.md), [decisions](addons/modmox_rules/docs/adr/), [roadmap](addons/modmox_rules/docs/roadmap.md))
- `addons/gut/`: GUT 9.7.1, the unit test framework (third party, MIT)
- `tools/`: developer scripts
- [GLOSSARY-MAP.md](GLOSSARY-MAP.md): how the game and engine vocabularies relate

## Running the tests

The engine's tests run headless from the command line. Point `GODOT` at the Godot 4.7.2 executable if it is not on your `PATH` as `godot`:

```bash
GODOT=~/Desktop/Godot_v4.7.2-stable_linux.x86_64 tools/test.sh
```

Extra GUT options are passed through, for example `tools/test.sh -gselect=test_static_typing` to run one test script. The command exits non-zero when any test fails.

## Static typing

Untyped declarations are compile errors in all project code except third-party addons (`project.godot`, `debug/gdscript/warnings`). The engine folder is explicitly included, and `test_static_typing.gd` guards that this stays true.
