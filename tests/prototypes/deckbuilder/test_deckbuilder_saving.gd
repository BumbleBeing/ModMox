extends GutTest
## Naming, saving and leaving: the name box, Save and its notice, and Exit with the prompt
## it shows when there are unsaved changes.

const OUTSIDE: Vector2 = Vector2(170, 900)

var _sample: DeckbuilderSample
var _screen: DeckbuilderScreen
var _deck: WorkingDeck
var _went_to: Array[String] = []


func before_each() -> void:
	_went_to = []
	_sample = DeckbuilderSample.make()
	_screen = DeckbuilderScreen.new()
	_screen.starts_itself = false
	_screen.navigate = func(scene: String) -> void: _went_to.append(scene)
	add_child_autofree(_screen)
	_screen.size = Vector2(1920, 1080)
	_screen.begin(_sample)
	_deck = _screen.working_deck()
	await wait_process_frames(2)


func after_each() -> void:
	await wait_process_frames(2)


func test_typing_in_the_name_box_renames_the_working_deck() -> void:
	_type_name("Stompy Two")

	assert_eq(_deck.name, "Stompy Two")
	assert_eq(_saved().name, "Red-Green Stompy", "Nothing is saved yet.")


func test_save_is_there_to_press_only_while_there_is_something_to_save() -> void:
	assert_true(_screen.save_button().disabled)

	_screen.land_button("Forest").pressed.emit()
	assert_false(_screen.save_button().disabled)

	_screen.double_click_at(_strip_of(_deck.cards_in(WorkingDeck.LANDS_COLUMN)[0]))
	assert_true(_screen.save_button().disabled, "Back to nine Forests, it is as it was saved.")

	_type_name("Stompy Two")
	assert_false(_screen.save_button().disabled)


func test_moving_cards_between_columns_is_nothing_to_save() -> void:
	var bolt: DeckbuilderCard = _deck.cards_in(1)[0]

	_screen.press_at(_strip_of(bolt))
	_screen.drag_to(_column_point(5))
	_screen.release_at(_column_point(5))

	assert_eq(_deck.column_of(bolt), 5)
	assert_true(_screen.save_button().disabled)


func test_saving_writes_the_deck_to_the_deckbox_and_stays_on_the_screen() -> void:
	_screen.land_button("Forest").pressed.emit()
	_type_name("  Stompy Two ")

	_screen.save_button().pressed.emit()

	assert_eq(_sample.deckbox.decks().size(), 1, "It is the same Deck, saved again.")
	assert_eq(_saved().name, "Stompy Two")
	assert_eq(_saved().basic_lands["Forest"], 10)
	assert_eq(_screen.name_box().text, "Stompy Two", "The spaces around the name are gone.")
	assert_eq(_screen.notice(), "Saved to the Deckbox.")
	assert_true(_screen.save_button().disabled)
	assert_eq(_went_to, [] as Array[String])


func test_an_illegal_deck_is_saved_all_the_same() -> void:
	_screen.double_click_at(_strip_of(_deck.cards_in(1)[0]))
	assert_false(_deck.is_legal())

	_screen.save_button().pressed.emit()

	assert_eq(_saved().size(), 39)
	assert_eq(_screen.notice(), "Saved to the Deckbox.")


func test_a_deck_without_a_name_is_not_saved_and_the_notice_says_why() -> void:
	_type_name("   ")

	_screen.save_button().pressed.emit()

	assert_eq(_saved().name, "Red-Green Stompy")
	assert_eq(_screen.notice(), "A Deck needs a name.")
	assert_false(_screen.save_button().disabled)


func test_a_name_another_deck_has_is_refused() -> void:
	var other: Deck = Deck.new()
	other.name = "Blue Skies"
	_sample.deckbox.put(other)
	_type_name("blue skies")

	_screen.save_button().pressed.emit()

	assert_eq(_saved().name, "Red-Green Stompy")
	assert_string_contains(_screen.notice(), "already named")


func test_the_notice_fades_away() -> void:
	_screen.land_button("Forest").pressed.emit()
	_screen.save_button().pressed.emit()

	_screen._process(DeckbuilderScreen.NOTICE_TIME + 0.1)

	assert_eq(_screen.notice(), "")


