extends GutTest
## The cards of the opening-hand overlay move: a hand is dealt from the library, a card put
## down goes back to it, the card under the cursor rises, and when the pregame ends the
## hand flies down to its strip.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const SCREEN: Vector2 = Vector2(1920, 1080)
const SECONDS: float = 0.3
const GAP: float = 0.06
const FRAME: float = 0.01
const NEAR: float = 1.0

var _presenter: EncounterPresenter
var _screen: EncounterScreen
var _overlay: OpeningHandOverlay


func after_each() -> void:
	await wait_process_frames(2)


func test_a_new_hand_is_dealt_from_the_library_face_down_a_card_at_a_time() -> void:
	_open()
	var ids: Array[int] = _overlay.shown_ids()
	assert_eq(ids.size(), 7)

	for object_id: int in ids:
		assert_almost_eq(_foot(object_id), _library_foot(), Vector2(NEAR, NEAR), "Card %d starts on the library." % object_id)
		assert_almost_eq(_overlay.face_of(object_id).scale.x * _overlay.face_of(object_id).size.y, EncounterLayout.PILE_HEIGHT, NEAR,
			"As small as the pile.")
		assert_eq(_overlay.back_of(object_id).modulate.a, 1.0, "Face down.")
	_wait(0.05)
	assert_gt(_foot(ids[0]).distance_to(_library_foot()), 5.0, "The first has left,")
	assert_almost_eq(_foot(ids[1]), _library_foot(), Vector2(NEAR, NEAR), "the second not yet.")
	var first: CardFace = _overlay.face_of(ids[0])
	assert_almost_eq(first.rotation, _overlay.motion().pose_of(ids[0]).turn, 0.0001, "It turns with its flight,")
	assert_between(absf(first.rotation), 0.001, absf(EncounterLayout.opening_hand_turns(7, 7)[0]) - 0.001, "part of the way so far.")
	_wait(SECONDS + GAP * 6.0)

	var places: Array[Rect2] = EncounterLayout.opening_hand_cards(7, 7, Rect2(Vector2.ZERO, _overlay.size))
	var turns: Array[float] = EncounterLayout.opening_hand_turns(7, 7)
	for index: int in ids.size():
		var face: CardFace = _overlay.face_of(ids[index])
		assert_almost_eq(face.position, places[index].position, Vector2(NEAR, NEAR), "Card %d is in its place." % index)
		assert_almost_eq(face.scale, Vector2.ONE, Vector2(0.001, 0.001))
		assert_almost_eq(face.rotation, turns[index], 0.01, "Fanned.")
		assert_null(_overlay.back_of(ids[index]), "Face up.")


func test_while_cards_are_in_the_air_the_cursor_is_on_none_and_a_click_chooses_none() -> void:
	_open()
	_press("Mulligan")
	_wait(2.0)
	_press("Keep 6")
	var ids: Array[int] = _overlay.shown_ids()
	_overlay.hover_at(_overlay.center_of(ids[4]))
	assert_eq(_overlay.hovered_id(), ids[4], "At rest a card answers to the cursor.")

	_overlay.click_at(_overlay.center_of(ids[4]))
	_screen.undo_button().pressed.emit()
	assert_true(_overlay.motion().is_moving(), "The card taken back is on its way home.")
	_overlay.hover_at(_overlay.center_of(ids[1]))

	assert_eq(_overlay.hovered_id(), OpeningHandOverlay.NONE, "No card is under the cursor,")
	assert_null(BorderEffects.glow_color(_overlay.face_of(ids[1])) if not _overlay.can_go_down(ids[1]) else null)
	_overlay.click_at(_overlay.center_of(ids[1]))
	assert_true(_overlay.shown_ids().has(ids[1]), "and a click puts none down.")
	assert_not_null(_overlay.button("Confirm"), "The buttons are still there to press.")
	_wait(SECONDS + 0.05)
	_overlay.hover_at(_overlay.center_of(ids[1]))
	assert_eq(_overlay.hovered_id(), ids[1], "Once everything has landed the cursor finds a card again.")
	_overlay.click_at(_overlay.center_of(ids[1]))
	assert_false(_overlay.shown_ids().has(ids[1]))


func test_no_card_answers_to_the_cursor_while_the_hand_is_dealt() -> void:
	_open()
	_wait(0.1)

	_overlay.hover_at(_overlay.center_of(_overlay.shown_ids()[0]))

	assert_eq(_overlay.hovered_id(), OpeningHandOverlay.NONE)
	_wait(SECONDS + GAP * 6.0)
	_overlay.hover_at(_overlay.center_of(_overlay.shown_ids()[0]))
	assert_eq(_overlay.hovered_id(), _overlay.shown_ids()[0])


func test_the_buttons_can_be_pressed_while_the_cards_are_still_dealt() -> void:
	_open()
	_wait(0.05)

	_press("Keep 7")

	assert_gt(_presenter.snapshot().view.game_turn, 0, "The Hero is never made to wait (A410).")


