extends GutTest
## Selecting a card with a right-click, reading cards in the inspector, and the Mod Slots
## drawn on the faces.

const OUTSIDE: Vector2 = Vector2(170, 900)

var _sample: DeckbuilderSample
var _screen: DeckbuilderScreen
var _deck: WorkingDeck


func before_each() -> void:
	_sample = DeckbuilderSample.make()
	_screen = DeckbuilderScreen.new()
	_screen.starts_itself = false
	add_child_autofree(_screen)
	_screen.size = Vector2(1920, 1080)
	_screen.begin(_sample)
	_deck = _screen.working_deck()
	await wait_process_frames(2)


func after_each() -> void:
	await wait_process_frames(2)


func test_nothing_is_selected_at_first_and_the_inspector_says_how_to_use_it() -> void:
	assert_null(_screen.selected())
	assert_null(_screen.inspected())
	assert_null(_screen.inspector_face())
	assert_null(_screen.modify_button())


func test_a_right_click_selects_a_card_and_holds_it_in_the_inspector() -> void:
	var lions: DeckbuilderCard = _spare("Savannah Lions")

	_screen.right_click_at(_in_collection(lions))
	_screen.drag_to(OUTSIDE)

	assert_eq(_screen.selected(), lions)
	assert_eq(_screen.inspected(), lions)
	assert_eq(_screen.inspector_face().title_text().shown_text(), "Savannah Lions")
	assert_true(_screen.is_ringed(_screen.collection_face(lions)))
	assert_false(_deck.contains(lions), "A right-click moves nothing.")
	assert_null(_screen.held_face())


func test_a_selected_deck_card_is_ringed_in_its_column_and_in_the_collection() -> void:
	var bolt: DeckbuilderCard = _deck.cards_in(1)[1]

	_screen.right_click_at(_strip_of(bolt))

	assert_eq(_screen.selected(), bolt)
	assert_true(_screen.is_ringed(_screen.column_face(bolt)))
	assert_true(_screen.is_ringed(_screen.collection_face(bolt)))
	assert_false(_screen.is_ringed(_screen.column_face(_deck.cards_in(1)[0])))


func test_only_one_card_is_selected_at_a_time() -> void:
	var lions: DeckbuilderCard = _spare("Savannah Lions")
	var bolt: DeckbuilderCard = _deck.cards_in(1)[1]
	_screen.right_click_at(_in_collection(lions))

	_screen.right_click_at(_strip_of(bolt))

	assert_eq(_screen.selected(), bolt)
	assert_false(_screen.is_ringed(_screen.collection_face(lions)))


func test_a_second_right_click_a_right_click_on_nothing_and_escape_each_let_go() -> void:
	var lions: DeckbuilderCard = _spare("Savannah Lions")
	var on_lions: Vector2 = _in_collection(lions)

	_screen.right_click_at(on_lions)
	_screen.right_click_at(on_lions)
	assert_null(_screen.selected(), "A second right-click on it.")
	assert_false(_screen.is_ringed(_screen.collection_face(lions)))

	_screen.right_click_at(on_lions)
	_screen.right_click_at(OUTSIDE)
	assert_null(_screen.selected(), "A right-click on empty space.")

	_screen.right_click_at(on_lions)
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	_screen._input(escape)
	assert_null(_screen.selected(), "Escape.")


func test_real_right_clicks_select() -> void:
	var lions: DeckbuilderCard = _spare("Savannah Lions")
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = _in_collection(lions)

	_screen._input(click)

	assert_eq(_screen.selected(), lions)
	assert_null(_screen.held_face())


func test_the_inspector_shows_the_card_under_the_cursor_and_falls_back_to_the_selected_one() -> void:
	var lions: DeckbuilderCard = _spare("Savannah Lions")
	var bolt: DeckbuilderCard = _deck.cards_in(1)[1]

	_screen.drag_to(_strip_of(bolt))
	assert_eq(_screen.inspected(), bolt, "With nothing selected, hovering is enough.")
	assert_eq(_screen.inspector_face().title_text().shown_text(), "Lightning Bolt")

	_screen.drag_to(OUTSIDE)
	assert_null(_screen.inspected())
	assert_null(_screen.inspector_face())

	_screen.right_click_at(_in_collection(lions))
	_screen.drag_to(_strip_of(bolt))
	assert_eq(_screen.inspector_face().title_text().shown_text(), "Lightning Bolt", "Another card is previewed.")
	assert_eq(_screen.selected(), lions)

	_screen.drag_to(OUTSIDE)
	assert_eq(_screen.inspector_face().title_text().shown_text(), "Savannah Lions")


func test_the_inspector_is_not_redrawn_while_the_same_card_is_under_the_cursor() -> void:
	var lions: DeckbuilderCard = _spare("Savannah Lions")
	_screen.drag_to(_in_collection(lions))
	var face: CardFace = _screen.inspector_face()

	_screen.drag_to(_in_collection(lions) + Vector2(5, 5))

	assert_same(_screen.inspector_face(), face)


