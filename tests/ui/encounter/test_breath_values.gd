extends GutTest
## Each Portrait's Breath Rate and Breath Intensity, kept in a table the breath lab saves.

const FILE: String = "user://test_breath_values.json"


func after_each() -> void:
	if FileAccess.file_exists(FILE):
		DirAccess.remove_absolute(FILE)


func test_a_portrait_is_known_by_its_file_name() -> void:
	var urza: Texture2D = load("res://ui/sprites/portraits/urza_academy_headmaster.png")

	assert_eq(BreathValues.key_of(urza), "urza_academy_headmaster")
	assert_eq(BreathValues.key_of(null), "")


func test_a_portrait_not_in_the_table_breathes_at_one_and_one() -> void:
	var values: BreathValues = BreathValues.load_from(FILE)

	assert_eq(values.rate_of("nobody"), 1.0)
	assert_eq(values.intensity_of("nobody"), 1.0)


func test_saved_values_are_read_back() -> void:
	var values: BreathValues = BreathValues.load_from(FILE)
	values.set_values("charmed_stray", 1.6, 0.5)
	values.save_to(FILE)

	var again: BreathValues = BreathValues.load_from(FILE)
	assert_eq(again.rate_of("charmed_stray"), 1.6)
	assert_eq(again.intensity_of("charmed_stray"), 0.5)
	assert_eq(again.rate_of("nobody"), 1.0)