func test_a_redraw_in_the_middle_of_the_deal_does_not_start_it_again() -> void:
	_open()
	_wait(0.2)
	var first: int = _overlay.shown_ids()[0]
	var reached: Vector2 = _foot(first)

	_screen._redraw()

	assert_almost_eq(_foot(first), reached, Vector2(NEAR, NEAR))
	assert_not_null(_overlay.back_of(_overlay.shown_ids()[6]), "The last card is still face down.")


func test_without_a_pace_every_card_is_at_its_place_at_once() -> void:
	_open(0.0)

	var places: Array[Rect2] = EncounterLayout.opening_hand_cards(7, 7, Rect2(Vector2.ZERO, _overlay.size))
	for index: int in 7:
		assert_eq(_overlay.face_of(_overlay.shown_ids()[index]).position, places[index].position)
		assert_null(_overlay.back_of(_overlay.shown_ids()[index]))


func test_a_mulligan_sends_the_old_hand_back_before_the_new_one_is_dealt() -> void:
	_open()
	_wait(1.0)
	var old: Array[int] = _overlay.shown_ids()
	var was_at: Vector2 = _foot(old[3])

	_press("Mulligan")

	var dealt: Array[int] = _overlay.shown_ids()
	assert_eq(dealt.size(), 7)
	for object_id: int in old:
		assert_false(dealt.has(object_id), "It is a new hand.")
		assert_not_null(_overlay.leaving_face_of(object_id), "The old card is still drawn, on its way out.")
	assert_almost_eq(_leaving_foot(old[3]), was_at, Vector2(NEAR, NEAR), "From where it was.")
	_wait(0.15)
	assert_gt(_leaving_foot(old[3]).distance_to(was_at), 5.0, "It is on its way to the library,")
	assert_gt(_overlay.back_of(old[3]).modulate.a, 0.0, "turning face down,")
	assert_almost_eq(_foot(dealt[0]), _library_foot(), Vector2(NEAR, NEAR), "and no new card has left yet.")
	_wait(0.2)
	assert_null(_overlay.leaving_face_of(old[3]), "Gone.")
	assert_gt(_foot(dealt[0]).distance_to(_library_foot()), 5.0, "Now the new hand is dealt.")


func test_a_card_put_down_slides_to_the_library_and_the_row_eases_closed() -> void:
	_open()
	_press("Mulligan")
	_wait(2.0)
	_press("Keep 6")
	var before: Array[int] = _overlay.shown_ids()
	var chosen: int = before[2]
	var neighbor: int = before[3]
	var neighbor_at: Vector2 = _foot(neighbor)
	var chosen_at: Vector2 = _foot(chosen)

	_overlay.click_at(_overlay.center_of(chosen))

	assert_false(_overlay.shown_ids().has(chosen))
	assert_false(_overlay.can_go_down(chosen), "On its way it takes no click.")
	assert_almost_eq(_leaving_foot(chosen), chosen_at, Vector2(NEAR, NEAR), "It starts where it was.")
	assert_almost_eq(_foot(neighbor), neighbor_at, Vector2(NEAR, NEAR), "The row does not jump.")
	assert_false(_overlay.button("Confirm").disabled, "Confirm does not wait for it.")
	_wait(0.06)
	var closed: Rect2 = EncounterLayout.opening_hand_cards(7, 6, Rect2(Vector2.ZERO, _overlay.size))[2]
	var closed_foot: Vector2 = _overlay.position + closed.position + Vector2(closed.size.x / 2.0, closed.size.y)
	assert_between(_foot(neighbor).x, closed_foot.x + 1.0, neighbor_at.x - 1.0, "The row is easing closed, quickly: its trip is short.")
	assert_gt(_leaving_foot(chosen).distance_to(chosen_at), 5.0)
	_wait(0.3)
	assert_almost_eq(_foot(neighbor), closed_foot, Vector2(NEAR, NEAR))
	assert_null(_overlay.leaving_face_of(chosen), "It is gone when it arrives.")


func test_undo_slides_the_card_back_from_where_it_has_got_to() -> void:
	_open()
	_press("Mulligan")
	_wait(2.0)
	_press("Keep 6")
	var chosen: int = _overlay.shown_ids()[2]
	var home: Vector2 = _foot(chosen)
	_overlay.click_at(_overlay.center_of(chosen))
	_wait(0.15)
	var reached: Vector2 = _leaving_foot(chosen)

	_screen.undo_button().pressed.emit()

	assert_true(_overlay.shown_ids().has(chosen))
	assert_null(_overlay.leaving_face_of(chosen))
	assert_almost_eq(_foot(chosen), reached, Vector2(NEAR, NEAR))
	_wait(0.35)
	assert_almost_eq(_foot(chosen), home, Vector2(NEAR, NEAR))
	assert_null(_overlay.back_of(chosen), "Face up again.")


