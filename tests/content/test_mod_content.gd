extends GutTest
## Every Mod and Hex in Content is well shaped (ADR 0029) and still reads as it did when it
## was added with /add-mod. ACCEPTED holds that text, so a later change to ModText or to a
## Modification's words shows here as a change to what a Mod says.

const CONTENT_ROOT: String = "res://content/mods/"
## Each Mod's file name and the text ModText wrote for it when it was accepted.
const ACCEPTED: Dictionary[String, String] = {
	"erupting": "Modified card gains \"Each creature you control has haste.\" and \"Whenever a creature you control enters, "
		+ "it deals 1 damage to each opponent.\" It costs {R} more to cast.",
	"flashy": "Modified card gains flash.",
	"holy": "Modified card gets +1/+1 and gains flying and lifelink. It costs {W} more to cast.",
	"impervious": "Modified card gains indestructible. It costs {2} more to cast.",
	"immaterial": "Modified card gains \"This creature can't be blocked.\"",
	"unstoppable": "Modified card gets +1/+1 and gains trample and deathtouch. It costs {G} more to cast.",
	"untouchable": "Modified card gains first strike and deathtouch. It costs {B} more to cast.",
	"violent": "Modified card gets +1/+1 and gains haste and trample. It costs {R/G} more to cast.",
	"vexing": "Modified card gains \"This spell can't be countered.\"",
	"viscious": "Modified card gets +1/+0 and gains menace and deathtouch. It costs {B} more to cast.",
}


func test_every_mod_in_content_is_well_shaped() -> void:
	if _mod_files().is_empty():
		pass_test("No Mod is authored yet.")
	for file_name: String in _mod_files():
		var mod: Mod = _load(file_name)
		assert_not_null(mod, "%s is a Mod." % file_name)
		if mod != null:
			assert_eq(mod.problems(), [] as Array[String], file_name)


func test_every_mod_is_named_for_its_file_and_no_two_share_a_name() -> void:
	if _mod_files().is_empty():
		pass_test("No Mod is authored yet.")
	var seen: Dictionary[String, String] = {}
	for file_name: String in _mod_files():
		var mod: Mod = _load(file_name)
		if mod == null:
			continue
		assert_eq(file_name, mod.name.to_snake_case(), "A Mod's file is named for it.")
		assert_false(seen.has(mod.name), "%s and %s are both named %s." % [file_name, seen.get(mod.name, ""), mod.name])
		seen[mod.name] = file_name


func test_every_mod_reads_as_it_was_accepted() -> void:
	var files: Array[String] = _mod_files()
	if files.is_empty() and ACCEPTED.is_empty():
		pass_test("No Mod is authored yet.")
	for file_name: String in files:
		assert_true(ACCEPTED.has(file_name), "%s has no accepted text." % file_name)
		var mod: Mod = _load(file_name)
		if mod != null and ACCEPTED.has(file_name):
			assert_eq(ModText.of(mod), ACCEPTED[file_name], file_name)
	for file_name: String in ACCEPTED:
		assert_true(files.has(file_name), "Accepted text for %s, which has no file." % file_name)


func _load(file_name: String) -> Mod:
	return load(CONTENT_ROOT + file_name + ".tres") as Mod


## The file name of every Mod under CONTENT_ROOT, in order.
func _mod_files() -> Array[String]:
	var found: Array[String] = []
	if not DirAccess.dir_exists_absolute(CONTENT_ROOT):
		return found
	for file: String in DirAccess.get_files_at(CONTENT_ROOT):
		if file.ends_with(".tres"):
			found.append(file.get_basename())
	found.sort()
	return found
