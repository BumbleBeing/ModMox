extends GutTest
## Screens turns the Screen RunFlow says comes next into the scene to open.


func test_every_screen_of_a_run_is_a_scene_that_exists() -> void:
	for screen: RunFlow.Screen in RunFlow.Screen.values():
		if screen == RunFlow.Screen.NONE:
			continue

		var scene: String = Screens.scene(screen)

		assert_true(ResourceLoader.exists(scene), "%s is %s." % [RunFlow.Screen.keys()[screen], scene])


func test_none_opens_no_scene() -> void:
	assert_eq(Screens.scene(RunFlow.Screen.NONE), "")
