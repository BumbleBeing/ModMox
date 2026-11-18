extends GutTest
## CreatureTypes.ALL: every creature type there is (CR 205.3m), what "choose a creature
## type" offers (ADR 0052).


func test_there_are_377_creature_types() -> void:
	assert_eq(CreatureTypes.ALL.size(), 377)


func test_they_are_in_alphabetical_order_and_each_is_listed_once() -> void:
	var sorted: Array[String] = CreatureTypes.ALL.duplicate()
	sorted.sort()
	assert_eq(CreatureTypes.ALL, sorted)
	var seen: Dictionary[String, bool] = {}
	for creature_type: String in CreatureTypes.ALL:
		assert_false(seen.has(creature_type), "%s is listed twice." % creature_type)
		seen[creature_type] = true


func test_names_with_spaces_and_punctuation_are_listed_as_printed() -> void:
	for creature_type: String in ["Cat", "Time Lord", "C'tan", "Assembly-Worker"]:
		assert_true(CreatureTypes.is_creature_type(creature_type), creature_type)


func test_other_subtypes_are_not_creature_types() -> void:
	for subtype: String in ["Forest", "Equipment", "Aura", "cat"]:
		assert_false(CreatureTypes.is_creature_type(subtype), subtype)
