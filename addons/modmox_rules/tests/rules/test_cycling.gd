extends GutTest
## Cycling (CR 702.29): "Cycling [cost]" means "[Cost], Discard this card: Draw a card", an
## activated ability that works only while its card is in its owner's hand (CR 702.29b,
## 113.6b), with no timing restriction. Discarding the card is a cost (ADR 0059), paid once
## the mana is (CR 601.2h). Cycler is an instant costing {0}, "You gain 1 life", with
## cycling {2}; two Elves, "{T}: Add {W}", pay for it. Typecycling (CR 702.29e) is cycling
## that searches instead of drawing: Landcycler is Cycler with basic landcycling, "Search
## your library for a basic land card, reveal it, put it into your hand, then shuffle."

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const Reason := ZoneChangeEvent.Reason

## The setup _hero_main() last started from, for a replay.
var _setup: MmEncounterSetup = null


func test_cycling_discards_the_card_and_draws_a_card() -> void:
	var engine: MmEngine = _hero_main([Scenario.elf(), Scenario.elf()], [Scenario.cycler()])
	var cycler: int = Scenario.card_in_hand(engine, engine.hero(), "Cycler")
	var hand: int = engine.hero().hand.size()
	var library: int = engine.hero().library.size()

	assert_eq(Scenario.activate(engine, cycler), "")

	assert_eq(_tapped_elves(engine), 2, "It cost {2}.")
	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Cycler"), -1, "Discarding it is part of the cost.")
	assert_eq(Scenario.last_reason_into(engine, MmZone.Kind.GRAVEYARD), Reason.DISCARD)
	assert_eq(Scenario.stack_ids(engine).size(), 1, "CR 602.2a: the ability uses the stack.")
	Scenario.resolve_stack(engine)
	assert_eq(engine.hero().hand.size(), hand, "One card out, one drawn.")
	assert_eq(engine.hero().library.size(), library - 1)
	assert_eq(engine.hero().life, 20, "The card's spell never happened.")


func test_it_is_not_offered_without_the_mana_for_its_cycling_cost() -> void:
	var engine: MmEngine = _hero_main([Scenario.elf()], [Scenario.cycler()])

	var cycler: int = Scenario.card_in_hand(engine, engine.hero(), "Cycler")

	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision, cycler), -1, "One Elf cannot pay {2}.")


func test_a_mana_ability_of_a_card_in_hand_pays_for_nothing() -> void:
	var engine: MmEngine = _hero_main([Scenario.elf()], [Scenario.cycler(), Scenario.elf("Pocket Elf")])
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision

	var pocket: int = Scenario.card_in_hand(engine, engine.hero(), "Pocket Elf")

	assert_eq(Scenario.activate_index(decision, pocket), -1, "CR 113.6: a creature's ability works on the battlefield only.")
	assert_eq(Scenario.activate_index(decision, Scenario.card_in_hand(engine, engine.hero(), "Cycler")), -1,
		"So it does not count toward paying {2}.")


func test_it_may_be_cycled_in_the_other_players_turn_whatever_its_card_type() -> void:
	var beast: MmCardDefinition = Scenario.creature("Beast", 3, 3, [Scenario.cycling(Scenario.mana_cost(2))])
	beast.mana_cost = Scenario.mana_cost(9)
	var engine: MmEngine = _hero_main([Scenario.elf(), Scenario.elf()], [beast])

	assert_eq(Scenario.play_until_step(engine, 4, Step.END), "")
	assert_eq(Scenario.pass_priority(engine), "", "The Villain has priority first in their own turn.")

	assert_eq(Scenario.activate(engine, Scenario.card_in_hand(engine, engine.hero(), "Beast")), "",
		"CR 702.29a: cycling has no timing restriction.")
	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Beast"), -1)


func test_it_may_be_cycled_with_a_spell_on_the_stack() -> void:
	var engine: MmEngine = _hero_main([], [Scenario.cycler("Free Cycler", Scenario.mana_cost(0)), Scenario.free_shock("Shock", 2)])
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Shock"), [MmReference.to_player(engine.villain().id)])

	assert_eq(Scenario.activate(engine, Scenario.card_in_hand(engine, engine.hero(), "Free Cycler")), "")

	assert_eq(Scenario.stack_ids(engine).size(), 2)


