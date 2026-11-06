extends GutTest
## Guards conventions hard rules 4 and 6 (ADR 0003, ADR 0006): engine source never uses
## the global RNG or the clock, and never awaits, uses signals, or extends Node.

const SOURCE_ROOT: String = "res://addons/modmox_rules/src"
const FORBIDDEN: Dictionary[String, String] = {
	"(?<![\\w.])(randi|randf|randi_range|randf_range|randfn|randomize|seed|rand_from_seed)\\s*\\(": "the global RNG",
	"\\.(shuffle|pick_random)\\s*\\(": "an Array method that uses the global RNG",
	"\\bTime\\.|\\bOS\\.get_(ticks|unix)": "the clock",
	"\\bawait\\b": "await",
	"^\\s*signal\\b": "a signal",
	"^\\s*extends\\s+Node": "a Node",
}


func test_engine_source_follows_the_determinism_rules() -> void:
	var scripts: PackedStringArray = _find_scripts(SOURCE_ROOT)
	assert_gt(scripts.size(), 0)
	var patterns: Dictionary[RegEx, String] = {}
	for pattern: String in FORBIDDEN:
		patterns[RegEx.create_from_string(pattern)] = FORBIDDEN[pattern]

	for path: String in scripts:
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for line_index: int in lines.size():
			var code: String = _strip_comment(lines[line_index])
			for regex: RegEx in patterns:
				if regex.search(code) != null:
					fail_test("%s:%d uses %s: %s" % [path, line_index + 1, patterns[regex], code.strip_edges()])
	pass_test("Scanned %d scripts." % scripts.size())


func _strip_comment(line: String) -> String:
	var hash_index: int = line.find("#")
	return line if hash_index == -1 else line.substr(0, hash_index)


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
