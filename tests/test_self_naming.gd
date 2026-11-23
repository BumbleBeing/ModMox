extends GutTest
## Guards the conventions' rules against a script naming itself (see "Tests", "The run ends
## clean"): a script that exports an Array or Dictionary of a script class, or that extends
## a script class, never uses its own class as a value. Godot 4.7.2 then fails to clear
## every script loaded earlier when it quits, if one script's compiling was the first to
## load that class and then this one, and the run ends with "ObjectDB instances were leaked".

const FOLDERS: Array[String] = [
	"res://addons/modmox_rules/", "res://addons/modmox_ai/", "res://run/", "res://ui/", "res://tools/",
	"res://tests/",
]

var _class_name: RegEx = RegEx.create_from_string("(?m)^class_name\\s+(\\w+)")
var _exported_container: RegEx = RegEx.create_from_string(
	"@export[^\\n]*?:\\s*(?:Array|Dictionary)\\[([^\\]]+)\\]")
var _extends: RegEx = RegEx.create_from_string("(?m)^extends\\s+(\\w+)")
var _comment_or_string: RegEx = RegEx.create_from_string("#[^\\n]*|\"(?:[^\"\\\\\\n]|\\\\.)*\"")


func test_no_script_that_exports_a_list_of_a_script_class_names_itself() -> void:
	var sources: Dictionary[String, String] = _sources_by_class()
	var classes: Array[String] = sources.keys()
	assert_gt(classes.size(), 200, "The scan found the project's classes.")
	var checked: Array[String] = []
	for own: String in classes:
		if _exports_a_list_of_a_script_class(sources[own], classes):
			checked.append(own)
			assert_false(_uses_itself_as_a_value(sources[own], own), "%s names itself." % own)

	assert_true(checked.has("StageDefinition"), "The scan found the scripts the rule is about.")
	assert_true(checked.has("MmCardDefinition"))


func test_no_script_that_extends_a_script_class_names_itself() -> void:
	var sources: Dictionary[String, String] = _sources_by_class()
	var classes: Array[String] = sources.keys()
	var checked: Array[String] = []
	for own: String in classes:
		if _extends_a_script_class(sources[own], classes):
			checked.append(own)
			assert_false(_uses_itself_as_a_value(sources[own], own), "%s names itself." % own)

	assert_true(checked.has("ActivateAbilityAction"), "The scan found the scripts the rule is about.")
	assert_true(checked.has("ProtectionAbility"))


func test_a_script_naming_itself_in_a_cast_a_check_a_list_or_a_call_is_found() -> void:
	for use: String in ["x as Probe", "x is Probe", "var all: Array[Probe] = []", "Probe.new()",
			"var seen: Dictionary[Probe, bool] = {}", "static func all() -> Array[Probe]:"]:
		assert_true(_uses_itself_as_a_value("class_name Probe\n\t%s\n" % use, "Probe"), use)


func test_a_script_declaring_something_of_its_own_class_is_not() -> void:
	for use: String in ["var original: Probe = null", "func copy() -> Probe:", "func is_same(other: Probe) -> bool:",
			"# a Probe", "return \"a Probe\"", "var probes: Array[ProbeKind] = []"]:
		assert_false(_uses_itself_as_a_value("class_name Probe\n\t%s\n" % use, "Probe"), use)


func test_only_an_exported_list_of_a_script_class_counts() -> void:
	var classes: Array[String] = ["Probe", "Other"]

	assert_true(_exports_a_list_of_a_script_class("@export var others: Array[Other] = []", classes))
	assert_true(_exports_a_list_of_a_script_class("@export var others: Dictionary[String, Other] = {}", classes))
	assert_false(_exports_a_list_of_a_script_class("var others: Array[Other] = []", classes))
	assert_false(_exports_a_list_of_a_script_class("@export var other: Other", classes))
	assert_false(_exports_a_list_of_a_script_class("@export var frames: Array[Texture2D] = []", classes))


func test_only_a_script_that_extends_a_script_class_counts() -> void:
	var classes: Array[String] = ["Probe", "Other"]

	assert_true(_extends_a_script_class("class_name Probe\nextends Other\n", classes))
	assert_false(_extends_a_script_class("class_name Probe\nextends RefCounted\n", classes))
	assert_false(_extends_a_script_class("class_name Probe\n## It extends Other.\n", classes))


## Whether [param source] extends one of [param classes].
func _extends_a_script_class(source: String, classes: Array[String]) -> bool:
	var found: RegExMatch = _extends.search(source)
	return found != null and classes.has(found.get_string(1))


## Whether [param source] exports an Array or Dictionary of one of [param classes].
func _exports_a_list_of_a_script_class(source: String, classes: Array[String]) -> bool:
	for found: RegExMatch in _exported_container.search_all(source):
		for type: String in found.get_string(1).split(","):
			if classes.has(type.strip_edges()):
				return true
	return false


## Whether [param source], the script of the class [param own], uses that class as a
## value: anywhere but its class_name line and the type of a variable, a parameter or a
## return.
func _uses_itself_as_a_value(source: String, own: String) -> bool:
	var code: String = _comment_or_string.sub(source, "", true)
	code = RegEx.create_from_string("(?m)^class_name\\s+%s\\b" % own).sub(code, "", true)
	code = RegEx.create_from_string("(?::|->)\\s*%s\\b" % own).sub(code, "", true)
	return RegEx.create_from_string("\\b%s\\b" % own).search(code) != null


## The source of every script with a class_name, by that name.
func _sources_by_class() -> Dictionary[String, String]:
	var sources: Dictionary[String, String] = {}
	for folder: String in FOLDERS:
		_collect(folder, sources)
	return sources


func _collect(folder: String, sources: Dictionary[String, String]) -> void:
	for sub: String in DirAccess.get_directories_at(folder):
		_collect(folder + sub + "/", sources)
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			var source: String = FileAccess.get_file_as_string(folder + file)
			var found: RegExMatch = _class_name.search(source)
			if found != null:
				sources[found.get_string(1)] = source
