extends GutTest
## The Tap Preview and Auto-tap on the Encounter Screen (13e-3, ADR 0031): the cursor on
## something that costs mana leaves the blue Glow only on what would be tapped for it, and
## while the game pays, what is still to be tapped glows and the Info Panel says so.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const SCREEN: Vector2 = Vector2(1920, 1080)
## A place on the board with nothing on it.
const AWAY: Vector2 = Vector2(1000, 500)
const BLUE: Color = DecisionClicks.COLORS[DecisionClicks.Kind.MANA]
const MANA: int = 270

var _presenter: EncounterPresenter
var _screen: EncounterScreen
var _window: SubViewport
var _now: int = 1000


func after_each() -> void:
	await wait_process_frames(2)


func test_the_cursor_on_a_card_that_costs_mana_leaves_blue_only_on_what_it_would_tap() -> void:
	_open(_forests_and(_bear(2)), 3)
	var cast: int = _cast()
	var planned: Array[int] = _presenter.payment_plan(cast).source_ids
	assert_eq(_glowing_lands().size(), 3, "Before, every land that can be tapped glows.")
	var faces: Array[Control] = _land_faces()

	_point_at_card("Bear")

	assert_eq(_screen.previewed_answer(), cast)
	var glowing: Array[int] = _glowing_lands()
	glowing.sort()
	planned.sort()
	assert_eq(glowing, planned, "Only the two Forests it would tap.")
	assert_eq(_land_faces(), faces, "Nothing was rebuilt for it.")
	for land: int in _lands():
		assert_not_null(_screen.click_catcher(land), "Every land can still be tapped by hand.")

	_point(AWAY)

	assert_eq(_screen.previewed_answer(), EncounterScreen.NO_PREVIEW)
	assert_eq(_glowing_lands().size(), 3, "With the cursor gone, every Glow is back.")
	assert_eq(_land_faces(), faces)


func test_a_card_that_costs_no_mana_and_a_land_change_no_glow() -> void:
	_open(_forests_and(_bear(0)), 2)

	_point_at_card("Bear")
	assert_eq(_screen.previewed_answer(), EncounterScreen.NO_PREVIEW, "A free spell has nothing to preview.")
	assert_eq(_glowing_lands().size(), 2)

	_point(AWAY)
	_point_at_card("Forest")
	assert_eq(_screen.previewed_answer(), EncounterScreen.NO_PREVIEW)
	assert_eq(_glowing_lands().size(), 2, "Sweeping the cursor along a hand of lands makes nothing blink.")
	_point(AWAY)


func test_there_is_no_preview_with_the_hold_key_down_or_auto_tap_off() -> void:
	_open(_forests_and(_bear(2)), 3)
	_point_at_card("Bear")
	assert_eq(_glowing_lands().size(), 2)

	_screen.set_hold_key_down(true)
	_screen.follow_preview(0.0)
	assert_eq(_screen.previewed_answer(), EncounterScreen.NO_PREVIEW, "The Hero is going to pay this one by hand.")
	assert_eq(_glowing_lands().size(), 3)
	_screen.set_hold_key_down(false)
	_screen.follow_preview(0.0)
	assert_eq(_glowing_lands().size(), 2)

	_presenter.set_auto_tapping(false)
	assert_eq(_screen.previewed_answer(), EncounterScreen.NO_PREVIEW)
	assert_eq(_glowing_lands().size(), 3)
	_point(AWAY)


func test_a_held_card_is_previewed_for_the_whole_drag_and_nothing_is_rebuilt() -> void:
	_open(_forests_and(_bear(2)), 3)
	var faces: Array[Control] = _land_faces()
	_point(AWAY)
	_settle()

	_screen.press_hand(_on_card("Bear"), false)
	_screen.drag_to(AWAY)
	_screen.follow_preview(0.0)

	assert_true(_screen.drag_card().is_holding())
	assert_eq(_screen.previewed_answer(), _cast(), "The cursor is nowhere near the hand, and the card is in it.")
	assert_eq(_glowing_lands().size(), 2)
	_screen.drag_to(Vector2(1000, 1040))
	_screen.follow_preview(0.0)
	assert_eq(_glowing_lands().size(), 2, "Over the hand's strip as much as above it.")
	assert_eq(_land_faces(), faces, "Nothing is rebuilt while a card is held.")
	_screen.cancel_drag()


