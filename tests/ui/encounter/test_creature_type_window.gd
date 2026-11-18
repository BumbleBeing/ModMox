extends GutTest
## The Creature Type Window on its own (game ADR 0053): its rows are built once for a
## decision, the search shows and orders them, the top match is lit, Up and Down move the
## light, Enter and a click choose, and nothing glows green.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const RALLY: int = 90

var _window: CreatureTypeWindow
var _chosen: Array[int] = []
var _pointed: Array[String] = []


func before_each() -> void:
	_chosen.clear()
	_pointed.clear()
	_window = CreatureTypeWindow.new()
	_window.size = Vector2(CreatureTypeWindow.WIDTH, 700)
	add_child_autofree(_window)
	_window.chosen.connect(func(answer: int) -> void: _chosen.append(answer))
	_window.pointed.connect(func(creature_type: String) -> void: _pointed.append(creature_type))
	_window.show_choice(CreatureTypeChoice.new(ChooseCreatureTypeDecision.new(HERO, RALLY), _view()))


func after_each() -> void:
	await wait_process_frames(2)


func test_it_is_titled_for_the_spell_with_a_search_box_and_every_type() -> void:
	assert_eq(_window.title_text(), "Rally the Ranks: choose a creature type")
	assert_eq(_window.query(), "")
	assert_eq(_window.shown_types().size(), 377)
	assert_eq(_window.shown_types().slice(0, 2), ["Cat", "Elf"], "The Hero's own types first.")
	assert_null(_window.close_button(), "It is answered, not closed.")


func test_a_pinned_entry_and_a_row_show_only_the_type_and_nothing_glows() -> void:
	assert_eq(_window.words_of("Cat"), "Cat")
	assert_eq(_window.row_of("Cat").get_child_count(), 2, "Its words and its ClickCatcher: no art, no count.")
	assert_null(_window.row_of("Cat").get_node_or_null(BorderEffects.GLOW), "Every type can be chosen, so none glows.")
	assert_null(_window.row_of("Advisor").get_node_or_null(BorderEffects.GLOW))
	assert_not_null(_window.catcher_of("Advisor"))


func test_typing_narrows_the_types_and_picks_out_the_typed_letters() -> void:
	_window.type_text("ca")

	var shown: Array[String] = _window.shown_types()
	assert_eq(shown[0], "Cat")
	assert_eq(shown[1], "Caitian", "Names starting with it first.")
	assert_false(shown.has("Elf"))
	assert_false(_window.row_of("Elf").visible)
	assert_true(_window.words_of("Scarecrow").contains("[color="), "The typed letters are picked out.")
	assert_eq(_window.lit(), "Cat", "The top match is lit.")


func test_enter_chooses_the_top_match_and_nothing_with_nothing_typed() -> void:
	_window.choose_lit()
	assert_eq(_chosen, [], "Nothing is typed, so nothing is lit.")

	_window.type_text("wiz")
	_window.filter_box().text_submitted.emit(_window.query())

	assert_eq(_chosen, [CreatureTypes.ALL.find("Wizard")])


func test_up_and_down_move_the_light_and_enter_chooses_the_lit_type() -> void:
	_window.type_text("ca")

	_window.step_light(1)
	_window.step_light(1)
	_window.step_light(-1)

	assert_eq(_window.lit(), "Caitian")
	_window.choose_lit()
	assert_eq(_chosen, [CreatureTypes.ALL.find("Caitian")])


func test_up_and_down_are_taken_as_keys() -> void:
	_window.type_text("ca")
	var down: InputEventKey = InputEventKey.new()
	down.keycode = KEY_DOWN
	down.pressed = true

	assert_true(_window.take_key(down))

	assert_eq(_window.lit(), "Caitian")


func test_a_click_on_a_row_chooses_its_type() -> void:
	_window.catcher_of("Goblin").clicked.emit()

	assert_eq(_chosen, [CreatureTypes.ALL.find("Goblin")])


func test_pointing_at_a_type_says_so_and_leaving_it_points_at_the_lit_one() -> void:
	_window.type_text("ca")
	_pointed.clear()

	_window.catcher_of("Camel").mouse_entered.emit()
	_window.catcher_of("Camel").mouse_exited.emit()

	assert_eq(_pointed, ["Camel", "Cat"])


func test_escape_in_the_search_box_is_the_screens() -> void:
	var escaped: Array[bool] = []
	_window.escaped.connect(func() -> void: escaped.append(true))
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true

	assert_true(_window.take_key(escape))

	assert_eq(escaped, [true])


func test_showing_the_same_decision_again_keeps_the_rows_and_what_is_typed() -> void:
	var decision: ChooseCreatureTypeDecision = _window.choice().decision
	_window.type_text("ca")
	var row: PanelContainer = _window.row_of("Cat")

	_window.show_choice(CreatureTypeChoice.new(decision, _view()))

	assert_eq(_window.query(), "ca")
	assert_same(_window.row_of("Cat"), row, "Nothing was rebuilt.")


func test_a_new_decision_builds_it_again_with_an_empty_search() -> void:
	_window.type_text("ca")

	_window.show_choice(CreatureTypeChoice.new(ChooseCreatureTypeDecision.new(HERO, RALLY), _view()))

	assert_eq(_window.query(), "")
	assert_eq(_window.shown_types().size(), 377)


## The Hero controls a Cat and an Elf, with Rally the Ranks resolving.
func _view() -> MmPlayerView:
	var view: MmPlayerView = MmPlayerView.new()
	view.viewer_id = HERO
	var rally: MmCardDefinition = Scenario.rally("Rally the Ranks")
	var spell: MmObjectView = MmObjectView.new()
	spell.id = RALLY
	spell.name = rally.name
	spell.abilities = rally.abilities
	view.stack = [spell]
	view.battlefield = [_creature(1, "Lion", "Cat"), _creature(2, "Lion", "Cat"), _creature(3, "Elf", "Elf")]
	return view


func _creature(id: int, card_name: String, subtype: String) -> MmObjectView:
	var seen: MmObjectView = MmObjectView.new()
	seen.id = id
	seen.name = card_name
	seen.is_creature = true
	seen.subtypes = [subtype]
	seen.controller_id = HERO
	return seen
