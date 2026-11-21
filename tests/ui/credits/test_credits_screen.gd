extends GutTest
## The Credits (milestone 19, signed off as step 3 of prototypes/run_ends): the roll rising on
## its own at a fixed pace and holding on "Thanks for playing", Main Menu and Art
## Attribution at the top, and the Art Attribution page scrolled by the mouse wheel.

const SCREEN: Vector2 = Vector2(1920, 1080)

var _screen: CreditsScreen
var _went_to: Array[String] = []


func before_each() -> void:
	_went_to = []
	RunFlow.clear()


func after_each() -> void:
	RunFlow.clear()
	CreditsScreen.has_left = false
	StageMapScreen.has_left = false
	await wait_process_frames(2)


func _open() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(SCREEN)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	_screen = CreditsScreen.new()
	_screen.starts_itself = false
	_screen.navigate = func(scene: String) -> void: _went_to.append(scene)
	viewport.add_child(_screen)
	_screen.size = SCREEN
	_screen.set_process(false)
	_screen.begin()
	await wait_process_frames(2)


func _click(target: Control) -> void:
	var spot: Vector2 = target.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = spot
		click.global_position = spot
		_screen.get_viewport().push_input(click)
	await wait_process_frames(1)


func _wheel_down(times: int) -> void:
	for index: int in times:
		for pressed: bool in [true, false]:
			var wheel: InputEventMouseButton = InputEventMouseButton.new()
			wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
			wheel.pressed = pressed
			wheel.factor = 1.0
			wheel.position = SCREEN / 2.0
			wheel.global_position = SCREEN / 2.0
			_screen.get_viewport().push_input(wheel)
	await wait_process_frames(2)


## S8: the roll rises on its own at PACE pixels a second, from just below the screen.
func test_the_roll_rises_on_its_own_at_a_fixed_pace() -> void:
	await _open()
	assert_eq(_screen.roll_top(), SCREEN.y)

	_screen.advance(2.0)

	assert_almost_eq(_screen.roll_top(), SCREEN.y - CreditsScreen.PACE * 2.0, 0.01)
	assert_eq(CreditsScreen.PACE, 60.0)


## S8: the same pace whatever the Game Speed: the roll is real time, and the screen has no
## Game Speed to scale it by.
func test_the_roll_keeps_its_pace_whatever_the_game_speed() -> void:
	await _open()

	assert_false("game_speed" in _screen)
	_screen.advance(3.0)
	assert_almost_eq(_screen.roll_top(), SCREEN.y - CreditsScreen.PACE * 3.0, 0.01)


## S8: the mouse wheel does not move the roll.
func test_the_mouse_wheel_does_not_move_the_roll() -> void:
	await _open()
	_screen.advance(5.0)
	var top: float = _screen.roll_top()

	await _wheel_down(5)

	assert_eq(_screen.roll_top(), top)


## S8: the roll holds with "Thanks for playing" at the middle of the screen.
func test_the_roll_holds_with_thanks_for_playing_at_the_middle() -> void:
	await _open()

	_screen.advance(1000.0)
	await wait_process_frames(1)

	var thanks: Label = _screen.roll_label("Thanks for playing")
	assert_not_null(thanks)
	assert_almost_eq(thanks.get_global_rect().get_center().y, SCREEN.y / 2.0, 1.0)
	var top: float = _screen.roll_top()
	_screen.advance(10.0)
	assert_eq(_screen.roll_top(), top, "It holds there.")


## The roll says what was agreed, Godot's license under "Made with Godot Engine".
func test_the_roll_says_what_was_agreed() -> void:
	await _open()
	var said: Array[String] = _screen.roll_texts()

	assert_eq(said[0], "ModMox")
	assert_has(said, "A game by Jackson 'BumbleBeing' Cmelak")
	assert_has(said, "Made with Godot Engine")
	assert_has(said, "This game uses Godot Engine, available under the following license:")
	assert_has(said, "Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.")
	assert_has(said, "The artists whose work the game borrows are named under Art Attribution, at the top right.")
	assert_has(said, "Linux Libertine by Philipp H. Poll, under the SIL Open Font License")
	assert_has(said, "TeX Gyre Schola by the GUST e-foundry, under the GUST Font License")
	assert_true(said.has("ModMox is unofficial Fan Content permitted under the Fan Content Policy. Not approved/endorsed "
			+ "by Wizards. Portions of the materials used are property of Wizards of the Coast. ©Wizards of the Coast LLC."))
	assert_eq(said[-1], "Thanks for playing")
	assert_lt(said.find("Made with Godot Engine"), said.find("Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur."))


## Main Menu stands at the top left and Art Attribution at the top right, of one size.
func test_the_two_buttons_stand_at_the_top_corners_alike() -> void:
	await _open()
	var main_menu: Rect2 = _screen.main_menu_button().get_global_rect()
	var toggle: Rect2 = _screen.page_button().get_global_rect()

	assert_eq(_screen.main_menu_button().text, "Main Menu")
	assert_eq(_screen.page_button().text, "Art Attribution")
	assert_eq(main_menu.size, toggle.size)
	assert_almost_eq(main_menu.position.x, CreditsScreen.MARGIN, 1.0)
	assert_almost_eq(SCREEN.x - toggle.end.x, CreditsScreen.MARGIN, 1.0)
	assert_eq(main_menu.position.y, toggle.position.y)


## S9: Art Attribution opens from its button, which then reads "Credits", and lists the art.
func test_art_attribution_opens_from_its_button() -> void:
	await _open()

	await _click(_screen.page_button())

	assert_true(_screen.is_attribution_open())
	assert_eq(_screen.page_button().text, "Credits")
	assert_has(_screen.attribution_texts(), "Card Art")
	assert_has(_screen.attribution_texts(), "Portraits")
	assert_false(_screen.attribution_texts().has("Emblem Art"))
	assert_has(_screen.attribution_texts(), "Lightning Bolt — Christopher Rush, LEA #161")


## S10: the mouse wheel scrolls Art Attribution, and "Credits" returns to the roll from the
## top.
func test_the_wheel_scrolls_art_attribution_and_credits_returns_to_the_roll() -> void:
	await _open()
	_screen.advance(12.0)
	await _click(_screen.page_button())

	await _wheel_down(4)

	assert_gt(_screen.attribution_scroll(), 0)
	await _click(_screen.page_button())
	assert_false(_screen.is_attribution_open())
	assert_eq(_screen.page_button().text, "Art Attribution")
	assert_eq(_screen.roll_top(), SCREEN.y, "From the top.")


## S11: Main Menu on the Credits goes to the main menu, and any run is over.
func test_main_menu_goes_to_the_main_menu() -> void:
	RunFlow.start(Run.debug(3))
	await _open()

	await _click(_screen.main_menu_button())

	assert_eq(_went_to, [Screens.MENU] as Array[String])
	assert_null(RunFlow.run)
	assert_true(CreditsScreen.has_left)


func test_the_credits_are_their_scene() -> void:
	var scene: Node = (load(Screens.CREDITS) as PackedScene).instantiate()
	assert_true(scene is CreditsScreen)
	scene.free()
