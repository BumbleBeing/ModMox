extends GutTest
## Every card in Content is held to its Oracle Data, kept in res://content/cards/oracle.json,
## but for its Rebalances (ADR 0040).

const CONTENT_ROOT: String = "res://content/cards/"


func test_every_card_file_has_oracle_data_and_every_entry_has_a_card_file() -> void:
	var entries: Dictionary = OracleData.new().entries
	var file_names: PackedStringArray = _card_files().keys()

	for file_name: String in file_names:
		assert_true(entries.has(file_name), "%s has no Oracle Data." % file_name)
	for file_name: String in entries:
		assert_true(file_names.has(file_name), "Oracle Data for %s, which has no card file." % file_name)
	assert_gt(file_names.size(), 40)


func test_every_card_matches_its_oracle_data_but_for_its_rebalances() -> void:
	var entries: Dictionary = OracleData.new().entries
	var files: Dictionary[String, String] = _card_files()

	for file_name: String in files:
		if not entries.has(file_name):
			continue
		var definition: MmCardDefinition = load(files[file_name]) as MmCardDefinition
		var entry: Dictionary = entries[file_name]

		assert_eq(OracleData.mismatches(definition, entry), PackedStringArray(), file_name)


## Every card file under CONTENT_ROOT, its file name → its path.
func _card_files(folder: String = CONTENT_ROOT) -> Dictionary[String, String]:
	var found: Dictionary[String, String] = {}
	for sub: String in DirAccess.get_directories_at(folder):
		found.merge(_card_files(folder + sub + "/"))
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(".tres"):
			found[file.get_basename()] = folder + file
	return found