func test_a_permanent_with_cycling_cannot_cycle() -> void:
	var beast: MmCardDefinition = Scenario.creature("Beast", 3, 3, [Scenario.cycling(Scenario.mana_cost(0))])

	var engine: MmEngine = _hero_main([beast], [])

	var on_battlefield: int = Scenario.permanent_named(engine, engine.hero().id, "Beast")
	assert_ne(on_battlefield, -1)
	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision, on_battlefield), -1,
		"CR 702.29b: only while it is in its owner's hand.")


func test_a_card_with_cycling_in_a_graveyard_cannot_cycle() -> void:
	var engine: MmEngine = _hero_main([], [Scenario.cycler("Free Cycler", Scenario.mana_cost(0))])
	Scenario.activate(engine, Scenario.card_in_hand(engine, engine.hero(), "Free Cycler"))
	Scenario.resolve_stack(engine)

	var in_graveyard: int = Scenario.card_in_graveyard(engine, engine.hero(), "Free Cycler")

	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision, in_graveyard), -1)


func test_countered_it_still_discarded_the_card_and_draws_nothing() -> void:
	var engine: MmEngine = _hero_main([], [Scenario.cycler("Free Cycler", Scenario.mana_cost(0)), Scenario.free_stifle("Stifle")])
	Scenario.activate(engine, Scenario.card_in_hand(engine, engine.hero(), "Free Cycler"))
	var ability: int = Scenario.stack_ids(engine)[0]
	var library: int = engine.hero().library.size()

	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Stifle"), [MmReference.to_object(ability)])
	Scenario.resolve_stack(engine)

	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Free Cycler"), -1, "Costs are paid first.")
	assert_eq(engine.hero().library.size(), library, "Nothing drawn.")


func test_canceling_while_paying_leaves_it_in_the_hand() -> void:
	var engine: MmEngine = _hero_main([Scenario.elf(), Scenario.elf()], [Scenario.cycler()])
	var cycler: int = Scenario.card_in_hand(engine, engine.hero(), "Cycler")
	engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, cycler))
	assert_true(engine.is_casting())
	assert_eq(Scenario.card_in_hand(engine, engine.hero(), "Cycler"), cycler, "CR 601.2h: it is discarded once the mana is paid.")

	assert_eq(engine.cancel_cast(), "")

	assert_eq(Scenario.card_in_hand(engine, engine.hero(), "Cycler"), cycler, "CR 728: as it was.")
	assert_true(engine.game_state().stack.is_empty())
	assert_eq(_tapped_elves(engine), 0)


func test_abilities_of_cards_in_hand_come_after_every_other_action() -> void:
	var engine: MmEngine = _hero_main([Scenario.elf(), Scenario.elf()], [Scenario.cycler()])
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision

	var last: ActivateAbilityAction = decision.actions.back() as ActivateAbilityAction

	assert_not_null(last, "ADR 0012: an Elf's ability still comes before it, so no earlier index moves.")
	assert_eq(engine.game_state().object(last.object_id).zone(), engine.hero().hand)
	assert_true(decision.actions[decision.actions.size() - 2] is ActivateAbilityAction)


func test_copies_and_replays_cycle_the_same() -> void:
	var engine: MmEngine = _hero_main([Scenario.elf(), Scenario.elf()], [Scenario.cycler()])
	Scenario.activate(engine, Scenario.card_in_hand(engine, engine.hero(), "Cycler"))

	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))
	var replayed: MmEngine = MmEngine.replay(_setup, engine.decision_log())

	assert_eq(replayed.fingerprint(), engine.fingerprint())
	assert_ne(Scenario.card_in_graveyard(copy, copy.hero(), "Cycler"), -1)
	assert_eq(Scenario.stack_ids(copy).size(), 1)


# --- Basic landcycling ------------------------------------------------------------------


