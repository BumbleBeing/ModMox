extends GutTest
## The Deckbox screen (milestone 16, signed off as prototypes/deckbox): the list of Decks
## with the Active Deck's star, each Deck's color pips and card count, selecting a Deck and
## the buttons that act on it, the delete confirmation, and Start or Close.

var _run: Run
var _screen: DeckboxScreen
var _went_to: Array[String] = []


func before_each() -> void:
	_went_to = []
	RunFlow.clear()
	_run = Run.debug(11)


func after_each() -> void:
	RunFlow.clear()
	await wait_process_frames(2)


func _open(before_encounter: bool = true) -> void:
	_screen = DeckboxScreen.new()
	_screen.starts_itself = false
	_screen.navigate = func(scene: String) -> void: _went_to.append(scene)
	add_child_autofree(_screen)
	_screen.size = Vector2(1920, 1080)
	if before_encounter:
		while not _run.stage_visit.must_play():
			_run.move_to(_run.stage_visit.choices()[0])
	_screen.begin(_run, _run.stage_visit.meeting if before_encounter else null)
	await wait_process_frames(1)


## A second, illegal Deck after the debug run's Active one.
func _add_short_deck() -> Deck:
	var deck: Deck = Deck.new()
	deck.name = "Short"
	deck.card_ids.append(_run.collection.cards()[0].id)
	_run.deckbox.put(deck)
	return deck


func test_each_deck_has_a_row_in_the_deckbox_order() -> void:
	_add_short_deck()
	await _open()
	assert_eq(_screen.row_names(), ["Red-Green", "Short"] as Array[String])


func test_only_the_active_deck_shows_the_star() -> void:
	_add_short_deck()
	await _open()
	assert_true(_screen.row_has_star(0))
	assert_false(_screen.row_has_star(1))


func test_a_rows_count_is_red_only_under_forty_cards() -> void:
	_add_short_deck()
	await _open()
	assert_eq(_screen.row_count_text(0), "%d cards" % _run.deckbox.active().size())
	assert_false(_screen.is_row_count_red(0))
	assert_eq(_screen.row_count_text(1), "1 cards")
	assert_true(_screen.is_row_count_red(1))


func test_a_row_shows_a_pip_for_each_of_its_decks_colors() -> void:
	await _open()
	var expected: Array[MmCardTypes.CardColor] = _run.deckbox.colors_of(_run.deckbox.active(), _run.collection)
	assert_eq(expected, [MmCardTypes.CardColor.RED, MmCardTypes.CardColor.GREEN] as Array[MmCardTypes.CardColor])
	assert_eq(_screen.row_pips(0), ["r", "g"] as Array[String])


func test_the_buttons_that_act_on_a_deck_wait_for_one_to_be_selected() -> void:
	await _open()
	assert_false(_screen.button("New Deck").disabled)
	for text: String in DeckboxScreen.SELECTION_BUTTONS:
		assert_true(_screen.button(text).disabled, text)
	_screen.click_row(0)
	assert_eq(_screen.selected(), _run.deckbox.active())
	for text: String in ["Edit Deck", "Duplicate Deck", "Delete Deck"]:
		assert_false(_screen.button(text).disabled, text)


func test_set_active_is_off_for_the_active_deck_and_moves_the_star() -> void:
	var short: Deck = _add_short_deck()
	await _open()
	_screen.click_row(0)
	assert_true(_screen.button("Set Active").disabled)
	_screen.click_row(1)
	assert_false(_screen.button("Set Active").disabled)
	_screen.button("Set Active").pressed.emit()
	assert_eq(_run.deckbox.active(), short)
	assert_true(_screen.row_has_star(1))
	assert_false(_screen.row_has_star(0))


func test_start_is_off_while_the_active_deck_is_illegal() -> void:
	var short: Deck = _add_short_deck()
	await _open()
	assert_false(_screen.button("Start").disabled)
	_screen.click_row(1)
	_screen.button("Set Active").pressed.emit()
	assert_true(_screen.button("Start").disabled)
	assert_true(_run.deckbox.is_active(short))


