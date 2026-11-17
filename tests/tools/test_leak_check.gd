extends GutTest
## tools/leak_check.sh, which tools/test.sh runs over a test run's output (conventions,
## "The run ends clean"): it fails when Godot said at exit that something was never freed,
## and prints what Godot said.

const SCRIPT: String = "res://tools/leak_check.sh"
const CLEAN: String = "Tests               2635\nPassing Tests       2635\n\n---- All tests passed! ----\n"
## What Godot 4.7.2 prints at exit for each kind of leak.
const WARNINGS: Array[String] = [
	"WARNING: 687 ObjectDB instances were leaked at exit (run with `--verbose` for details).",
	"ERROR: 271 resources still in use at exit (run with --verbose for details).",
	"ERROR: 21 RID allocations of type 'PN13RendererDummy14TextureStorage12DummyTextureE' were leaked at exit.",
	"ERROR: Pages in use exist at exit in PagedAllocator: N12VariantPools11BucketSmallE",
]

var _log: String = OS.get_cache_dir().path_join("modmox_leak_check_test.log")


func after_each() -> void:
	DirAccess.remove_absolute(_log)


func test_a_clean_run_passes_and_prints_nothing() -> void:
	var output: Array[String] = []

	var code: int = _check(CLEAN, output)

	assert_eq(code, 0)
	assert_eq(output[0], "")


func test_each_kind_of_leak_fails_the_run_and_is_printed() -> void:
	for warning: String in WARNINGS:
		var output: Array[String] = []

		var code: int = _check(CLEAN + warning + "\n", output)

		assert_eq(code, 1, warning)
		assert_string_contains(output[0], warning)
		assert_string_contains(output[0], "conventions.md")


## A test may speak of leaks, as this file does; only Godot's own lines at exit count.
func test_a_test_name_that_mentions_leaks_passes() -> void:
	var output: Array[String] = []

	var code: int = _check("* test_no_objectdb_instances_were_leaked_at_exit\n" + CLEAN, output)

	assert_eq(code, 0)


## Runs the check over [param text] saved as a run's output and returns its exit code,
## putting what it printed in [param output].
func _check(text: String, output: Array[String]) -> int:
	var file: FileAccess = FileAccess.open(_log, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return OS.execute("bash", [ProjectSettings.globalize_path(SCRIPT), _log], output, true)
