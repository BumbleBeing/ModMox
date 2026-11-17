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
