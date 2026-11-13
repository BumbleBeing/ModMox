extends GutTest
## A Backdrop (game glossary) is the one picture behind an Encounter Screen: a picture file
## named for it if there is one, and a placeholder drawn by a shader if not (ADR 0035).

const PICTURES: String = "res://tests/ui/backdrops/support/"


func test_the_backdrops_are_plain_and_the_five_colors() -> void:
	assert_eq(Backdrops.NAMES, ["plain", "white", "blue", "black", "red", "green"] as Array[String])


func test_plain_has_no_backdrop() -> void:
	assert_null(Backdrops.make(Backdrops.PLAIN))


func test_each_color_has_a_placeholder_of_its_own() -> void:
	var kinds: Array[int] = []
	for backdrop: String in Backdrops.NAMES:
		if backdrop == Backdrops.PLAIN:
			continue
		var made: Control = autofree(Backdrops.make(backdrop)) as Control
		assert_not_null(made, backdrop)
		var material: ShaderMaterial = made.material as ShaderMaterial
		assert_not_null(material, "%s is drawn by the shader." % backdrop)
		var kind: int = material.get_shader_parameter("kind")
		assert_does_not_have(kinds, kind, "%s is not drawn as another is." % backdrop)
		kinds.append(kind)
		assert_eq(made.mouse_filter, Control.MOUSE_FILTER_IGNORE)

	assert_eq(kinds.size(), 5)


func test_a_picture_named_for_a_backdrop_is_drawn_instead_with_hard_edges() -> void:
	var made: TextureRect = autofree(Backdrops.make("red", PICTURES)) as TextureRect

	assert_not_null(made, "The picture is drawn, not the placeholder.")
	assert_eq(made.texture, load(PICTURES + "red.png"))
	assert_eq(made.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(made.stretch_mode, TextureRect.STRETCH_SCALE, "It fills the screen, which is always 16:9.")
	assert_eq(made.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_a_backdrop_with_no_picture_in_a_folder_of_pictures_keeps_its_placeholder() -> void:
	var made: Control = autofree(Backdrops.make("green", PICTURES)) as Control

	assert_true(made.material is ShaderMaterial)


func test_a_picture_is_six_times_smaller_than_the_screen() -> void:
	assert_eq(Backdrops.SIZE, Vector2i(320, 180))
	assert_eq(Backdrops.SIZE * 6, Vector2i(1920, 1080))


func test_the_game_is_always_drawn_at_sixteen_to_nine() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "keep")
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 1920)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 1080)