func test_with_several_options_only_the_row_pointed_at_is_previewed() -> void:
	_open(_forests_and(_bear(2)), 3)
	var bear: MmObjectView = _in_hand("Bear")
	var options: Array[ClickOption] = _screen._clicks.hand_options_of(bear.id)
	_screen._clicks._hand_options[bear.id] = [options[0], ClickOption.new(options[0].answer, "Cast Bear another way")]

	_point_at_card("Bear")
	assert_eq(_screen.previewed_answer(), EncounterScreen.NO_PREVIEW, "A card with two ways shows neither until one is pointed at.")
	assert_eq(_glowing_lands().size(), 3)
	_screen.press_hand(_on_card("Bear"), true)
	assert_true(_screen.option_menu().is_open())
	_screen.follow_preview(0.0)
	assert_eq(_screen.previewed_answer(), EncounterScreen.NO_PREVIEW)

	_screen.option_menu().rows()[1].mouse_entered.emit()
	_screen.follow_preview(0.0)
	assert_eq(_screen.previewed_answer(), options[0].answer)
	assert_eq(_glowing_lands().size(), 2)

	_screen.option_menu().rows()[1].mouse_exited.emit()
	_screen.follow_preview(0.0)
	assert_eq(_glowing_lands().size(), 3)
	_screen.option_menu().close()
	_point(AWAY)


func test_the_cursor_on_a_permanent_previews_the_ability_it_offers() -> void:
	var troll: MmCardDefinition = Scenario.creature("Troll", 2, 2, [Scenario.regenerate_ability(Scenario.mana_cost(1))])
	_open(_forests_and(troll), 1)
	_presenter.answer(_cast())
	_presenter.wait_until_idle()
	_play_until(func() -> bool: return _lands().size() >= 2 and _tapped().is_empty() and _ability() != -1)
	var plan: PaymentPlan = _presenter.payment_plan(_ability())
	var face: Control = _screen.face_of(_permanent("Troll"))

	_point(face.get_global_rect().get_center())

	assert_eq(_screen.previewed_answer(), _ability())
	assert_eq(_glowing_lands(), plan.source_ids, "The one Forest it would tap.")
	assert_eq(BorderEffects.glow_color(face), DecisionClicks.color_of(DecisionClicks.Kind.ABILITY), "The Troll keeps its own Glow.")

	_point(_screen.face_of(_lands()[0]).get_global_rect().get_center())
	assert_eq(_screen.previewed_answer(), EncounterScreen.NO_PREVIEW, "A land offers only its mana, which costs none.")
	assert_eq(_glowing_lands().size(), 2)
	_point(AWAY)


func test_pool_mana_that_would_be_spent_glows_on_its_button() -> void:
	_open(_forests_and(_bear(2)), 3)
	var green: Button = _screen.player_panel(HERO).mana_button(MmMana.Type.GREEN)
	_presenter.answer(Scenario.activate_index(_presenter.snapshot().decision as PriorityDecision, _lands()[0]))
	assert_null(BorderEffects.glow_color(green), "At priority no mana button glows.")

	_point_at_card("Bear")

	assert_eq(BorderEffects.glow_color(green), BLUE, "The mana already made is spent first.")
	assert_true(green.disabled, "Shown, not offered.")
	assert_eq(_glowing_lands().size(), 1, "And one more Forest is tapped for the rest.")
	_screen._redraw()
	assert_eq(BorderEffects.glow_color(green), BLUE, "A redraw marks the pool again.")

	_point(AWAY)
	assert_null(BorderEffects.glow_color(green))


func test_a_card_under_a_window_is_not_previewed_through_it() -> void:
	_open(_forests_and(_bear(2)), 3)
	_point_at_card("Bear")
	assert_eq(_glowing_lands().size(), 2)
	var window: ZoneWindow = _screen.emblems_window(HERO)

	window.set_open(true)
	window.position = _on_card("Bear") - Vector2(50, 50)
	_screen.follow_preview(0.0)

	assert_eq(_screen.previewed_answer(), EncounterScreen.NO_PREVIEW, "The cursor is on the window, not the card.")
	assert_eq(_glowing_lands().size(), 3)
	window.set_open(false)
	_point(AWAY)


