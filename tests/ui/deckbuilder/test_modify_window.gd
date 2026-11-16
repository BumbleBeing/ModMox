extends GutTest
## The Modify Window: every kind of held Mod with its count, the inapplicable ones gray, the
## card as it would become beside the card as it is, and Apply asking once more.

const Fixture: GDScript = preload("res://tests/ui/deckbuilder/support/deckbuilder_fixture.gd")

var _fixture: Fixture
var _ember: Mod
var _rename: Mod
var _modify_window: ModifyWindow


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

	assert_string_contains(_modify_window.tile_words(_ember).written(), "×2")
	assert_string_contains(_modify_window.tile_words(_ember).written(), _ember.name)
	assert_string_contains(_modify_window.tile_words(_rename).written(), "×1")
	assert_false(_modify_window.tile(_ember).disabled)
	assert_null(_modify_window.tile(Fixture.rename_mod("Not held")))


func test_a_mana_cost_in_a_mods_description_is_drawn_as_symbols() -> void:
	_ember.description = "This card costs {R} more to cast."
	var tap: Mod = Fixture.word_mod("Springs")
	tap.description = "This card has \"{2}{U}, {T}: Draw a card.\""
	_fixture.held_mods.add(tap)
	_open(_fixture.own("grizzly_bears"))

	assert_eq(_modify_window.tile_words(_ember).symbols(), ["r"] as Array[String])
	assert_eq(_modify_window.tile_words(tap).symbols(), ["2", "u", "t"] as Array[String])
	for mod: Mod in [_ember, tap, _rename]:
		assert_false(_modify_window.tile_words(mod).get_parsed_text().contains("{"), "No braces are shown as text.")
		assert_eq(_modify_window.tile(mod).text, "", "The tile's words are drawn by its Symbol Label alone.")
	assert_string_contains(_modify_window.tile_words(_ember).get_parsed_text(), "This card costs   more to cast.")


func test_a_tile_is_as_tall_as_its_words() -> void:
	_ember.description = "This card costs {R} more to cast, and this sentence runs on for long enough to take " \
			+ "several lines of the tile, so that the tile has to grow to hold all of them."
	_open(_fixture.own("grizzly_bears"))
	await wait_process_frames(3)

	var words: SymbolLabel = _modify_window.tile_words(_ember)
	assert_gt(words.get_line_count(), 2)
	assert_gte(_modify_window.tile(_ember).size.y, float(words.get_content_height()), "The tile holds every line.")
	assert_gt(_modify_window.tile(_ember).size.y, _modify_window.tile(_rename).size.y)


func test_the_card_with_a_mod_draws_the_costs_in_its_abilities_as_symbols() -> void:
	_open(_fixture.own("llanowar_elves"))

	_modify_window.hover(_rename)

	assert_eq(_modify_window.before_face().rules().symbols(), ["{T}", "{G}"] as Array[String])
	assert_eq(_modify_window.after_face().rules().symbols(), ["{T}", "{G}"] as Array[String])


func test_a_mod_that_is_not_applicable_is_gray_and_cannot_be_chosen() -> void:
	_open(_fixture.own("forest"))

	assert_true(_modify_window.tile(_ember).disabled, "A land has no mana cost.")
	assert_false(_modify_window.tile(_rename).disabled, "A basic land takes a Mod that fits it.")

	_modify_window.hover(_ember)
	_modify_window.choose(_ember)

	assert_null(_modify_window.previewed())
	assert_null(_modify_window.chosen())
	assert_eq(_modify_window.state(), ModifyWindow.State.CHOOSING)


func test_hovering_over_a_mod_shows_the_card_as_it_would_become_beside_the_card_as_it_is() -> void:
	_open(_fixture.own("grizzly_bears"))
	assert_null(_modify_window.after_face())
	assert_eq(_modify_window.before_face().title_text().shown_text(), "Grizzly Bears")

	_modify_window.hover(_rename)
	assert_eq(_modify_window.previewed(), _rename)
	assert_eq(_modify_window.after_face().title_text().shown_text(), "Mox-Touched")
	assert_null(DeckbuilderFace.mod_slots_on(_modify_window.after_face()), "The faces here show no Mod Slots.")
	assert_null(DeckbuilderFace.mod_slots_on(_modify_window.before_face()))
	assert_eq(_modify_window.before_face().title_text().shown_text(), "Grizzly Bears")

	_modify_window.hover(null)
	assert_null(_modify_window.previewed())
	assert_null(_modify_window.after_face())


func test_clicking_a_mod_offers_apply_and_cancel_and_holds_its_preview() -> void:
	_open(_fixture.own("grizzly_bears"))
	assert_not_null(_modify_window.button("close"))
	assert_true(_modify_window.button("apply").disabled, "Apply is there, gray, until a Mod is clicked.")
	_modify_window.button("apply").pressed.emit()
	assert_eq(_modify_window.state(), ModifyWindow.State.CHOOSING)

	_modify_window.choose(_ember)

	assert_eq(_modify_window.state(), ModifyWindow.State.CHOSEN)
	assert_eq(_modify_window.chosen(), _ember)
	assert_false(_modify_window.button("apply").disabled)
	assert_not_null(_modify_window.button("cancel"))
	_modify_window.hover(_rename)
	assert_eq(_modify_window.previewed(), _ember, "Hovering no longer changes the preview.")

	_modify_window.choose(_rename)
	assert_eq(_modify_window.chosen(), _rename, "Clicking another Mod chooses that one instead.")

	_modify_window.button("cancel").pressed.emit()
	assert_eq(_modify_window.state(), ModifyWindow.State.CHOOSING)
	assert_null(_modify_window.chosen())
	assert_null(_modify_window.previewed())


