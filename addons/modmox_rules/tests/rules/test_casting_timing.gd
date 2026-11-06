extends GutTest
## When a spell may be cast (CR 117.1a, 307.1, 601.2c): a spell is offered only when its
## timing allows it, it has a legal target for every requirement, and it can be paid for.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const Type := MmMana.Type


func test_a_sorcery_is_offered_in_your_main_phase_with_an_empty_stack() -> void:
	var engine: MmEngine = _bolts_and_spikes(1)
	var spike: int = Scenario.card_in_hand(engine, engine.hero(), "Spike")

	assert_true(Scenario.offers_cast(engine, spike))


func test_a_sorcery_is_not_offered_outside_your_main_phase() -> void:
	var engine: MmEngine = _bolts_and_spikes(1)
	var spike: int = Scenario.card_in_hand(engine, engine.hero(), "Spike")

	Scenario.play_until_step(engine, 1, Step.BEGINNING_OF_COMBAT)

	assert_false(Scenario.offers_cast(engine, spike))


func test_a_sorcery_is_not_offered_while_something_is_on_the_stack() -> void:
	var engine: MmEngine = _bolts_and_spikes(3)
	var bolt: int = Scenario.card_in_hand(engine, engine.hero(), "Bolt")
	var spike: int = Scenario.card_in_hand(engine, engine.hero(), "Spike")

	assert_eq(Scenario.cast(engine, bolt, [MmReference.to_player(engine.villain().id)]), "")

	assert_eq(engine.pending_decision().player_id, engine.hero().id, "The caster keeps priority.")
	assert_false(Scenario.offers_cast(engine, spike))


func test_a_sorcery_is_not_offered_on_your_opponents_turn() -> void:
	var engine: MmEngine = _bolts_and_spikes(1)

	Scenario.pass_priority(engine)

	var villain_spike: int = Scenario.card_in_hand(engine, engine.villain(), "Spike")
	assert_true(villain_spike == -1 or not Scenario.offers_cast(engine, villain_spike))


func test_an_instant_is_offered_whenever_you_hold_priority_and_can_pay() -> void:
	var engine: MmEngine = _bolts_and_spikes(3)
	var bolt: int = Scenario.card_in_hand(engine, engine.hero(), "Bolt")

	Scenario.play_until_step(engine, 3, Step.END)

	assert_true(Scenario.offers_cast(engine, bolt), "An instant in the end step.")


func test_nothing_is_offered_without_the_mana_to_pay() -> void:
	var setup: MmEncounterSetup = Scenario.setup_with(Scenario.copies(Scenario.bolt(), 40), Scenario.copies(Scenario.vanilla("Card"), 40))
	var engine: MmEngine = MmEngine.start(setup)
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)

	var bolt: int = Scenario.card_in_hand(engine, engine.hero(), "Bolt")

	assert_false(Scenario.offers_cast(engine, bolt), "No lands, no mana.")


func test_affordability_matches_colors_exactly() -> void:
	var gruul: MmCardDefinition = Scenario.instant("Gruul Charm", Scenario.mana_cost(0, [Type.RED, Type.GREEN]), [], [])
	var two_forests: MmEngine = Scenario.find_engine(
		Scenario.setup_with(Scenario.deck_of(Scenario.basic_land("Forest"), 20, gruul, 20), Scenario.copies(Scenario.vanilla("Card"), 40)),
		func(running: MmEngine) -> bool: return Scenario.ready_in_main(running, 3, 2, "Gruul Charm"))
	var charm: int = Scenario.card_in_hand(two_forests, two_forests.hero(), "Gruul Charm")
	assert_false(Scenario.offers_cast(two_forests, charm), "Two Forests cannot make {R}{G}.")

	var dual: MmCardDefinition = Scenario.basic_land("Forest")
	dual.name = "Wild Dual"
	dual.subtypes = ["Forest", "Mountain"]
	var forest_and_dual: Array[MmCardDefinition] = Scenario.deck_of(Scenario.basic_land("Forest"), 10, gruul, 20)
	forest_and_dual.append_array(Scenario.copies(dual, 10))
	var with_dual: MmEngine = Scenario.find_engine(
		Scenario.setup_with(forest_and_dual, Scenario.copies(Scenario.vanilla("Card"), 40)),
		func(running: MmEngine) -> bool:
			return (Scenario.ready_in_main(running, 3, 2, "Gruul Charm")
				and _controlled(running, "Forest") == 1 and _controlled(running, "Wild Dual") == 1))
	var other_charm: int = Scenario.card_in_hand(with_dual, with_dual.hero(), "Gruul Charm")
	assert_true(Scenario.offers_cast(with_dual, other_charm), "A Forest and a Forest Mountain can.")


func test_floating_mana_counts_toward_paying() -> void:
	var engine: MmEngine = _bolts_and_spikes(1)
	var mountain: int = Scenario.first_permanent_of(engine, engine.hero().id)
	var bolt: int = Scenario.card_in_hand(engine, engine.hero(), "Bolt")

	engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, mountain))

	assert_eq(engine.hero().mana_pool().size(), 1)
	assert_true(Scenario.offers_cast(engine, bolt), "The floating {R} pays for it.")


func test_a_spell_with_no_legal_target_is_not_offered() -> void:
	# "{0}: target untapped land" with no lands on the battlefield.
	var free_spell: MmCardDefinition = Scenario.instant("Land Ping", Scenario.mana_cost(0),
		[Scenario.target(Scenario.untapped_land())], [Scenario.gain_life(1, YouSelection.new())])
	var engine: MmEngine = Scenario.find_engine(
		Scenario.setup_with(Scenario.deck_of(Scenario.basic_land("Forest"), 20, free_spell, 20), Scenario.copies(Scenario.vanilla("Card"), 40)),
		func(running: MmEngine) -> bool:
			Scenario.play_until_step(running, 1, Step.PRECOMBAT_MAIN)
			return Scenario.card_in_hand(running, running.hero(), "Land Ping") != -1 and Scenario.card_in_hand(running, running.hero(), "Forest") != -1)
	var ping: int = Scenario.card_in_hand(engine, engine.hero(), "Land Ping")

	assert_false(Scenario.offers_cast(engine, ping), "No land to target yet.")
	Scenario.play_first_land(engine)
	assert_true(Scenario.offers_cast(engine, ping))


## Hero and Villain decks of Mountains, Bolts and Spikes, in the Hero's main phase of
## [param game_turn] holding both spells.
func _bolts_and_spikes(game_turn: int) -> MmEngine:
	var spike: MmCardDefinition = Scenario.sorcery("Spike", Scenario.mana_cost(0, [Type.RED]),
		[Scenario.target_player()], [Scenario.deal_damage(3, Scenario.targeted(0))])
	var cards: Array[MmCardDefinition] = Scenario.deck_of(Scenario.basic_land("Mountain"), 16, Scenario.bolt(), 12)
	cards.append_array(Scenario.copies(spike, 12))
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, cards.duplicate()),
		func(running: MmEngine) -> bool:
			return Scenario.ready_in_main(running, game_turn, ceili(game_turn / 2.0), "Bolt") and Scenario.card_in_hand(running, running.hero(), "Spike") != -1)
	assert_not_null(engine, "No seed gave the needed hand.")
	return engine


func _controlled(engine: MmEngine, card_name: String) -> int:
	var found: int = 0
	for permanent: MmGameObject in engine.game_state().battlefield.objects():
		if permanent.controller_id == engine.hero().id and engine.game_state().characteristics_of(permanent).name == card_name:
			found += 1
	return found