func test_exit_with_nothing_to_save_goes_straight_to_the_main_menu() -> void:
	_screen.exit_button().pressed.emit()

	assert_null(_screen.exit_prompt())
	assert_eq(_went_to, [DeckbuilderScreen.MENU] as Array[String])
	assert_true(ResourceLoader.exists(DeckbuilderScreen.MENU))


func test_exit_with_unsaved_changes_asks_first() -> void:
	_screen.land_button("Forest").pressed.emit()

	_screen.exit_button().pressed.emit()

	assert_not_null(_screen.exit_prompt())
	assert_string_contains(_screen.exit_prompt().message(), "not been saved")
	assert_eq(_went_to, [] as Array[String])


func test_keep_building_closes_the_prompt_and_changes_nothing() -> void:
	_screen.land_button("Forest").pressed.emit()
	_screen.exit_button().pressed.emit()

	_screen.exit_prompt().button(DeckbuilderScreen.ExitAnswer.KEEP_BUILDING).pressed.emit()

	assert_null(_screen.exit_prompt())
	assert_eq(_went_to, [] as Array[String])
	assert_eq(_deck.basic_land_count("Forest"), 10)
	assert_eq(_saved().basic_lands["Forest"], 9)


func test_exit_without_saving_leaves_the_deckbox_as_it_was() -> void:
	_screen.land_button("Forest").pressed.emit()
	_type_name("Thrown Away")
	_screen.exit_button().pressed.emit()

	_screen.exit_prompt().button(DeckbuilderScreen.ExitAnswer.EXIT_WITHOUT_SAVING).pressed.emit()

	assert_eq(_went_to, [DeckbuilderScreen.MENU] as Array[String])
	assert_eq(_saved().name, "Red-Green Stompy")
	assert_eq(_saved().basic_lands["Forest"], 9)


func test_save_and_exit_saves_then_leaves() -> void:
	_screen.land_button("Forest").pressed.emit()
	_screen.exit_button().pressed.emit()

	_screen.exit_prompt().button(DeckbuilderScreen.ExitAnswer.SAVE_AND_EXIT).pressed.emit()

	assert_eq(_saved().basic_lands["Forest"], 10)
	assert_eq(_went_to, [DeckbuilderScreen.MENU] as Array[String])


func test_save_and_exit_stays_when_the_deck_cannot_be_saved() -> void:
	_type_name("")
	_screen.exit_button().pressed.emit()

	_screen.exit_prompt().button(DeckbuilderScreen.ExitAnswer.SAVE_AND_EXIT).pressed.emit()

	assert_eq(_went_to, [] as Array[String])
	assert_null(_screen.exit_prompt())
	assert_eq(_screen.notice(), "A Deck needs a name.")


func test_nothing_behind_the_prompt_takes_clicks_and_escape_keeps_building() -> void:
	_screen.land_button("Forest").pressed.emit()
	_screen.exit_button().pressed.emit()

	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = _strip_of(_deck.cards_in(1)[0])
	_screen._input(click)
	assert_null(_screen.selected())

	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	_screen._input(escape)
	assert_null(_screen.exit_prompt())
	assert_eq(_went_to, [] as Array[String])


func test_applying_a_mod_is_not_an_unsaved_change() -> void:
	var bears: DeckbuilderCard = _deck.cards_in(2)[2]
	_screen.right_click_at(_strip_of(bears))
	_screen.drag_to(OUTSIDE)
	_screen.apply_mod_button().pressed.emit()
	_screen.mod_popup().choose(_sample.held_mods.kinds()[0])
	_screen.mod_popup().button("apply").pressed.emit()
	_screen.mod_popup().button("yes").pressed.emit()

	_screen.exit_button().pressed.emit()

	assert_null(_screen.exit_prompt(), "The Mod is already on the card for good; there is nothing to ask about.")
	assert_eq(_went_to, [DeckbuilderScreen.MENU] as Array[String])


func _type_name(text: String) -> void:
	_screen.name_box().text = text
	_screen.name_box().text_changed.emit(text)


## The sample's Deck as the Deckbox holds it.
func _saved() -> Deck:
	return _sample.deckbox.decks()[0]


func _strip_of(card: DeckbuilderCard) -> Vector2:
	return _screen.column_face(card).global_position + Vector2(40, 8)


func _column_point(column: int) -> Vector2:
	var place: Rect2 = _screen.layout().column(column)
	return Vector2(place.get_center().x, place.end.y - 20.0)
