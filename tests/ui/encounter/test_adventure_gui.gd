extends GutTest
## An Adventurer card on screen (game ADR 0079, engine ADR 0078), as the prototype was signed
## off: drawn in CardConjurer's Adventure frame, its book open on the Adventure's page and the
## creature's; let go from the hand, the Option Menu offers each half; on the stack the whole
## card is drawn with the creature's page dimmed; on an adventure it is cast from the Exile
## window, as a card with flashback is from the Graveyard window.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const WHITE: MmMana.Type = MmMana.Type.WHITE


func after_each() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func test_an_adventurer_card_gets_the_adventure_frame_of_its_color() -> void:
	var spec: FrameSpec = FrameSpec.of(CardLook.of_definition(_white_guide()))

	assert_true(spec.is_adventure)
	assert_eq(_layers(spec), ["adventure/w", "pt/w"])
	assert_eq(spec.key(), "card1:w:adventure:pt")
	assert_false(FrameSpec.of(CardLook.of_definition(Scenario.creature("Bear", 2, 2))).is_adventure)


func test_its_face_writes_the_adventure_on_the_left_page_and_its_own_rules_on_the_right() -> void:
	var face: CardFace = CardFace.new()
	add_child_autofree(face)

	face.setup(CardLook.of_definition(_white_guide()), 700.0)

	assert_eq(face.adventure_title_text().shown_text(), "Gift")
	assert_eq(face.adventure_type_line_text().shown_text(), "Sorcery — Adventure")
	assert_eq(face.adventure_type_line_text().run_colors(), [Color.WHITE] as Array[Color])
	assert_not_null(face.adventure_rules())
	assert_eq(face.rules().position, CardGeometry.on_card(CardGeometry.CREATURE_PAGE_RULES, face.size).position,
		"Flying is on the right page.")
	assert_eq(face.title_text().shown_text(), "Guide")


func test_a_card_without_an_adventure_has_no_left_page() -> void:
	var face: CardFace = CardFace.new()
	add_child_autofree(face)

	face.setup(CardLook.of_definition(Scenario.creature("Bear", 2, 2, [FlyingAbility.new()])), 700.0)

	assert_null(face.adventure_title_text())
	assert_eq(face.rules().position, CardGeometry.on_card(CardGeometry.RULES, face.size).position)


func test_its_card_text_has_the_adventure_under_the_creatures_text() -> void:
	var look: CardLook = CardLook.of_definition(_white_guide())

	assert_eq(look.adventure_text_lines(), ["Gift {1}{W}", "Sorcery — Adventure", "Target creature gets +2/+1 until end of turn."])


func test_let_go_from_the_hand_it_offers_casting_each_half() -> void:
	var engine: MmEngine = _hero_main()
	var guide: int = Scenario.card_in_hand(engine, engine.hero(), "Guide")

	var clicks: DecisionClicks = DecisionClicks.of(engine.pending_decision(), engine.view_for(engine.hero()))

	assert_eq(_texts(clicks.hand_options_of(guide)), ["Cast Guide", "Cast Gift"])


func test_on_the_stack_it_reads_as_an_adventure_and_is_drawn_whole_with_its_creature_page_dimmed() -> void:
	var engine: MmEngine = _hero_main()
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.cast_adventure(engine, Scenario.card_in_hand(engine, engine.hero(), "Guide"), MmReference.to_object(bear))
	var view: MmPlayerView = engine.view_for(engine.villain())
	var spell: MmObjectView = view.stack[0]

	var item: StackItem = StackItem.of(spell, view)
	var look: CardLook = CardLook.of_view(spell)

	assert_eq(item.first_line, "Gift (Adventure)")
	assert_eq(item.full_text,
		"Gift — Target creature gets +2/+1 until end of turn. · Cast as an Adventure: exiled as it resolves, and Guide may then be cast from exile.")
	assert_eq([look.name, look.is_adventure_cast, look.adventure.name], ["Guide", true, "Gift"], "The whole card.")


func test_on_an_adventure_it_is_cast_from_the_exile_window_and_says_so() -> void:
	var engine: MmEngine = _hero_main()
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.cast_adventure(engine, Scenario.card_in_hand(engine, engine.hero(), "Guide"), MmReference.to_object(bear))
	Scenario.resolve_stack(engine)
	var view: MmPlayerView = engine.view_for(engine.hero())
	var exiled: MmObjectView = view.exiles[engine.hero().id][0] as MmObjectView

	var clicks: DecisionClicks = DecisionClicks.of(engine.pending_decision(), view)
	var states: Array[StateEntry] = StateInformation.of(exiled, view)

	assert_eq(_texts(clicks.options_of(exiled.id)), ["Cast Guide from exile"])
	assert_true(clicks.piles().has(EncounterLayout.pile_key(MmZone.Kind.EXILE, true)), "Game ADR 0049: its pile glows green.")
	assert_eq(_titles_and_texts(states), [["On an Adventure", "May be cast as Guide."]])


## Guide costing {W}, its Adventure Gift costing {1}{W}.
func _white_guide() -> MmCardDefinition:
	return Scenario.adventurer(Scenario.mana_cost(0, [WHITE]), Scenario.mana_cost(1, [WHITE]))


## The Hero in their main phase on Game Turn 3 with Bear, a 2/2, on the battlefield, holding
## Guide (Scenario.adventurer()).
func _hero_main() -> MmEngine:
	var bear: Array[MmCardDefinition] = [Scenario.creature("Bear", 2, 2)]
	var extras: Array[MmCardDefinition] = [Scenario.adventurer()]
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(bear, no_cards, extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, bear, no_cards, extras, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


func _layers(spec: FrameSpec) -> Array:
	var names: Array = []
	for layer: FrameLayer in spec.layers():
		names.append(layer.describe())
	return names


func _texts(options: Array[ClickOption]) -> Array[String]:
	var texts: Array[String] = []
	for option: ClickOption in options:
		texts.append(option.text)
	return texts


func _titles_and_texts(states: Array[StateEntry]) -> Array:
	var pairs: Array = []
	for entry: StateEntry in states:
		pairs.append([entry.title, entry.text])
	return pairs