func test_modify_is_for_the_selected_card_while_it_has_an_empty_mod_slot() -> void:
	var lions: DeckbuilderCard = _spare("Savannah Lions")
	var full_bolt: DeckbuilderCard = _modded("Lightning Bolt", 3)

	_screen.drag_to(_in_collection(lions))
	assert_true(_screen.modify_button().disabled, "Only hovered, it is not selected.")

	_screen.right_click_at(_in_collection(lions))
	assert_false(_screen.modify_button().disabled)

	_screen.right_click_at(_strip_of(full_bolt))
	_screen.drag_to(OUTSIDE)
	assert_eq(_screen.selected(), full_bolt)
	assert_true(_screen.modify_button().disabled, "All three Mod Slots are filled.")

	var forest: DeckbuilderCard = _deck.cards_in(WorkingDeck.LANDS_COLUMN)[0]
	_screen.right_click_at(_strip_of(forest))
	_screen.drag_to(OUTSIDE)
	assert_true(_screen.modify_button().disabled, "A basic land cannot take Mods.")


func test_a_selected_basic_land_that_leaves_the_deck_is_let_go() -> void:
	var forest: DeckbuilderCard = _deck.cards_in(WorkingDeck.LANDS_COLUMN)[0]
	_screen.right_click_at(_strip_of(forest))

	_screen.double_click_at(_strip_of(forest))

	assert_null(_screen.selected())


func test_a_selected_collection_card_stays_selected_when_it_leaves_the_deck() -> void:
	var bolt: DeckbuilderCard = _deck.cards_in(1)[1]
	_screen.right_click_at(_strip_of(bolt))

	_screen.double_click_at(_strip_of(bolt))

	assert_eq(_screen.selected(), bolt)
	assert_true(_screen.is_ringed(_screen.collection_face(bolt)))


func test_mod_slots_are_filled_in_the_order_earned_green_for_a_mod_and_red_for_a_hex() -> void:
	assert_eq(ModSlotRow.slots_of(_modded("Lightning Bolt", 3)), [
		ModSlotRow.Slot.MOD, ModSlotRow.Slot.MOD, ModSlotRow.Slot.HEX,
	] as Array[ModSlotRow.Slot])
	assert_eq(ModSlotRow.slots_of(_modded("Craw Wurm", 1)), [
		ModSlotRow.Slot.HEX, ModSlotRow.Slot.EMPTY, ModSlotRow.Slot.EMPTY,
	] as Array[ModSlotRow.Slot])
	assert_eq(ModSlotRow.slots_of(_spare("Savannah Lions")), [
		ModSlotRow.Slot.EMPTY, ModSlotRow.Slot.EMPTY, ModSlotRow.Slot.EMPTY,
	] as Array[ModSlotRow.Slot])
	assert_eq(ModSlotRow.slots_of(_deck.cards_in(WorkingDeck.LANDS_COLUMN)[0]), [] as Array[ModSlotRow.Slot])
	assert_ne(ModSlotRow.color_of(ModSlotRow.Slot.MOD), ModSlotRow.color_of(ModSlotRow.Slot.HEX))


func test_every_face_but_a_basic_lands_shows_its_mod_slots_inside_the_card() -> void:
	var wurm: DeckbuilderCard = _modded("Craw Wurm", 1)
	var forest: DeckbuilderCard = _deck.cards_in(WorkingDeck.LANDS_COLUMN)[0]

	for face: CardFace in [_screen.collection_face(wurm), _screen.column_face(wurm)]:
		var row: ModSlotRow = _screen.mod_slots_on(face)
		assert_not_null(row)
		assert_eq(row.slots(), ModSlotRow.slots_of(wurm))
		assert_true(Rect2(Vector2.ZERO, face.size).encloses(Rect2(row.position, row.size)))
		assert_almost_eq(row.position.x + row.size.x / 2.0, face.size.x / 2.0, 0.01, "Centered along the bottom.")
		var bar_middle: float = face.size.y * (ModSlotRow.BAR_TOP + 1.0) / 2.0
		assert_almost_eq(row.get_rect().get_center().y, bar_middle - ModSlotRow.LIFT, 0.01,
				"One unit above the middle of the black bar under the frame.")
	assert_null(_screen.mod_slots_on(_screen.column_face(forest)))

	_screen.right_click_at(_strip_of(wurm))
	assert_null(_screen.mod_slots_on(_screen.inspector_face()), "The inspector lists them under the face instead.")


func test_a_held_card_shows_its_mod_slots_too() -> void:
	var lions: DeckbuilderCard = _spare("Savannah Lions")
	_screen.press_at(_in_collection(lions))

	_screen.drag_to(_in_collection(lions) + Vector2(40, 0))

	assert_not_null(_screen.mod_slots_on(_screen.held_face()))
	_screen.release_at(OUTSIDE)


func _strip_of(card: DeckbuilderCard) -> Vector2:
	return _screen.column_face(card).global_position + Vector2(40, 8)


func _in_collection(card: DeckbuilderCard) -> Vector2:
	return _screen.collection_face(card).get_global_rect().get_center()