func test_basic_landcycling_puts_a_basic_land_card_into_the_hand_then_shuffles() -> void:
	var engine: MmEngine = _landcycling_main(true)
	var hand: int = engine.hero().hand.size()
	var library: int = engine.hero().library.size()
	var shuffles: int = _shuffles_of(engine)

	assert_eq(Scenario.activate(engine, Scenario.card_in_hand(engine, engine.hero(), "Landcycler")), "")
	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Landcycler"), -1, "Discarding it is part of the cost.")
	assert_eq(Scenario.pass_to_search(engine), "")
	var search: ChooseCardsInLibraryDecision = engine.pending_decision() as ChooseCardsInLibraryDecision
	assert_gt(search.candidate_ids.size(), 0)
	var found: int = engine.game_state().object(search.candidate_ids[0]).card_id
	assert_eq(engine.submit([search.candidate_ids[0]]), "")

	assert_true(_hand_card_ids(engine).has(found), "CR 702.29e: the Forest found is in the hand.")
	assert_eq(engine.hero().hand.size(), hand, "One card out, one found.")
	assert_eq(engine.hero().library.size(), library - 1, "Nothing drawn.")
	assert_eq(_shuffles_of(engine), shuffles + 1, "Then shuffle.")
	assert_eq(Scenario.last_reason_into(engine, MmZone.Kind.HAND), Reason.SEARCH)


func test_basic_landcycling_offers_every_basic_land_and_no_other_card() -> void:
	var engine: MmEngine = _landcycling_main(true)
	assert_eq(Scenario.activate(engine, Scenario.card_in_hand(engine, engine.hero(), "Landcycler")), "")

	assert_eq(Scenario.pass_to_search(engine), "")

	var search: ChooseCardsInLibraryDecision = engine.pending_decision() as ChooseCardsInLibraryDecision
	var forests: int = 0
	for card: MmGameObject in engine.hero().library.objects():
		if engine.game_state().characteristics_of(card).name == "Forest":
			forests += 1
	assert_gt(forests, 0)
	assert_eq(search.candidate_ids.size(), forests, "Grove, a nonbasic land, is not offered.")
	assert_eq(search.most, 1)
	for id: int in search.candidate_ids:
		assert_eq(engine.game_state().characteristics_of(engine.game_state().object(id)).name, "Forest")


func test_basic_landcycling_with_no_basic_land_finds_nothing_and_still_discarded_the_card() -> void:
	var engine: MmEngine = _landcycling_main(false)
	var hand: int = engine.hero().hand.size()
	var library: int = engine.hero().library.size()
	assert_eq(Scenario.activate(engine, Scenario.card_in_hand(engine, engine.hero(), "Landcycler")), "")
	assert_eq(Scenario.pass_to_search(engine), "")
	var search: ChooseCardsInLibraryDecision = engine.pending_decision() as ChooseCardsInLibraryDecision
	assert_eq(search.candidate_ids.size(), 0, "No basic land in this library.")

	assert_eq(engine.submit([]), "")

	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Landcycler"), -1)
	assert_eq(engine.hero().hand.size(), hand - 1)
	assert_eq(engine.hero().library.size(), library)


func test_a_permanent_with_basic_landcycling_cannot_cycle() -> void:
	var beast: MmCardDefinition = Scenario.creature("Beast", 3, 3, [Scenario.landcycling(Scenario.mana_cost(0))])

	var engine: MmEngine = _hero_main([beast], [])

	var on_battlefield: int = Scenario.permanent_named(engine, engine.hero().id, "Beast")
	assert_ne(on_battlefield, -1)
	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision, on_battlefield), -1,
		"CR 702.29b: only while it is in its owner's hand.")


func test_copies_and_replays_landcycle_the_same() -> void:
	var engine: MmEngine = _landcycling_main(true)
	assert_eq(Scenario.activate(engine, Scenario.card_in_hand(engine, engine.hero(), "Landcycler")), "")
	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))
	assert_eq(Scenario.pass_to_search(engine), "")
	var search: ChooseCardsInLibraryDecision = engine.pending_decision() as ChooseCardsInLibraryDecision
	assert_eq(engine.submit([search.candidate_ids[0]]), "")

	var replayed: MmEngine = MmEngine.replay(_setup, engine.decision_log())

	assert_eq(replayed.fingerprint(), engine.fingerprint())
	assert_eq(Scenario.pass_to_search(copy), "")
	var copied_search: ChooseCardsInLibraryDecision = copy.pending_decision() as ChooseCardsInLibraryDecision
	assert_not_null(copied_search, "The copy searches too.")
	if copied_search != null:
		assert_gt(copied_search.candidate_ids.size(), 0)


