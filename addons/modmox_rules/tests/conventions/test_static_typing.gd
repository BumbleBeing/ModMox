extends GutTest
## Guards ADR 0005: all engine GDScript is statically typed, enforced by
## treating untyped-declaration warnings as errors inside the engine folder.

const ENGINE_ROOT: String = "res://addons/modmox_rules"
## Engine source (not tests: GUT already fails any test script that does not compile,
## and re-loading the running test script from disk is unsafe).
const SOURCE_ROOT: String = ENGINE_ROOT + "/src"


func test_untyped_declaration_is_rejected_inside_engine() -> void:
	var probe: GDScript = _make_probe("__untyped_probe__.gd", "extends RefCounted\nvar untyped = 1\n")
	assert_ne(probe.reload(), OK, "An untyped declaration in the engine must fail to compile.")
	assert_engine_error("has no static type")


func test_typed_declaration_compiles_inside_engine() -> void:
	# Control for the test above: proves the failure comes from typing, not the probe setup.
	var probe: GDScript = _make_probe("__typed_probe__.gd", "extends RefCounted\nvar typed: int = 1\n")
	assert_eq(probe.reload(), OK, "A typed declaration in the engine must compile.")


func test_every_engine_source_script_compiles() -> void:
	var paths: PackedStringArray = _find_scripts(SOURCE_ROOT)
	assert_gt(paths.size(), 0, "Expected to find engine source scripts.")
	for path: String in paths:
		var script: GDScript = load(path) as GDScript
		assert_not_null(script, "Failed to load %s" % path)
		if script != null:
			assert_true(script.can_instantiate(), "Script does not compile: %s" % path)


## Builds an in-memory script "located" at a path inside the engine folder that does
## not exist on disk, so compiling it applies the engine's warning rules.
func _make_probe(file_name: String, source: String) -> GDScript:
	var probe: GDScript = GDScript.new()
	probe.source_code = source
	probe.resource_path = ENGINE_ROOT.path_join("tests").path_join(file_name)
	return probe


func _find_scripts(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return found
	for file_name: String in dir.get_files():
		if file_name.ends_with(".gd"):
			found.append(dir_path.path_join(file_name))
	for sub_dir: String in dir.get_directories():
		found.append_array(_find_scripts(dir_path.path_join(sub_dir)))
	return found
