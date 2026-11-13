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
	_ember.name = "Ember"
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

	assert_true(_popup.tile(_ember).disabled, "A land has no mana cost.")
	assert_false(_popup.tile(_rename).disabled, "A basic land takes a Mod that fits it.")

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
	assert_null(DeckbuilderFace.mod_slots_on(_popup.after_face()), "The faces here show no Mod Slots.")
	assert_null(DeckbuilderFace.mod_slots_on(_popup.before_face()))
	assert_eq(_popup.before_face().title_text().shown_text(), "Grizzly Bears")

	_popup.hover(null)
	assert_null(_popup.previewed())
	assert_null(_popup.after_face())


func test_clicking_a_mod_offers_apply_and_cancel_and_holds_its_preview() -> void:
	_open(_fixture.own("grizzly_bears"))
	assert_not_null(_popup.button("close"))
	assert_true(_popup.button("apply").disabled, "Apply is there, gray, until a Mod is clicked.")
	_popup.button("apply").pressed.emit()
	assert_eq(_popup.state(), ModPopup.State.CHOOSING)

	_popup.choose(_ember)

	assert_eq(_popup.state(), ModPopup.State.CHOSEN)
	assert_eq(_popup.chosen(), _ember)
	assert_false(_popup.button("apply").disabled)
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


func test_three_bordered_panels_of_one_height_carry_their_titles_and_the_window_fits_them() -> void:
	_open(_fixture.own("grizzly_bears"))
	await wait_process_frames(2)
	var panels: Array[PanelContainer] = _popup.panels()

	assert_eq(_popup.panel_titles(), ["Valid Mods", "Current", "With selected Mod"] as Array[String])
	for panel: PanelContainer in panels:
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		assert_eq(style.border_color, DeckbuilderLook.PANEL_EDGE)
		assert_almost_eq(panel.size.y, panels[0].size.y, 0.5)
		var title: Label = panel.find_child("Title", true, false) as Label
		assert_eq(title.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	assert_gt(panels[1].size.y, ModPopup.FACE_HEIGHT)
	assert_lt(panels[1].size.y, ModPopup.FACE_HEIGHT + 80.0, "A card's height and a little more.")
	var apply: Button = _popup.button("apply")
	assert_almost_eq(_popup.window().get_global_rect().end.y, apply.get_global_rect().end.y + ModPopup.PAD, 6.0,
			"Nothing is left empty under the buttons.")
	assert_almost_eq(apply.global_position.y, panels[0].get_global_rect().end.y + 14.0, 8.0,
			"Nor between the panels and the buttons.")

	_ember.name = "Ember"
	_popup.hover(_ember)
	assert_eq(_popup.panel_titles()[2], "With Ember")
	_popup.hover(null)
	assert_eq(_popup.panel_titles()[2], "With selected Mod")


func _open(card: DeckbuilderCard) -> void:
	_popup = ModPopup.new()
	_popup.setup(card, _fixture.held_mods)
	add_child_autofree(_popup)
