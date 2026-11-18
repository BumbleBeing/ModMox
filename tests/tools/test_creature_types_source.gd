extends GutTest
## The card tool's `creature-types` command (engine ADR 0052): it reads Scryfall's catalog
## of creature types and writes the engine's CreatureTypes again, saying what changed.


func test_the_types_are_read_from_a_catalog_sorted_and_each_once() -> void:
	var catalog: Dictionary = {"object": "catalog", "total_values": 4, "data": ["Elf", "Cat", "Time Lord", "Cat"]}

	assert_eq(CreatureTypesSource.types_in(catalog), ["Cat", "Elf", "Time Lord"])


func test_what_is_not_a_catalog_has_no_types() -> void:
	assert_eq(CreatureTypesSource.types_in(null), [])
	assert_eq(CreatureTypesSource.types_in({"object": "error"}), [])
	assert_eq(CreatureTypesSource.types_in({"data": [3, "Cat"]}), ["Cat"])


func test_what_was_added_and_removed_is_found() -> void:
	var before: Array[String] = ["Cat", "Elf"]
	var now: Array[String] = ["Cat", "Wombat"]

	assert_eq(CreatureTypesSource.added(before, now), ["Wombat"])
	assert_eq(CreatureTypesSource.added(now, before), ["Elf"], "Removed.")


func test_the_source_it_writes_for_the_current_list_is_the_engines_file_as_it_is() -> void:
	var written: String = CreatureTypesSource.source_of(CreatureTypes.ALL)

	assert_eq(written, FileAccess.get_file_as_string(CreatureTypesSource.PATH))


func test_the_source_it_writes_lists_every_type_in_order_in_short_lines() -> void:
	var types: Array[String] = ["Assembly-Worker", "C'tan", "Cat", "Time Lord"]

	var written: String = CreatureTypesSource.source_of(types)

	assert_true(written.contains("\t\"Assembly-Worker\", \"C'tan\", \"Cat\", \"Time Lord\",\n]"), written)
	for line: String in written.split("\n"):
		assert_lte(line.length(), 100, line)