func test_a_redraw_and_a_new_snapshot_keep_the_preview_under_a_cursor_that_has_not_moved() -> void:
	_open(_forests_and(_bear(2)), 3)
	_point_at_card("Bear")
	var faces: Array[Control] = _land_faces()

	_screen._redraw()

	assert_ne(_land_faces(), faces, "The board was rebuilt.")
	assert_eq(_screen.previewed_answer(), _cast())
	assert_eq(_glowing_lands().size(), 2, "And drawn with the preview.")

	_presenter.toggle_stop(HERO, MmTurn.Step.UPKEEP)

	assert_eq(_screen.previewed_answer(), _cast(), "A new snapshot is asked about at once.")
	assert_eq(_glowing_lands().size(), 2)
	await wait_process_frames(2)
	_point(AWAY)


func test_while_the_game_pays_what_is_still_to_be_tapped_glows_and_the_info_panel_says_so() -> void:
	_open(_forests_and(_bear(3)), 3)
	_presenter.clock = func() -> int: return _now
	_presenter.mana_wait_msec = MANA

	_presenter.answer(_cast())

	assert_true(_presenter.is_paying_for_hero())
	assert_eq(_tapped().size(), 1)
	assert_eq(_glowing_lands().size(), 2, "The two Forests still to come.")
	for land: int in _lands():
		assert_null(_screen.click_catcher(land), "Nothing takes a click meanwhile.")
	assert_eq(_screen.info_panel().prompt_text(), "Paying for Bear")
	assert_eq(_screen.info_panel().owed_pip_names(), ["2"] as Array[String])
	assert_false(_screen.info_panel().is_dim())
	assert_true(_screen.undo_button().disabled)
	_now += MANA
	_presenter.poll()
	assert_eq(_glowing_lands().size(), 1)
	assert_eq(_screen.info_panel().owed_pip_names(), ["1"] as Array[String])

	_screen.info_panel().cancel_button().pressed.emit()

	assert_false(_presenter.is_paying_for_hero())
	assert_eq(_tapped().size(), 0, "Cancel takes the whole cast back.")
	assert_not_null(_in_hand("Bear"))
	assert_eq(_glowing_lands().size(), 3)
	await wait_process_frames(2)


func test_a_real_cursor_resting_on_a_card_brings_the_preview_and_leaving_takes_it_away() -> void:
	_open(_forests_and(_bear(2)), 3)
	_screen.set_process(true)
	_window.push_input(_motion(AWAY))
	await wait_process_frames(3)
	assert_eq(_glowing_lands().size(), 3)

	_window.push_input(_motion(_on_card("Bear")))
	await wait_process_frames(3)
	# The hand parted under the cursor; point at where the card is now.
	_window.push_input(_motion(_on_card("Bear")))
	await wait_process_frames(3)

	assert_eq(_screen.previewed_answer(), _cast(), "Asked for each frame, with no call from the test.")
	assert_eq(_glowing_lands().size(), 2)

	_window.push_input(_motion(AWAY))
	await wait_process_frames(3)
	assert_eq(_screen.previewed_answer(), EncounterScreen.NO_PREVIEW)
	assert_eq(_glowing_lands().size(), 3)


## Opens the screen in a viewport of its own, with Auto-tap on, and plays until the Hero
## has priority with at least [param lands] untapped lands, a spell to cast and an empty
## stack. The screen's own _process is off, so a test says when the cursor is looked at.
func _open(setup: MmEncounterSetup, lands: int) -> void:
	_now = 1000
	_window = SubViewport.new()
	_window.size = Vector2i(SCREEN)
	add_child_autofree(_window)
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	_window.add_child(_screen)
	_screen.set_process(false)
	_screen.size = SCREEN
	_presenter = EncounterPresenter.new(setup, DefaultAnswerAgent.new())
	_presenter.set_auto_passing(false)
	_presenter.set_auto_tapping(true)
	_screen.begin(_presenter)
	_presenter.wait_until_idle()
	_play_until(func() -> bool:
		return _lands().size() >= lands and _tapped().is_empty() and _cast() != -1 and _presenter.snapshot().view.stack.is_empty())
	_window.push_input(_motion(AWAY))
	_settle()


