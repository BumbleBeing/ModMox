extends GutTest
## Mill (CR 701.17a): the top cards of a library go to its owner's graveyard, all at once.
## "Put [a card] from among them into your hand" then chooses among the cards just milled,
## and only those, as the spell resolves; it is not a target (CR 608.2d, engine ADR 0080).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const CardType := MmCardTypes.CardType


func test_milling_four_puts_the_top_four_cards_of_the_library_into_the_graveyard() -> void:
	var engine: MmEngine = _hero_main([Scenario.free_mill("Mill Four", 4)])
	var top_four: Array[int] = engine.hero().library.object_ids().slice(0, 4)
	var library_size: int = engine.hero().library.size()
	var names: Array[String] = []
	for id: int in top_four:
		names.append(engine.game_state().characteristics_of(engine.game_state().object(id)).name)

	assert_eq(Scenario.cast_and_resolve(engine, "Mill Four"), "")

	assert_eq(engine.hero().library.size(), library_size - 4)
	var graveyard: Array[String] = Scenario.names(engine, engine.hero().graveyard)
	assert_eq(graveyard.slice(0, 4), names, "In the order they were on top.")
	assert_eq(graveyard[4], "Mill Four", "Then the spell, as it left the stack.")
	for event: MmEvent in Scenario.events_of(engine, ZoneChangeEvent):
		var move: ZoneChangeEvent = event as ZoneChangeEvent
		if move.from_zone_kind == MmZone.Kind.LIBRARY and move.to_zone_kind == MmZone.Kind.GRAVEYARD:
			assert_eq(move.reason, ZoneChangeEvent.Reason.MILL)


func test_milling_more_than_the_library_holds_mills_it_all_and_loses_nothing() -> void:
	var engine: MmEngine = _hero_main([Scenario.free_mill("Mill Lots", 100)])

	assert_eq(Scenario.cast_and_resolve(engine, "Mill Lots"), "")

	assert_eq(engine.hero().library.size(), 0)
	assert_false(engine.is_over(), "CR 701.17b: milling is not drawing.")


func test_each_opponent_mills_from_their_own_library() -> void:
	var engine: MmEngine = _hero_main([Scenario.free_mill("Opponent Mill", 3, true)])
	var villain_library: int = engine.villain().library.size()
	var villain_graveyard: int = engine.villain().graveyard.size()

	assert_eq(Scenario.cast_and_resolve(engine, "Opponent Mill"), "")

	assert_eq(engine.villain().library.size(), villain_library - 3)
	assert_eq(engine.villain().graveyard.size(), villain_graveyard + 3, "The Villain may have discarded at cleanup.")


func test_an_instant_or_sorcery_card_from_among_the_milled_cards_is_chosen_into_the_hand() -> void:
	var engine: MmEngine = _hero_main([Scenario.free_secrets(), _ping(), _ping(), Scenario.creature("Bear", 2, 2)])
	var milled: Array[int] = engine.hero().library.object_ids().slice(0, 4)
	assert_true(_has_instant(engine, milled), "The deck puts a Ping among the top four.")

	_cast(engine, "Secrets")
	assert_eq(Scenario.pass_priority(engine), "")
	assert_eq(Scenario.pass_priority(engine), "")

	var choice: ChooseObjectDecision = engine.pending_decision() as ChooseObjectDecision
	assert_not_null(choice, "CR 608.2d: chosen as it resolves.")
	if choice == null:
		return
	for candidate: MmReference in choice.candidates:
		var card: MmGameObject = engine.game_state().object(candidate.id)
		assert_eq(card.zone(), engine.hero().graveyard, "A milled card, now in the graveyard.")
		var seen: MmCharacteristics = engine.game_state().characteristics_of(card)
		assert_true(seen.has_card_type(CardType.INSTANT) or seen.has_card_type(CardType.SORCERY), "Only instants and sorceries.")
	var chosen: int = choice.candidates[0].id
	var hand_before: int = engine.hero().hand.size()
	assert_eq(engine.submit(0), "")
	Scenario.resolve_stack(engine)
	assert_eq(engine.hero().hand.size(), hand_before + 1)
	assert_null(engine.game_state().object(chosen), "It moved, so it is a new object (ADR 0008).")


func test_a_card_already_in_the_graveyard_is_not_among_them() -> void:
	var engine: MmEngine = _hero_main([Scenario.free_secrets(), Scenario.creature("Bear", 2, 2), _ping()])
	assert_eq(Scenario.cast_and_resolve(engine, "Ping"), "")
	var earlier_ping: int = engine.hero().graveyard.objects()[-1].id

	_cast(engine, "Secrets")
	Scenario.pass_priority(engine)
	Scenario.pass_priority(engine)

	var choice: ChooseObjectDecision = engine.pending_decision() as ChooseObjectDecision
	if choice != null:
		for candidate: MmReference in choice.candidates:
			assert_ne(candidate.id, earlier_ping, "Only the cards this spell milled.")
	assert_ne(engine.game_state().object(earlier_ping), null, "The earlier Ping stays where it was.")


func test_with_no_instant_or_sorcery_among_them_nothing_is_asked_or_put_into_the_hand() -> void:
	var engine: MmEngine = _hero_main([Scenario.free_secrets(), Scenario.creature("Bear", 2, 2)], true)
	var hand_before: int = engine.hero().hand.size()

	_cast(engine, "Secrets")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_false(engine.pending_decision() is ChooseObjectDecision)
	assert_eq(engine.hero().hand.size(), hand_before - 1, "Only Secrets left the hand.")
	assert_eq(engine.hero().graveyard.size(), 5, "Four milled, then Secrets.")


## An instant costing {0}: "You gain 1 life."
func _ping() -> MmCardDefinition:
	return Scenario.instant("Ping", Scenario.mana_cost(0), [], [Scenario.gain_life(1, Scenario.you())])


## The Hero in their main phase on Game Turn 3, their deck cycling through [param cards] and
## Plains, holding the first of them. With [param is_first_alone] the deck has one of the
## first and cycles through the rest.
func _hero_main(cards: Array[MmCardDefinition], is_first_alone: bool = false) -> MmEngine:
	var deck: Array[MmCardDefinition] = cards.duplicate()
	deck.append(Scenario.basic_land("Plains"))
	var no_cards: Array[MmCardDefinition] = []
	var held: Array[MmCardDefinition] = [cards[0]]
	var setup: MmEncounterSetup = Scenario.combat_setup(no_cards, no_cards, deck)
	if is_first_alone:
		var rest: Array[MmCardDefinition] = Scenario.cycled(deck.slice(1)).slice(0, 39)
		rest.append(cards[0])
		setup = Scenario.setup_with(rest, Scenario.cycled(no_cards))
	var engine: MmEngine = Scenario.permanents_ready_with(setup, no_cards, no_cards, held, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


func _cast(engine: MmEngine, card_name: String) -> void:
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), card_name)), "")


func _has_instant(engine: MmEngine, ids: Array[int]) -> bool:
	for id: int in ids:
		if engine.game_state().characteristics_of(engine.game_state().object(id)).has_card_type(CardType.INSTANT):
			return true
	return false
