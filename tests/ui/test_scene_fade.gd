extends GutTest
## Scene Fade: the screen fades to black, the scene is swapped, and it fades back in, all
## in SceneFade.SECONDS. The swap is handed in, so these tests never leave the test
## runner's scene.

var _swaps: int = 0
var _alpha_at_swap: float = -1.0
var _fade: SceneFade = null


func before_each() -> void:
	_swaps = 0
	_alpha_at_swap = -1.0
	_fade = null


func after_each() -> void:
	if is_instance_valid(_fade):
		_fade.queue_free()


func _swap() -> void:
	_swaps += 1
	_alpha_at_swap = _fade.curtain().color.a


func _play() -> SceneFade:
	_fade = SceneFade.play(get_tree(), _swap)
	return _fade


func test_it_starts_clear_and_black_covers_the_screen_by_the_swap() -> void:
	_play()
	assert_almost_eq(_fade.curtain().color.a, 0.0, 0.01, "It begins clear.")
	await _fade.swapped
	assert_eq(_swaps, 1)
	assert_almost_eq(_alpha_at_swap, 1.0, 0.01, "The scene is swapped behind solid black.")
	assert_eq(_fade.curtain().color, Color(0, 0, 0, 1))


func test_it_fades_back_in_and_is_gone_once_its_time_is_up() -> void:
	var began: int = Time.get_ticks_msec()
	_play()
	await _fade.finished
	var took: float = (Time.get_ticks_msec() - began) / 1000.0
	assert_between(took, SceneFade.SECONDS - 0.05, SceneFade.SECONDS + 0.2)
	assert_almost_eq(_fade.curtain().color.a, 0.0, 0.01)
	await wait_process_frames(2)
	assert_false(is_instance_valid(_fade), "It takes itself away.")
	assert_null(SceneFade.playing_in(get_tree()))


func test_half_the_time_is_spent_fading_out() -> void:
	var began: int = Time.get_ticks_msec()
	_play()
	await _fade.swapped
	var took: float = (Time.get_ticks_msec() - began) / 1000.0
	assert_between(took, SceneFade.SECONDS / 2.0 - 0.05, SceneFade.SECONDS / 2.0 + 0.2)


func test_a_frame_that_hitches_does_not_cut_the_fade_short() -> void:
	_play()
	OS.delay_msec(400)
	await wait_process_frames(2)
	assert_lt(_fade.curtain().color.a, 0.5, "A 0.4 s frame takes no more than LONGEST_STEP of it.")


func test_a_whole_frame_is_drawn_solid_black_before_the_swap() -> void:
	# A slow swap holds the last frame drawn on the screen for as long as it takes, so that
	# frame must be solid black, not the old scene behind a black not quite done.
	var black_from: Array[int] = [-1]
	var swap_at: Array[int] = [-1]
	_fade = SceneFade.play(get_tree(), func() -> void: swap_at[0] = Engine.get_process_frames())
	while swap_at[0] < 0:
		await get_tree().process_frame
		if black_from[0] < 0 and _fade.curtain().color.a >= 1.0:
			black_from[0] = Engine.get_process_frames()
	assert_gt(black_from[0], -1, "It was solid black before the swap.")
	assert_gt(swap_at[0], black_from[0], "A frame went by solid black before the swap.")


func test_it_stays_solid_black_while_the_new_scene_is_slow_to_draw() -> void:
	_play()
	await _fade.swapped
	for frame: int in 4:
		OS.delay_msec(120)
		await wait_process_frames(1)
		assert_eq(_fade.curtain().color.a, 1.0, "Lagging frame %d after the swap." % frame)
	await _fade.finished
	assert_almost_eq(_fade.curtain().color.a, 0.0, 0.01, "It fades in once the frames are smooth.")


func test_it_does_not_wait_for_ever_on_a_scene_that_is_always_slow() -> void:
	_play()
	await _fade.swapped
	var began: int = Time.get_ticks_msec()
	while is_instance_valid(_fade) and _fade.curtain().color.a >= 1.0:
		OS.delay_msec(100)
		await wait_process_frames(1)
	var held: float = (Time.get_ticks_msec() - began) / 1000.0
	assert_between(held, SceneFade.LONGEST_HOLD - 0.15, SceneFade.LONGEST_HOLD + 0.3)


func test_it_is_drawn_over_everything_and_stops_the_mouse_over_the_whole_window() -> void:
	_play()
	assert_eq(_fade.layer, SceneFade.LAYER)
	assert_gt(SceneFade.LAYER, 100)
	assert_eq(_fade.curtain().mouse_filter, Control.MOUSE_FILTER_STOP)
	await wait_process_frames(1)
	assert_true(_fade.curtain().get_global_rect().encloses(get_viewport().get_visible_rect()))


func test_it_lives_on_the_window_so_the_swap_does_not_take_it_away() -> void:
	_play()
	assert_eq(_fade.get_parent(), get_tree().root)


func test_it_runs_while_the_game_is_paused() -> void:
	_play()
	assert_eq(_fade.process_mode, Node.PROCESS_MODE_ALWAYS)


func test_a_second_change_while_one_is_fading_is_dropped() -> void:
	_play()
	var again: SceneFade = SceneFade.play(get_tree(), _swap)
	assert_eq(again, _fade, "The one already playing is handed back.")
	await _fade.finished
	assert_eq(_swaps, 1)


func test_keys_pressed_during_a_fade_go_no_further() -> void:
	_play()
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	get_viewport().push_input(key)
	assert_true(get_viewport().is_input_handled())
