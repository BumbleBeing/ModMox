extends GutTest
## The Menu Soldier's node: it draws the frame his sequence is on, in whole pixels, from the
## first moment, lets time go by on its own, and chooses at random unless given a seed.


func test_he_stands_still_from_the_first_moment_in_whole_pixels() -> void:
	var soldier: MenuSoldier = _soldier(1)

	assert_eq(soldier.texture.resource_path, SoldierAnimations.SPRITES % SoldierAnimations.NEUTRAL)
	assert_eq(soldier.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(soldier.size, Vector2.ONE * MenuSoldier.SPRITE_SIZE * MenuSoldier.SCALE)
	assert_eq(soldier.mouse_filter, Control.MOUSE_FILTER_IGNORE, "he takes no clicks")


func test_he_shows_whatever_frame_his_sequence_is_on() -> void:
	var soldier: MenuSoldier = _soldier(2)
	var shown: Dictionary[String, bool] = {}

	for step: int in 400:
		soldier.advance(0.1)
		assert_eq(soldier.texture.resource_path, SoldierAnimations.SPRITES % soldier.sequence().frame())
		shown[soldier.sequence().frame()] = true

	assert_gt(shown.size(), 10, "he moves through many frames in forty seconds")


func test_time_goes_by_for_him_on_its_own() -> void:
	var soldier: MenuSoldier = _soldier(3)
	var before: float = soldier.sequence().seconds_until_flash()

	await wait_process_frames(3)

	assert_lt(soldier.sequence().seconds_until_flash(), before)


func test_he_tells_when_his_frame_changes_and_only_then() -> void:
	var soldier: MenuSoldier = _soldier(4)
	watch_signals(soldier)

	soldier.advance(0.1)
	assert_signal_not_emitted(soldier, "frame_changed", "still standing at the start")
	while soldier.sequence().frame() == SoldierAnimations.NEUTRAL:
		soldier.advance(0.05)

	assert_signal_emit_count(soldier, "frame_changed", 1)
	assert_signal_emitted_with_parameters(soldier, "frame_changed", [soldier.sequence().frame()])


func test_where_he_touches_the_ground_follows_his_feet_and_his_spear() -> void:
	var soldier: MenuSoldier = _soldier(5)
	var standing: Array[int] = soldier.contacts()
	var lifted: Dictionary[String, bool] = {}

	for step: int in 1200:
		soldier.advance(0.05)
		assert_eq_deep(soldier.contacts(), SoldierShadow.contacts_of(soldier.texture.get_image()))
		if soldier.contacts() != standing:
			lifted[soldier.sequence().frame()] = true

	assert_gt(lifted.size(), 0, "a foot or the spear lifts within a minute")


func test_his_shadow_flashes_on_the_frame_he_does() -> void:
	var soldier: MenuSoldier = _soldier(6)
	watch_signals(soldier)

	soldier.advance(soldier.sequence().seconds_until_flash() + 0.001)

	assert_true(SoldierAnimations.FLASH_COLORS.has(soldier.sequence().frame()))
	var flash: Color = SoldierAnimations.FLASH_COLORS[soldier.sequence().frame()]
	assert_eq(soldier.shadow().color_of(soldier.contacts()[0]), Color(flash, 0.5))
	assert_signal_emitted(soldier, "shadow_changed")


func test_without_a_seed_each_soldier_chooses_his_first_transition_at_random() -> void:
	var firsts: Dictionary[String, bool] = {}

	for count: int in 20:
		var soldier: MenuSoldier = MenuSoldier.new()
		firsts[soldier.sequence().animation()] = true
		soldier.free()

	assert_gt(firsts.size(), 1, "not the same one every time the game starts")


## A soldier in the tree, choosing with [param random_seed].
func _soldier(random_seed: int) -> MenuSoldier:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = random_seed
	var soldier: MenuSoldier = MenuSoldier.new(random)
	add_child_autofree(soldier)
	return soldier
