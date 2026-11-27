extends GutTest
## Every Armor in Content is well shaped (game ADR 0106) and still reads as it did when it was
## added with /add-armor. ACCEPTED holds those words, so a later change to
## StartingConditionText or AbilityText shows here as a change to what an Armor says.

const CONTENT_ROOT: String = "res://content/armor/"
const EMBLEMS: String = "res://content/emblems/"
const ICONS: String = "res://ui/sprites/armor/"
## Each Armor's file name and the words StartingConditionText wrote for it when it was
## accepted, a sentence for each Starting Condition, one to a line.
const ACCEPTED: Dictionary[String, String] = {
	"seers_cuirass": "You get an emblem with \"{2}{U}: Draw a card. Activate only as a sorcery and only once each game.\"",
}


## A11: every Armor in Content passes the shape check.
func test_every_armor_in_content_is_well_shaped() -> void:
	if _armor_files().is_empty():
		pass_test("No Armor is authored yet.")
	for file_name: String in _armor_files():
		var armor: Armor = _load(file_name)
		assert_not_null(armor, "%s is an Armor." % file_name)
		if armor != null:
			assert_eq(armor.problems(), [] as Array[String], file_name)


## A11: every Armor is named for its file, apostrophes dropped, and no two share a name.
func test_every_armor_is_named_for_its_file_and_no_two_share_a_name() -> void:
	if _armor_files().is_empty():
		pass_test("No Armor is authored yet.")
	var seen: Dictionary[String, String] = {}
	for file_name: String in _armor_files():
		var armor: Armor = _load(file_name)
		if armor == null:
			continue
		assert_eq(file_name, armor.name.to_snake_case().replace("'", ""), "An Armor's file is named for it.")
		assert_false(seen.has(armor.name), "%s and %s are both named %s." % [file_name, seen.get(armor.name, ""), armor.name])
		seen[armor.name] = file_name


## A11: an Armor's icon is the one named for it in the Armor sprites, and its Emblem, if it
## has one, is the one named for it in the Emblems, with its name.
func test_every_armors_icon_and_emblem_are_named_for_it() -> void:
	if _armor_files().is_empty():
		pass_test("No Armor is authored yet.")
	for file_name: String in _armor_files():
		var armor: Armor = _load(file_name)
		if armor == null:
			continue
		if armor.icon != null:
			assert_eq(armor.icon.resource_path, ICONS + file_name + ".png", file_name)
		var emblems: Array[MmCardDefinition] = []
		for condition: StartingCondition in armor.starting_conditions:
			if condition is EmblemStartingCondition and (condition as EmblemStartingCondition).emblem != null:
				emblems.append((condition as EmblemStartingCondition).emblem)
		assert_lt(emblems.size(), 2, "%s brings one Emblem at most, holding every ability it gives." % file_name)
		for emblem: MmCardDefinition in emblems:
			assert_eq(emblem.resource_path, EMBLEMS + file_name + ".tres", file_name)
			assert_eq(emblem.name, armor.name, "%s's Emblem has its name." % file_name)


## A11: every Armor reads as it did when it was accepted.
func test_every_armor_reads_as_it_was_accepted() -> void:
	var files: Array[String] = _armor_files()
	if files.is_empty() and ACCEPTED.is_empty():
		pass_test("No Armor is authored yet.")
	for file_name: String in files:
		assert_true(ACCEPTED.has(file_name), "%s has no accepted words." % file_name)
		var armor: Armor = _load(file_name)
		if armor != null and ACCEPTED.has(file_name):
			assert_eq("\n".join(StartingConditionText.lines_of(armor.starting_conditions)), ACCEPTED[file_name], file_name)
	for file_name: String in ACCEPTED:
		assert_true(files.has(file_name), "Accepted words for %s, which has no file." % file_name)


func _load(file_name: String) -> Armor:
	return load(CONTENT_ROOT + file_name + ".tres") as Armor


## The file name of every Armor under CONTENT_ROOT, in order.
func _armor_files() -> Array[String]:
	var found: Array[String] = []
	if not DirAccess.dir_exists_absolute(CONTENT_ROOT):
		return found
	for file: String in DirAccess.get_files_at(CONTENT_ROOT):
		# An exported game lists a resource as "name.tres.remap".
		var armor: String = file.trim_suffix(".remap")
		if armor.ends_with(".tres"):
			found.append(armor.get_basename())
	found.sort()
	return found
