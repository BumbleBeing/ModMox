extends GutTest
## The Mod pop-up: every kind of held Mod with its count, the inapplicable ones gray, the
## card as it would become beside the card as it is, and Apply asking once more.

const Fixture: GDScript = preload("res://tests/prototypes/deckbuilder/deckbuilder_fixture.gd")

var _fixture: Fixture
var _ember: Mod
var _rename: Mod
var _popup: ModPopup


func before_each() -> void:
	_fixture = Fixture.new()
	_ember = Fixture.add_symbol_mod(MmMana.Type.RED)
	_rename = Fixture.rename_mod("Mox-Touched")
	_fixture.held_mods.add(_ember)
	_fixture.held_mods.add(_ember)
	_fixture.held_mods.add(_rename)


func after_each() -> void:
	await wait_process_frames(2)


func test_a_card_with_a_mod_is_a_copy_and_the_card_is_not_changed() -> void:
	var bears: DeckbuilderCard = _fixture.own("grizzly_bears")

	var copy: DeckbuilderCard = bears.with_mod(_ember)

	assert_eq(copy.mana_value(), 3)
	assert_eq(copy.mods, [_ember] as Array[Mod])
	assert_eq(bears.mana_value(), 2)
	assert_eq(bears.mods, [] as Array[Mod])
	assert_eq(bears.run_card.modifications.size(), 0)


func test_there_is_a_tile_for_each_kind_of_held_mod_with_its_count() -> void:
	_open(_fixture.own("grizzly_bears"))

	assert_string_contains(_popup.tile(_ember).text, "×2")
	assert_string_contains(_popup.tile(_ember).text, _ember.name)
	assert_string_contains(_popup.tile(_rename).text, "×1")
	assert_false(_popup.tile(_ember).disabled)
	assert_null(_popup.tile(Fixture.rename_mod("Not held")))


func test_a_mod_that_is_not_applicable_is_gray_and_cannot_be_chosen() -> void:
	_open(_fixture.own("forest"))

	assert_true(_popup.tile(_ember).disabled, "A basic land has no Mod Slots.")
	assert_true(_popup.tile(_rename).disabled)

	_popup.hover(_ember)
	_popup.choose(_ember)

	assert_null(_popup.previewed())
	assert_null(_popup.chosen())
	assert_eq(_popup.state(), ModPopup.State.CHOOSING)


func test_hovering_over_a_mod_shows_the_card_as_it_would_become_beside_the_card_as_it_is() -> void:
	_open(_fixture.own("grizzly_bears"))
	assert_null(_popup.after_face())
	assert_eq(_popup.before_face().title_text().shown_text(), "Grizzly Bears")

	_popup.hover(_rename)
	assert_eq(_popup.previewed(), _rename)
	assert_eq(_popup.after_face().title_text().shown_text(), "Mox-Touched")
	assert_eq(DeckbuilderFace.mod_slots_on(_popup.after_face()).slots()[0], ModSlotRow.Slot.MOD,
			"The Mod Slot it would fill shows filled.")
	assert_eq(_popup.before_face().title_text().shown_text(), "Grizzly Bears")

	_popup.hover(null)
	assert_null(_popup.previewed())
	assert_null(_popup.after_face())


func test_clicking_a_mod_offers_apply_and_cancel_and_holds_its_preview() -> void:
	_open(_fixture.own("grizzly_bears"))
	assert_not_null(_popup.button("close"))
	assert_null(_popup.button("apply"))

	_popup.choose(_ember)

	assert_eq(_popup.state(), ModPopup.State.CHOSEN)
	assert_eq(_popup.chosen(), _ember)
	assert_not_null(_popup.button("apply"))
	assert_not_null(_popup.button("cancel"))
	_popup.hover(_rename)
	assert_eq(_popup.previewed(), _ember, "Hovering no longer changes the preview.")

	_popup.choose(_rename)
	assert_eq(_popup.chosen(), _rename, "Clicking another Mod chooses that one instead.")

	_popup.button("cancel").pressed.emit()
	assert_eq(_popup.state(), ModPopup.State.CHOOSING)
	assert_null(_popup.chosen())
	assert_null(_popup.previewed())


func test_apply_asks_are_you_sure_and_only_yes_applies() -> void:
	_open(_fixture.own("grizzly_bears"))
	watch_signals(_popup)
	_popup.choose(_ember)

	_popup.button("apply").pressed.emit()
	assert_eq(_popup.state(), ModPopup.State.CONFIRMING)
	assert_string_contains(_popup.question(), "Are you sure?")
	assert_string_contains(_popup.question(), "Grizzly Bears")
	assert_true(_popup.tile(_rename).disabled, "Nothing else can be chosen while it asks.")
	assert_signal_not_emitted(_popup, "applied")

	_popup.button("no").pressed.emit()
	assert_eq(_popup.state(), ModPopup.State.CHOSEN)
	assert_eq(_popup.chosen(), _ember)
	assert_signal_not_emitted(_popup, "applied")

	_popup.button("apply").pressed.emit()
	_popup.button("yes").pressed.emit()
	assert_signal_emitted_with_parameters(_popup, "applied", [_ember])


func test_the_pop_up_changes_nothing_itself() -> void:
	var bears: DeckbuilderCard = _fixture.own("grizzly_bears")
	_open(bears)

	_popup.choose(_ember)
	_popup.button("apply").pressed.emit()
	_popup.button("yes").pressed.emit()

	assert_eq(bears.mods.size(), 0)
	assert_eq(_fixture.held_mods.count_of(_ember), 2)


func test_close_reports_closed() -> void:
	_open(_fixture.own("grizzly_bears"))
	watch_signals(_popup)

	_popup.button("close").pressed.emit()

	assert_signal_emitted(_popup, "closed")


func test_with_no_mods_held_it_says_so() -> void:
	_fixture.held_mods = HeldMods.new()

	_open(_fixture.own("grizzly_bears"))

	assert_null(_popup.tile(_ember))
	assert_not_null(_popup.button("close"))


func _open(card: DeckbuilderCard) -> void:
	_popup = ModPopup.new()
	_popup.setup(card, _fixture.held_mods)
	add_child_autofree(_popup)
