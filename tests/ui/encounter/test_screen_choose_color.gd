extends GutTest
## Choosing the color of "Add one mana of any color" on the Encounter Screen (game ADR 0073).
## The Hero's Hoard, a free instant, makes a Treasure ("{T}, Sacrifice this token: Add one
## mana of any color."). Clicked, the Treasure opens the Option Menu with a row for each of
## its five colors, "Add {W}" to "Add {G}", all five in sight. While Savannah Lions is paid
## for by hand, the row whose color pays what is still owed, {W}, glows green; at priority no
## row glows. Pointing at a row shows the ability in full in the Info Panel.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const SCREEN: Vector2 = Vector2(1920, 1080)
## A place on the board with nothing on it.
const AWAY: Vector2 = Vector2(1000, 500)
const COLOR_ROWS: Array[String] = ["Add {W}", "Add {U}", "Add {B}", "Add {R}", "Add {G}"]

var _presenter: EncounterPresenter
var _screen: EncounterScreen
var _window: SubViewport


func after_each() -> void:
	# What a redraw replaced is freed at the end of the frame.
	await wait_process_frames(2)


func test_clicking_a_treasure_while_paying_for_savannah_lions_by_hand_opens_every_color_and_white_glows() -> void:
	_open_paying()
	assert_true(_presenter.snapshot().decision is PayManaDecision, "Auto-tap is off: the Hero pays by hand.")

	_click(_treasure())

	var menu: OptionMenu = _screen.option_menu()
	assert_true(menu.is_open())
	assert_eq(_words(menu), COLOR_ROWS)
	assert_eq(menu.words()[0].symbols(), ["w"] as Array[String], "Drawn as a pip.")
	var five: float = 5.0 * EncounterLayout.MENU_ROW + 4.0 * EncounterLayout.MENU_GAP + EncounterLayout.MENU_PAD * 2.0
	assert_eq(menu.box_rect().size.y, five, "All five colors in sight, none scrolled to.")
	var green: Color = DecisionClicks.color_of(DecisionClicks.Kind.PLAY)
	assert_eq(BorderEffects.glow_colors(menu.rows()[0]), [green] as Array[Color], "{W} pays what is owed.")
	for index: int in range(1, 5):
		assert_eq(BorderEffects.glow_colors(menu.rows()[index]), [] as Array[Color], "%s pays nothing." % COLOR_ROWS[index])
	assert_true(_presenter.snapshot().decision is PayManaDecision, "Nothing is paid until a row is chosen.")


func test_choosing_add_white_pays_for_savannah_lions() -> void:
	_open_paying()
	_click(_treasure())

	_screen.option_menu().rows()[0].pressed.emit()
	_presenter.wait_until_idle()

	assert_false(_screen.option_menu().is_open())
	assert_true(_presenter.snapshot().decision is PriorityDecision, "Paid in full, so cast.")
	assert_ne(_permanent("Savannah Lions"), -1, "Cast, and passed as the Hero's own spell is (ADR 0031).")
	assert_eq(_treasure(), -1, "Sacrificed.")
	assert_eq(_pool(), [] as Array[MmMana.Type])


func test_pointing_at_a_color_row_shows_the_ability_in_full_in_the_info_panel() -> void:
	_open_paying()
	_click(_treasure())
	var info: InfoPanel = _screen.info_panel()

	_screen.option_menu().rows()[0].mouse_entered.emit()

	assert_eq(info.option_text(), "{T}, Sacrifice this token: Add {W}.")
	assert_false(info.shows_prompt())

	_screen.option_menu().rows()[0].mouse_exited.emit()
	_screen.option_menu().rows()[3].mouse_entered.emit()

	assert_eq(info.option_text(), "{T}, Sacrifice this token: Add {R}.")
	_screen.option_menu().rows()[3].mouse_exited.emit()


func test_at_priority_every_color_is_offered_none_glows_and_its_mana_goes_to_the_pool() -> void:
	_open_with_a_treasure()

	_click(_treasure())

	var menu: OptionMenu = _screen.option_menu()
	assert_eq(_words(menu), COLOR_ROWS)
	for row: Button in menu.rows():
		assert_eq(BorderEffects.glow_colors(row), [] as Array[Color], "Every color can be chosen: nothing glows.")

	menu.rows()[4].pressed.emit()
	_presenter.wait_until_idle()

	assert_eq(_pool(), [MmMana.Type.GREEN] as Array[MmMana.Type])
	assert_eq(_treasure(), -1)