func _play_until(is_there: Callable) -> void:
	for step: int in 600:
		var snapshot: EncounterSnapshot = _presenter.snapshot()
		if snapshot.decision is PriorityDecision and is_there.call():
			return
		if snapshot.is_over():
			break
		_presenter.answer(Scenario.default_answer(snapshot.decision, true))
		_presenter.wait_until_idle()
	fail_test("The game never got there.")


## Moves the cursor to [param at] and has the screen look at it, as each frame would.
func _point(at: Vector2) -> void:
	_window.push_input(_motion(at))
	_settle()
	_screen.follow_preview(0.0)


## Rests the cursor on the card in hand named [param card_name], once the hand has parted
## around it.
func _point_at_card(card_name: String) -> void:
	_window.push_input(_motion(_on_card(card_name)))
	_settle()
	_point(_on_card(card_name))
	assert_eq(_screen.hand_card_under(_on_card(card_name)), _in_hand(card_name).card_id, "The cursor is on the %s." % card_name)


func _settle() -> void:
	for frame: int in 60:
		_screen._spread_hand(0.3)


func _motion(at: Vector2) -> InputEventMouseMotion:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	return motion


func _forests_and(card: MmCardDefinition) -> MmEncounterSetup:
	var cards: Array[MmCardDefinition] = []
	for index: int in 20:
		cards.append_array([Scenario.basic_land("Forest"), card])
	return Scenario.setup_with(cards, Scenario.copies(Scenario.vanilla("Card"), 40))


func _bear(generic: int) -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2, [], Scenario.mana_cost(generic))


## The Hero's view of the leftmost card in hand named [param card_name], or null.
func _in_hand(card_name: String) -> MmObjectView:
	for card_id: int in _screen.hand_order().cards():
		for card: MmObjectView in _presenter.snapshot().view.hand:
			if card.card_id == card_id and card.name == card_name:
				return card
	return null


## A place on the card in hand named [param card_name] that no other card covers.
func _on_card(card_name: String) -> Vector2:
	return _screen.face_of(_in_hand(card_name).id).position + Vector2(30, 60)


func _cast() -> int:
	var priority: PriorityDecision = _presenter.snapshot().decision as PriorityDecision
	if priority == null:
		return -1
	return Scenario.action_index(priority, func(action: MmAction) -> bool: return action is CastSpellAction)


func _ability() -> int:
	var snapshot: EncounterSnapshot = _presenter.snapshot()
	var priority: PriorityDecision = snapshot.decision as PriorityDecision
	if priority == null:
		return -1
	return Scenario.action_index(priority, func(action: MmAction) -> bool:
		return action is ActivateAbilityAction and not AutoPass.is_mana_ability(action, snapshot.view))


func _permanent(card_name: String) -> int:
	for permanent: MmObjectView in _presenter.snapshot().view.battlefield:
		if permanent.name == card_name and permanent.controller_id == HERO:
			return permanent.id
	return -1


## The Hero's lands, tapped or not.
func _lands() -> Array[int]:
	var ids: Array[int] = []
	for permanent: MmObjectView in _presenter.snapshot().view.battlefield:
		if permanent.controller_id == HERO and permanent.card_types.has(MmCardTypes.CardType.LAND):
			ids.append(permanent.id)
	return ids


func _tapped() -> Array[int]:
	var ids: Array[int] = []
	for permanent: MmObjectView in _presenter.snapshot().view.battlefield:
		if permanent.controller_id == HERO and permanent.is_tapped:
			ids.append(permanent.id)
	return ids


## The Hero's lands whose faces glow blue.
func _glowing_lands() -> Array[int]:
	var ids: Array[int] = []
	for land: int in _lands():
		if BorderEffects.glow_colors(_screen.face_of(land)).has(BLUE):
			ids.append(land)
	return ids


func _land_faces() -> Array[Control]:
	var faces: Array[Control] = []
	for land: int in _lands():
		faces.append(_screen.face_of(land))
	return faces