func test_start_plays_the_encounter_against_the_villain_shown() -> void:
	await _open()
	var villain: Villain = _run.stage_visit.meeting
	assert_eq(_screen.villain_shown(), villain)
	_screen.button("Start").pressed.emit()
	assert_eq(_went_to, [DeckboxScreen.ENCOUNTER] as Array[String])
	assert_not_null(EncounterScreen.request)
	assert_eq(EncounterScreen.request.villain_setup, villain.setups[0])
	assert_eq(EncounterScreen.request.villain_name, villain.name)
	assert_eq(EncounterScreen.request.run, _run)


func test_opened_with_no_villain_it_has_close_and_a_centered_title() -> void:
	await _open(false)
	assert_null(_screen.button("Start"))
	assert_null(_screen.villain_shown())
	assert_eq(_screen.title_alignment(), HORIZONTAL_ALIGNMENT_CENTER)
	_screen.button("Close").pressed.emit()
	assert_eq(_went_to, [RunFlow.back_from_deckbox] as Array[String])


func test_close_leaves_even_with_an_illegal_active_deck() -> void:
	var short: Deck = _add_short_deck()
	_run.deckbox.set_active(short)
	await _open(false)
	assert_false(_screen.button("Close").disabled)
	_screen.button("Close").pressed.emit()
	assert_eq(_went_to.size(), 1)


func test_before_an_encounter_the_title_is_on_the_left() -> void:
	await _open()
	assert_eq(_screen.title_alignment(), HORIZONTAL_ALIGNMENT_LEFT)


func test_duplicate_deck_adds_a_copy_after_it_and_selects_it() -> void:
	await _open()
	_screen.click_row(0)
	_screen.button("Duplicate Deck").pressed.emit()
	assert_eq(_screen.row_names(), ["Red-Green", "Red-Green (copy)"] as Array[String])
	assert_eq(_screen.selected(), _run.deckbox.decks()[1])
	assert_true(_screen.row_has_star(0))


func test_delete_deck_asks_first_and_cancel_keeps_it() -> void:
	await _open()
	_screen.click_row(0)
	_screen.button("Delete Deck").pressed.emit()
	assert_true(_screen.is_confirming_delete())
	assert_string_contains(_screen.confirm_text(), "Red-Green")
	assert_string_contains(_screen.confirm_text(), "Active Deck")
	_screen.confirm_button("Cancel").pressed.emit()
	assert_false(_screen.is_confirming_delete())
	assert_eq(_run.deckbox.decks().size(), 1)


func test_deleting_the_active_deck_leaves_none_and_start_off() -> void:
	await _open()
	_screen.click_row(0)
	_screen.button("Delete Deck").pressed.emit()
	_screen.confirm_button("Delete Deck").pressed.emit()
	assert_false(_screen.is_confirming_delete())
	assert_true(_run.deckbox.decks().is_empty())
	assert_null(_run.deckbox.active())
	assert_null(_screen.selected())
	assert_true(_screen.button("Start").disabled)


func test_a_deck_that_is_not_active_is_deleted_without_the_active_line() -> void:
	_add_short_deck()
	await _open()
	_screen.click_row(1)
	_screen.button("Delete Deck").pressed.emit()
	assert_false(_screen.confirm_text().contains("Active Deck"))


func test_edit_deck_opens_the_selected_deck_in_the_deckbuilder() -> void:
	await _open()
	_screen.click_row(0)
	_screen.button("Edit Deck").pressed.emit()
	assert_eq(_went_to, [DeckboxScreen.DECKBUILDER] as Array[String])
	assert_eq(RunFlow.deck_to_edit, _run.deckbox.active())
	assert_true(RunFlow.is_editing)