func test_pointing_at_a_color_row_previews_what_it_pays_as_any_other_row_does() -> void:
	# ADR 0031: the Tap Preview is the payment of the row the cursor is on. A mana ability
	# costs no mana, so there is nothing to show for a color, as for a land's row.
	_open_with_a_treasure()
	_presenter.set_auto_tapping(true)
	_click(_treasure())
	var menu: OptionMenu = _screen.option_menu()
	var white: int = _activation(MmMana.Type.WHITE)

	menu.rows()[0].mouse_entered.emit()
	_screen.follow_preview(0.0)

	assert_eq(menu.pointed_answer(), white, "The Tap Preview asks for the row the cursor is on.")
	assert_null(_presenter.payment_plan(white))
	assert_eq(_screen.previewed_answer(), EncounterScreen.NO_PREVIEW)
	menu.rows()[0].mouse_exited.emit()


func test_a_real_click_on_a_color_row_chooses_that_color() -> void:
	# Every new mouse input gets one test through the real pipeline: the row's words lie
	# over it and must leave it the click.
	_open_paying()
	var face: Rect2 = _screen.face_of(_treasure()).get_global_rect()
	# Low on the Treasure: the Stack Window, showing Savannah Lions, lies over its top.
	var on_treasure: Vector2 = Vector2(face.get_center().x, face.end.y - 12.0)
	_window.push_input(_motion(on_treasure))
	_window.push_input(_button(true, on_treasure))
	_window.push_input(_button(false, on_treasure))
	var menu: OptionMenu = _screen.option_menu()
	assert_true(menu.is_open(), "A real click on the Treasure opens the menu.")
	await wait_process_frames(2)  # The menu's list lays out its rows.
	var at: Vector2 = menu.rows()[0].get_global_rect().get_center()
	assert_true(menu.box_rect().has_point(at))

	_window.push_input(_motion(at))
	_window.push_input(_button(true, at))
	_window.push_input(_button(false, at))
	_presenter.wait_until_idle()

	assert_ne(_permanent("Savannah Lions"), -1, "Add {W} paid for it.")
	_window.push_input(_motion(AWAY))
	await wait_process_frames(3)


func test_x_closes_an_open_option_menu_at_priority_and_makes_no_mana() -> void:
	_open_with_a_treasure()
	_click(_treasure())
	assert_true(_screen.option_menu().is_open())

	_screen.press_key(KEY_X)
	_presenter.wait_until_idle()

	assert_false(_screen.option_menu().is_open())
	assert_ne(_treasure(), -1, "Nothing was chosen: the Treasure is still there.")
	assert_eq(_pool(), [] as Array[MmMana.Type])


func test_while_paying_x_closes_the_option_menu_first_and_cancels_the_cast_only_when_pressed_again() -> void:
	_open_paying()
	_click(_treasure())

	_screen.press_key(KEY_X)
	_presenter.wait_until_idle()

	assert_false(_screen.option_menu().is_open())
	assert_true(_presenter.snapshot().decision is PayManaDecision, "The cast goes on: only the menu closed.")
	assert_not_null(_screen.info_panel().cancel_button())

	_screen.press_key(KEY_X)
	_presenter.wait_until_idle()

	assert_true(_presenter.snapshot().decision is PriorityDecision, "With the menu closed, X cancels the cast.")
	assert_eq(_permanent("Savannah Lions"), -1)
	assert_ne(_treasure(), -1)


## Opens the screen and plays to the Hero's first main phase, where their Hoard has made a
## Treasure, and casts Savannah Lions, to be paid for by hand.
func _open_paying() -> void:
	_open_with_a_treasure()
	_cast("Savannah Lions")