func test_apply_asks_are_you_sure_and_only_yes_applies() -> void:
	_open(_fixture.own("grizzly_bears"))
	watch_signals(_modify_window)
	_modify_window.choose(_ember)

	_modify_window.button("apply").pressed.emit()
	assert_eq(_modify_window.state(), ModifyWindow.State.CONFIRMING)
	assert_string_contains(_modify_window.question(), "Are you sure?")
	assert_string_contains(_modify_window.question(), "Grizzly Bears")
	assert_true(_modify_window.tile(_rename).disabled, "Nothing else can be chosen while it asks.")
	assert_signal_not_emitted(_modify_window, "applied")

	_modify_window.button("no").pressed.emit()
	assert_eq(_modify_window.state(), ModifyWindow.State.CHOSEN)
	assert_eq(_modify_window.chosen(), _ember)
	assert_signal_not_emitted(_modify_window, "applied")

	_modify_window.button("apply").pressed.emit()
	_modify_window.button("yes").pressed.emit()
	assert_signal_emitted_with_parameters(_modify_window, "applied", [_ember])


func test_the_pop_up_changes_nothing_itself() -> void:
	var bears: DeckbuilderCard = _fixture.own("grizzly_bears")
	_open(bears)

	_modify_window.choose(_ember)
	_modify_window.button("apply").pressed.emit()
	_modify_window.button("yes").pressed.emit()

	assert_eq(bears.mods.size(), 0)
	assert_eq(_fixture.held_mods.count_of(_ember), 2)


func test_close_reports_closed() -> void:
	_open(_fixture.own("grizzly_bears"))
	watch_signals(_modify_window)

	_modify_window.button("close").pressed.emit()

	assert_signal_emitted(_modify_window, "closed")


func test_with_no_mods_held_it_says_so() -> void:
	_fixture.held_mods = HeldMods.new()

	_open(_fixture.own("grizzly_bears"))

	assert_null(_modify_window.tile(_ember))
	assert_not_null(_modify_window.button("close"))


func test_three_bordered_panels_of_one_height_carry_their_titles_and_the_window_fits_them() -> void:
	_open(_fixture.own("grizzly_bears"))
	await wait_process_frames(2)
	var panels: Array[PanelContainer] = _modify_window.panels()

	assert_eq(_modify_window.panel_titles(), ["Valid Mods", "Current", "With selected Mod"] as Array[String])
	for panel: PanelContainer in panels + [_modify_window.window()]:
		var style: StyleBoxTexture = panel.get_theme_stylebox("panel") as StyleBoxTexture
		assert_not_null(style, "Dither Shaded.")
		assert_eq(style.texture.get_height(), int(panel.size.y), "Painted for its own height.")
		assert_eq(style.texture.get_image().get_pixel(int(style.texture_margin_left), 0), DeckbuilderLook.PANEL_EDGE,
				"Edged in the panels' gray.")
	for button: Button in [_modify_window.tile(_ember), _modify_window.button("apply"), _modify_window.button("close")]:
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			var face: StyleBoxTexture = button.get_theme_stylebox(state) as StyleBoxTexture
			assert_not_null(face, "A Mod's tile and a button are Dither Shaded too.")
			assert_eq(face.texture.get_height(), int(button.size.y), "Painted for its own height.")
	assert_true(_modify_window.after_place().get_theme_stylebox("panel") is StyleBoxFlat,
			"The place for the card as it would become is not.")
	for panel: PanelContainer in panels:
		assert_almost_eq(panel.size.y, panels[0].size.y, 0.5)
		var title: Label = panel.find_child("Title", true, false) as Label
		assert_eq(title.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	assert_gt(panels[1].size.y, ModifyWindow.FACE_HEIGHT)
	assert_lt(panels[1].size.y, ModifyWindow.FACE_HEIGHT + 80.0, "A card's height and a little more.")
	var apply: Button = _modify_window.button("apply")
	assert_almost_eq(_modify_window.window().get_global_rect().end.y, apply.get_global_rect().end.y + ModifyWindow.PAD, 6.0,
			"Nothing is left empty under the buttons.")
	assert_almost_eq(apply.global_position.y, panels[0].get_global_rect().end.y + 14.0, 8.0,
			"Nor between the panels and the buttons.")

	_ember.name = "Ember"
	_modify_window.hover(_ember)
	assert_eq(_modify_window.panel_titles()[2], "With Ember")
	_modify_window.hover(null)
	assert_eq(_modify_window.panel_titles()[2], "With selected Mod")


func _open(card: DeckbuilderCard) -> void:
	_modify_window = ModifyWindow.new()
	_modify_window.setup(card, _fixture.held_mods)
	add_child_autofree(_modify_window)