func test_new_deck_opens_the_deckbuilder_on_a_new_deck() -> void:
	await _open()
	_screen.button("New Deck").pressed.emit()
	assert_eq(_went_to, [DeckboxScreen.DECKBUILDER] as Array[String])
	assert_null(RunFlow.deck_to_edit)
	assert_true(RunFlow.is_editing)


func test_a_real_click_on_a_row_selects_it() -> void:
	_add_short_deck()
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	_screen = DeckboxScreen.new()
	_screen.starts_itself = false
	_screen.navigate = func(scene: String) -> void: _went_to.append(scene)
	viewport.add_child(_screen)
	_screen.size = Vector2(1920, 1080)
	_screen.begin(_run, null)
	await wait_process_frames(3)
	var center: Vector2 = _screen.row_rect(1).get_center()
	for pressed: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = center
		click.global_position = center
		viewport.push_input(click)
	await wait_process_frames(1)
	assert_eq(_screen.selected(), _run.deckbox.decks()[1])


func test_clicking_the_selected_deck_again_unselects_it() -> void:
	await _open()
	_screen.click_row(0)
	assert_eq(_screen.selected(), _run.deckbox.active())
	_screen.click_row(0)
	assert_null(_screen.selected())
	for text: String in DeckboxScreen.SELECTION_BUTTONS:
		assert_true(_screen.button(text).disabled, text)


## The brightness of the middle of [param plate]'s top block.
func _top_light(plate: StyleBox) -> float:
	var image: Image = (plate as StyleBoxTexture).texture.get_image()
	return image.get_pixel(image.get_width() / 2, 8).get_luminance()


func test_a_row_under_the_cursor_is_lightened_and_goes_back_after() -> void:
	await _open()
	var plain: float = _top_light(_screen.row_plate(0))
	_screen.hover_row(0, true)
	var lit: float = _top_light(_screen.row_plate(0))
	assert_gt(lit, plain)
	_screen.hover_row(0, false)
	assert_almost_eq(_top_light(_screen.row_plate(0)), plain, 0.001)


func test_a_row_is_lightened_by_ten_percent() -> void:
	assert_eq(DeckboxScreen.HOVER_LIGHTEN, 0.10)
	assert_eq(DeckboxScreen.row_top(true), DeckboxScreen.row_top(false).lightened(0.10))


func test_a_buttons_hover_face_is_lightened_by_ten_percent() -> void:
	await _open()
	var made: Button = _screen.button("Start")
	assert_gt(_top_light(made.get_theme_stylebox("hover")), _top_light(made.get_theme_stylebox("normal")))
	var normal: StyleBoxTexture = DitherShading.button_plate(DeckbuilderLook.BUTTON, false, DeckboxScreen.BUTTON_HEIGHT)
	var hover: StyleBoxTexture = DitherShading.button_plate(DeckbuilderLook.BUTTON.lightened(0.10), false, DeckboxScreen.BUTTON_HEIGHT)
	assert_almost_eq(_top_light(made.get_theme_stylebox("normal")), _top_light(normal), 0.001)
	assert_almost_eq(_top_light(made.get_theme_stylebox("hover")), _top_light(hover), 0.001)


func test_a_disabled_button_has_no_lip_and_a_clickable_one_does() -> void:
	await _open()
	var made: Button = _screen.button("Start")
	var disabled: StyleBox = made.get_theme_stylebox("disabled")
	var normal: StyleBox = made.get_theme_stylebox("normal")

	assert_eq(disabled.content_margin_top, disabled.content_margin_bottom)
	assert_gt(normal.content_margin_bottom, normal.content_margin_top, "Its text sits above its lip.")


func test_a_selected_row_under_the_cursor_keeps_its_brass_edge() -> void:
	await _open()
	_screen.click_row(0)
	_screen.hover_row(0, true)
	var image: Image = (_screen.row_plate(0) as StyleBoxTexture).texture.get_image()
	assert_eq(image.get_pixel(image.get_width() / 2, 0), DeckbuilderLook.BRASS)