## A plain copy of the card named [param card_name] that is not in the Deck.
func _spare(card_name: String) -> DeckbuilderCard:
	for card: DeckbuilderCard in _sample.collection.cards():
		if card.run_card.base.name == card_name and card.mods.is_empty() and not _deck.contains(card):
			return card
	return null


## The copy of the card whose base is named [param card_name] that has [param mods] Mods.
func _modded(card_name: String, mods: int) -> DeckbuilderCard:
	for card: DeckbuilderCard in _sample.collection.cards():
		if card.run_card.base.name == card_name and card.mods.size() == mods:
			return card
	return null


func test_modify_opens_the_mod_pop_up_for_the_selected_card() -> void:
	var lions: DeckbuilderCard = _spare("Savannah Lions")
	_screen.right_click_at(_in_collection(lions))

	_screen.modify_button().pressed.emit()

	assert_not_null(_screen.mod_popup())
	assert_eq(_screen.mod_popup().before_face().title_text().shown_text(), "Savannah Lions")
	assert_eq(_screen.mod_popup().z_index, 10, "Over everything, a raised card included.")


func test_nothing_behind_the_pop_up_takes_clicks_and_escape_closes_it() -> void:
	var lions: DeckbuilderCard = _spare("Savannah Lions")
	_screen.right_click_at(_in_collection(lions))
	_screen.modify_button().pressed.emit()

	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = _strip_of(_deck.cards_in(1)[0])
	_screen._input(click)
	assert_eq(_screen.selected(), lions)

	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	_screen._input(escape)
	assert_null(_screen.mod_popup())
	assert_eq(_screen.selected(), lions, "Escape closed the pop-up and left the selection.")


func test_applying_a_mod_uses_it_up_and_changes_the_card_everywhere_at_once() -> void:
	var bears: DeckbuilderCard = _deck.cards_in(2)[2]
	assert_eq(bears.look().name, "Grizzly Bears")
	assert_eq(bears.mods.size(), 0)
	var ember: Mod = _held("Ember")
	var held_before: int = _sample.held_mods.count_of(ember)
	_screen.right_click_at(_strip_of(bears))
	_screen.drag_to(OUTSIDE)
	_screen.modify_button().pressed.emit()

	_screen.mod_popup().choose(ember)
	_screen.mod_popup().button("apply").pressed.emit()
	_screen.mod_popup().button("yes").pressed.emit()

	assert_null(_screen.mod_popup())
	assert_eq(bears.mods, [ember] as Array[Mod])
	assert_eq(_sample.held_mods.count_of(ember), held_before - 1)
	assert_eq(bears.mana_value(), 3)
	assert_eq(_deck.column_of(bears), 2, "It stays in the column it was in.")
	assert_false(_deck.has_unsaved_changes(), "Applying a Mod has nothing to do with saving.")
	for face: CardFace in [_screen.column_face(bears), _screen.collection_face(bears), _screen.inspector_face()]:
		assert_eq(face.get_parent() != null, true)
	assert_eq(_screen.mod_slots_on(_screen.column_face(bears)).slots()[0], ModSlotRow.Slot.MOD)
	assert_eq(_screen.mod_slots_on(_screen.collection_face(bears)).slots()[0], ModSlotRow.Slot.MOD)
	assert_true(_screen.is_ringed(_screen.column_face(bears)), "It is still selected.")
	assert_almost_eq(_screen.column_face(bears).position.y, _screen.layout().fan_offset(2), 0.01)
	await wait_process_frames(2)


func test_closing_the_pop_up_applies_nothing() -> void:
	var lions: DeckbuilderCard = _spare("Savannah Lions")
	_screen.right_click_at(_in_collection(lions))
	_screen.modify_button().pressed.emit()
	_screen.mod_popup().choose(_held("Ember"))

	_screen.mod_popup().button("cancel").pressed.emit()
	_screen.mod_popup().button("close").pressed.emit()

	assert_null(_screen.mod_popup())
	assert_eq(lions.mods.size(), 0)
	assert_eq(_sample.held_mods.count_of(_held("Ember")), 2)


func test_modify_goes_gray_when_the_last_mod_slot_is_filled() -> void:
	var two: DeckbuilderCard = _spare("Savannah Lions")
	two.attach(_held("Moss"))
	two.attach(_held("Tide"))
	_screen.right_click_at(_in_collection(two))
	_screen.modify_button().pressed.emit()

	_screen.mod_popup().choose(_held("Ember"))
	_screen.mod_popup().button("apply").pressed.emit()
	_screen.mod_popup().button("yes").pressed.emit()
	_screen.drag_to(OUTSIDE)

	assert_eq(two.mods.size(), 3)
	assert_true(_screen.modify_button().disabled)
	_screen.open_mod_popup()
	assert_null(_screen.mod_popup())
	await wait_process_frames(2)


## The held Mod named [param mod_name].
func _held(mod_name: String) -> Mod:
	for mod: Mod in _sample.held_mods.kinds():
		if mod.name == mod_name:
			return mod
	return null