func test_basic_landcycling_survives_saving_loading_and_duplicating() -> void:
	var path: String = "user://test_landcycling_save.tres"
	var definition: MmCardDefinition = Scenario.landcycler("Landcycler", Scenario.mana_cost(1))
	assert_eq(ResourceSaver.save(definition, path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	var copies: Array[CyclingAbility] = [
		loaded.abilities[1] as CyclingAbility,
		(definition.abilities[1] as CyclingAbility).duplicate() as CyclingAbility,
		(definition.abilities[1] as CyclingAbility).duplicate_deep() as CyclingAbility,
	]
	for ability: CyclingAbility in copies:
		assert_not_null(ability.search)
		assert_eq(ability.effects.size(), 1)
		var searching: SearchLibraryEffect = ability.effects[0] as SearchLibraryEffect
		assert_not_null(searching, "Its search, not a draw.")
		if searching != null:
			assert_not_null(searching.filter)
			assert_eq(searching.destination, MmZone.Kind.HAND)
			assert_true(searching.reveal)
		assert_eq(ability.costs.size(), 1)
		assert_true(ability.costs[0] is DiscardThisCardCost)
		assert_true(ability.is_activated_from_hand)


func test_cycling_with_no_search_draws_and_clearing_the_search_draws_again() -> void:
	var ability: CyclingAbility = Scenario.cycling(Scenario.mana_cost(2))
	assert_true(ability.effects[0] is DrawCardsEffect)

	ability.search = Scenario.basic_land_card()
	assert_true(ability.effects[0] is SearchLibraryEffect)
	ability.search = null

	assert_eq(ability.effects.size(), 1)
	assert_true(ability.effects[0] is DrawCardsEffect)


func _hero_main(hero_permanents: Array[MmCardDefinition], hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, no_cards, hero_extras)
	_setup = setup
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, no_cards, hero_extras, no_cards,
		3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


func _tapped_elves(engine: MmEngine) -> int:
	var tapped: int = 0
	for id: int in Scenario.permanents_named(engine, engine.hero().id, "Elf"):
		if engine.game_state().object(id).is_tapped:
			tapped += 1
	return tapped


## The Hero in their first main phase holding Landcycler, with basic landcycling {0}, and a
## library holding Grove (a nonbasic land), Gift and, when [param with_forests], Forests.
func _landcycling_main(with_forests: bool) -> MmEngine:
	var gift: MmCardDefinition = Scenario.instant("Gift", Scenario.mana_cost(0), [], [Scenario.gain_life(1, Scenario.you())])
	var cards: Array[MmCardDefinition] = [Scenario.landcycler("Landcycler", Scenario.mana_cost(0)),
		Scenario.mana_land("Grove", MmMana.Type.GREEN, 1), gift]
	if with_forests:
		cards.append(Scenario.basic_land("Forest"))
	var setup: MmEncounterSetup = Scenario.setup_with(Scenario.cycled(cards), Scenario.cycled([]))
	_setup = setup
	var engine: MmEngine = Scenario.find_engine(setup, func(running: MmEngine) -> bool:
		return Scenario.ready_in_main(running, 1, 0, "Landcycler"))
	assert_not_null(engine, "No seed gave the needed hand.")
	return engine


func _shuffles_of(engine: MmEngine) -> int:
	var shuffles: int = 0
	for event: MmEvent in engine.game_state().event_log:
		var shuffle: ShuffleEvent = event as ShuffleEvent
		if shuffle != null and shuffle.zone_kind == MmZone.Kind.LIBRARY and shuffle.owner_id == engine.hero().id:
			shuffles += 1
	return shuffles


func _hand_card_ids(engine: MmEngine) -> Array[int]:
	var ids: Array[int] = []
	for card: MmGameObject in engine.hero().hand.objects():
		ids.append(card.card_id)
	return ids