func test_the_card_under_the_cursor_rises_and_grows_and_is_found_where_it_is_drawn() -> void:
	_open(0.0)
	var object_id: int = _overlay.shown_ids()[3]
	var face: CardFace = _overlay.face_of(object_id)
	var rest: Vector2 = face.position
	var above: Vector2 = face.position + Vector2(face.size.x / 2.0, -face.size.y * 0.05)
	assert_eq(_overlay.card_at(above), OpeningHandOverlay.NONE, "Just above the card there is nothing.")

	_overlay.hover_at(_overlay.center_of(object_id))
	assert_eq(_overlay.lift_of(object_id), 0.0, "It does not jump.")
	_overlay.ease_cards(0.5)
	assert_almost_eq(_overlay.lift_of(object_id), 0.5, 0.001)
	_overlay.ease_cards(1.0)

	assert_almost_eq(face.scale.x, 1.0 + OpeningHandOverlay.HOVER_GROW, 0.001)
	assert_almost_eq(rest.y - face.position.y, face.size.y * OpeningHandOverlay.HOVER_RISE, 0.5)
	assert_eq(_overlay.card_at(above), object_id, "Risen, it is found there.")
	assert_almost_eq(_overlay.face_of(_overlay.shown_ids()[1]).scale.x, 1.0, 0.001, "The rest stay as they were.")

	_overlay.stop_hovering()
	_overlay.ease_cards(1.0)

	assert_almost_eq(face.scale.x, 1.0, 0.001)
	assert_almost_eq(face.position, rest, Vector2(0.5, 0.5))


func test_when_the_first_turn_begins_the_hand_flies_down_to_its_strip() -> void:
	_open()
	_screen.face_motion().seconds = 0.2
	_wait(1.0)
	var ids: Array[int] = _overlay.shown_ids()

	_press("Keep 7")
	var scrim: ColorRect = _overlay.scrim()

	assert_gt(_presenter.snapshot().view.game_turn, 0)
	assert_true(_presenter.snapshot().decision is PriorityDecision, "The Hero is asked at once.")
	assert_true(_overlay.is_closing())
	assert_eq(_overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE, "It takes no clicks meanwhile.")
	for object_id: int in ids:
		assert_true(_overlay.is_landing(object_id))
		assert_false(_screen.face_of(object_id).visible, "The strip shows no second copy of card %d." % object_id)
	_wait(SECONDS + 0.02)

	for object_id: int in ids:
		var strip: CardFace = _screen.face_of(object_id) as CardFace
		var flown: CardFace = _overlay.face_of(object_id)
		assert_almost_eq(_foot(object_id), strip.position + strip.pivot_offset, Vector2(2.0, 2.0), "Card %d has landed in its place." % object_id)
		assert_almost_eq(flown.scale.x * flown.size.y, strip.size.y, NEAR, "At the size of a card in hand.")
		assert_eq(flown.modulate.a, 1.0, "The cards do not fade.")
	await wait_seconds(0.12)
	assert_lt(scrim.modulate.a, 1.0, "The scrim fades around them.")
	await wait_seconds(0.3)

	assert_false(_overlay.visible)
	for object_id: int in ids:
		assert_false(_overlay.is_landing(object_id))
		assert_true(_screen.face_of(object_id).visible, "Now the strip has it.")


func test_without_a_pace_the_hand_is_in_its_strip_at_once() -> void:
	_open(0.0)
	var ids: Array[int] = _overlay.shown_ids()

	_press("Keep 7")

	assert_false(_overlay.visible)
	for object_id: int in ids:
		assert_true(_screen.face_of(object_id).visible)


## Opens a screen through the pregame whose overlay moves its cards over [param seconds],
## stepped by _wait() alone.
func _open(seconds: float = SECONDS) -> void:
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	add_child_autofree(_screen)
	_screen.set_process(false)
	_screen.size = SCREEN
	_overlay = _screen.opening_overlay()
	_overlay.set_process(false)
	_overlay.motion().seconds = seconds
	_overlay.motion().gap_seconds = GAP if seconds > 0.0 else 0.0
	_presenter = EncounterPresenter.new(Scenario.setup(), DefaultAnswerAgent.new())
	_presenter.set_auto_passing(false)
	_screen.begin(_presenter)
	_presenter.wait_until_idle()


func _wait(seconds: float) -> void:
	for frame: int in roundi(seconds / FRAME):
		_overlay.advance(FRAME)
		_overlay.ease_cards(EncounterLayout.ease_weight(OpeningHandOverlay.EASE, FRAME))


func _press(text: String) -> void:
	assert_not_null(_overlay.button(text), "There is a button reading \"%s\"." % text)
	if _overlay.button(text) != null:
		_overlay.button(text).pressed.emit()
	_presenter.wait_until_idle()


## The middle of the bottom edge of the card of the row that is [param object_id], on the
## screen: the point it turns about.
func _foot(object_id: int) -> Vector2:
	var face: CardFace = _overlay.face_of(object_id)
	return _overlay.position + face.position + face.pivot_offset


func _leaving_foot(object_id: int) -> Vector2:
	var face: CardFace = _overlay.leaving_face_of(object_id)
	return _overlay.position + face.position + face.pivot_offset


## Where the foot of the Hero's library card is on the screen.
func _library_foot() -> Vector2:
	var pile: Rect2 = EncounterLayout.regions(SCREEN)["hero_library"]
	return Vector2(pile.get_center().x, pile.position.y + EncounterLayout.PILE_HEIGHT)
