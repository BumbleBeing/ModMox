extends GutTest
## The AI follows the engine's conventions (ADR 0020): its only randomness is the AI RNG,
## and it never reads the clock to decide anything (A159). The one clock read reports a
## slow decision as a warning.

const SOURCE_ROOT: String = "res://addons/modmox_ai/src"
const FORBIDDEN: Array[String] = ["randi(", "randf(", "randomize(", ".shuffle(", "pick_random(", "Time.", "OS.get_ticks"]
## file name → the forbidden text it may use, and why.
const ALLOWED: Dictionary[String, String] = {"ai_agent.gd": "Time."}


func test_the_ai_uses_no_other_randomness_and_no_clock() -> void:
	var dir: DirAccess = DirAccess.open(SOURCE_ROOT)
	assert_not_null(dir)
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".gd"):
			continue
		var source: String = FileAccess.get_file_as_string(SOURCE_ROOT.path_join(file_name))
		for forbidden: String in FORBIDDEN:
			if ALLOWED.get(file_name, "") == forbidden:
				continue
			assert_eq(source.find(forbidden), -1, "%s uses %s" % [file_name, forbidden])


func test_the_clock_only_ever_produces_a_warning() -> void:
	var source: String = FileAccess.get_file_as_string(SOURCE_ROOT.path_join("ai_agent.gd"))

	assert_eq(source.count("Time."), 2, "Start and end of answer(), passed only to _warn_if_slow().")