## Opens the screen in a viewport of its own and plays to the Hero's main phase on Game Turn
## 1 with a Treasure their Hoard made and Savannah Lions in hand.
func _open_with_a_treasure() -> void:
	var treasure: MmCardDefinition = load("res://content/tokens/treasure.tres") as MmCardDefinition
	var lions: MmCardDefinition = load("res://content/cards/alpha/savannah_lions.tres") as MmCardDefinition
	var hero_deck: Array[MmCardDefinition] = Scenario.cycled([Scenario.free_tokens("Hoard", treasure), lions,
		Scenario.basic_land("Forest")])
	var villain_deck: Array[MmCardDefinition] = Scenario.copies(Scenario.basic_land("Forest"), 40)
	var chosen: MmEncounterSetup = null
	for encounter_seed: int in range(1, 400):
		var setup: MmEncounterSetup = Scenario.setup_with(hero_deck, villain_deck,
			MmEncounterSetup.StartingPlayerRule.HERO_STARTS, encounter_seed)
		var engine: MmEngine = MmEngine.start(setup)
		Scenario.keep_all(engine)
		var hero_hand: Array = Scenario.names(engine, engine.hero().hand)
		if hero_hand.has("Hoard") and hero_hand.has("Savannah Lions"):
			chosen = setup
			break
	assert_not_null(chosen, "No seed gave the needed cards.")
	_window = SubViewport.new()
	_window.size = Vector2i(SCREEN)
	add_child_autofree(_window)
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	_window.add_child(_screen)
	_screen.set_process(false)
	_screen.size = SCREEN
	_presenter = EncounterPresenter.new(chosen, DefaultAnswerAgent.new())
	_presenter.set_auto_passing(false)
	_screen.begin(_presenter)
	_presenter.wait_until_idle()
	_answer_pregame()
	_play_to(1)
	# The Hero's own spell is passed as soon as it is cast (ADR 0031), so the Hoard resolves.
	_cast("Hoard")
	_play_to(1)
	assert_ne(_treasure(), -1, "The Hoard made a Treasure.")


func _answer_pregame() -> void:
	if _presenter.snapshot().decision is ChoosePlayOrDrawDecision:
		_presenter.answer(ChoosePlayOrDrawDecision.Choice.PLAY)
		_presenter.wait_until_idle()
	_presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	_presenter.wait_until_idle()


## Passes until the Hero has priority with an empty stack in the main phase of Game Turn
## [param game_turn].
func _play_to(game_turn: int) -> void:
	for attempt: int in 200:
		var snapshot: EncounterSnapshot = _presenter.snapshot()
		if snapshot.decision is PriorityDecision and snapshot.view.game_turn == game_turn \
				and snapshot.view.step == MmTurn.Step.PRECOMBAT_MAIN and snapshot.view.stack.is_empty():
			return
		_presenter.pass_priority()
		_presenter.wait_until_idle()
	fail_test("Game Turn %d's main phase was never reached." % game_turn)


## Casts the Hero's card named [param card_name] from their hand.
func _cast(card_name: String) -> void:
	var snapshot: EncounterSnapshot = _presenter.snapshot()
	var priority: PriorityDecision = snapshot.decision as PriorityDecision
	for index: int in priority.actions.size():
		var cast: CastSpellAction = priority.actions[index] as CastSpellAction
		if cast != null and EncounterSnapshot.name_in(snapshot.view, cast.object_id) == card_name:
			assert_eq(_presenter.answer(index), "")
			_presenter.wait_until_idle()
			return
	fail_test("%s could not be cast." % card_name)


## The Hero's Treasure, or -1 once it is gone.
func _treasure() -> int:
	for permanent: MmObjectView in _presenter.snapshot().view.battlefield:
		if permanent.is_token and permanent.controller_id == HERO:
			return permanent.id
	return -1


## The answer that makes [param color] with the Hero's Treasure.
func _activation(color: MmMana.Type) -> int:
	var priority: PriorityDecision = _presenter.snapshot().decision as PriorityDecision
	return Scenario.action_index(priority, func(action: MmAction) -> bool:
		var activate: ActivateAbilityAction = action as ActivateAbilityAction
		return activate != null and activate.object_id == _treasure() and activate.mana_type == color)


func _click(object_id: int) -> void:
	var catcher: ClickCatcher = _screen.click_catcher(object_id)
	assert_not_null(catcher, "It can be clicked.")
	if catcher != null:
		catcher.clicked.emit()


func _words(menu: OptionMenu) -> Array:
	return menu.words().map(func(words: SymbolLabel) -> String: return words.written())


func _permanent(card_name: String) -> int:
	for permanent: MmObjectView in _presenter.snapshot().view.battlefield:
		if permanent.name == card_name and permanent.controller_id == HERO:
			return permanent.id
	return -1


func _pool() -> Array[MmMana.Type]:
	var types: Array[MmMana.Type] = []
	for unit: MmMana in _presenter.snapshot().view.mana_pools.get(HERO, []):
		types.append(unit.type)
	return types


func _motion(at: Vector2) -> InputEventMouseMotion:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	return motion


func _button(is_pressed: bool, at: Vector2) -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = is_pressed
	click.position = at
	click.global_position = at
	return click
