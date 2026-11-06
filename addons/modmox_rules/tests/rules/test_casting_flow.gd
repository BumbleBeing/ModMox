extends GutTest
## CR 601.2: casting a spell. The card moves to the stack, targets are chosen, then the
## cost is paid one step at a time. Mana from abilities activated while paying goes
## straight to the cost; any extra stays in the pool.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Type := MmMana.Type


func test_casting_moves_the_card_to_the_stack_as_a_new_object() -> void:
	var engine: MmEngine = _hero_with_bolt(1)
	var bolt: int = Scenario.card_in_hand(engine, engine.hero(), "Bolt")

	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, bolt))

	assert_eq(engine.game_state().stack.size(), 1)
	var on_stack: MmGameObject = engine.game_state().stack.objects()[0]
	assert_ne(on_stack.id, bolt)
	assert_true(engine.pending_decision() is ChooseTargetDecision)


func test_the_target_decision_lists_legal_candidates_players_first() -> void:
	var engine: MmEngine = _hero_with_bolt(1)
	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, Scenario.card_in_hand(engine, engine.hero(), "Bolt")))

	var decision: ChooseTargetDecision = engine.pending_decision() as ChooseTargetDecision

	assert_eq(decision.player_id, engine.hero().id)
	assert_eq(decision.candidates.size(), 2, "A Mountain is not a legal 'any target'.")
	assert_true(decision.candidates[0].equals(MmReference.to_player(engine.hero().id)))
	assert_true(decision.candidates[1].equals(MmReference.to_player(engine.villain().id)))


func test_invalid_target_answers_are_rejected_and_change_nothing() -> void:
	var engine: MmEngine = _hero_with_bolt(1)
	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, Scenario.card_in_hand(engine, engine.hero(), "Bolt")))
	var before: String = engine.fingerprint()

	for bad_answer: Variant in [2, -1, "villain", [1]]:
		assert_ne(engine.submit(bad_answer), "", "Answer %s should be rejected." % [bad_answer])

	assert_eq(engine.fingerprint(), before)


func test_tapping_a_land_while_paying_spends_its_mana_directly() -> void:
	var engine: MmEngine = _hero_with_bolt(1)
	var mountain: int = Scenario.first_permanent_of(engine, engine.hero().id)
	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, Scenario.card_in_hand(engine, engine.hero(), "Bolt")))
	Scenario.choose_target(engine, MmReference.to_player(engine.villain().id))
	assert_true(engine.pending_decision() is PayManaDecision)

	assert_eq(Scenario.pay_by_tapping(engine, mountain), "")

	assert_true(engine.game_state().object(mountain).is_tapped)
	assert_eq(engine.hero().mana_pool().size(), 0, "The mana went straight to the cost.")
	assert_true(engine.pending_decision() is PriorityDecision, "Fully paid: the spell is cast.")
	assert_eq(engine.pending_decision().player_id, engine.hero().id, "The caster receives priority (CR 117.3c).")
	assert_true(_logged(engine, ManaSpentEvent))


func test_floating_mana_can_pay() -> void:
	var engine: MmEngine = _hero_with_bolt(1)
	var mountain: int = Scenario.first_permanent_of(engine, engine.hero().id)
	engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, mountain))
	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, Scenario.card_in_hand(engine, engine.hero(), "Bolt")))
	Scenario.choose_target(engine, MmReference.to_player(engine.villain().id))

	assert_eq(Scenario.pay_with(engine, Type.RED), "")

	assert_eq(engine.hero().mana_pool().size(), 0)
	assert_eq(engine.game_state().stack.size(), 1)


func test_colored_mana_pays_its_own_symbol_before_generic() -> void:
	# {1}{R} with a Mountain and a Forest: the {R} must pay {R}, leaving {1} for the Forest.
	var shock: MmCardDefinition = Scenario.instant("Big Shock", Scenario.mana_cost(1, [Type.RED]),
		[Scenario.any_target()], [Scenario.deal_damage(2, Scenario.targeted(0))])
	var cards: Array[MmCardDefinition] = Scenario.deck_of(Scenario.basic_land("Mountain"), 10, shock, 20)
	cards.append_array(Scenario.copies(Scenario.basic_land("Forest"), 10))
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, Scenario.copies(Scenario.vanilla("Card"), 40)),
		func(running: MmEngine) -> bool:
			return Scenario.ready_in_main(running, 3, 2, "Big Shock") and _controlled(running, "Forest") == 1 and _controlled(running, "Mountain") == 1)
	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, Scenario.card_in_hand(engine, engine.hero(), "Big Shock")))
	Scenario.choose_target(engine, MmReference.to_player(engine.villain().id))

	assert_eq(Scenario.pay_by_tapping(engine, _permanent_named(engine, "Mountain")), "")
	var decision: PayManaDecision = engine.pending_decision() as PayManaDecision
	assert_eq(decision.remaining_symbols, [], "The {R} paid the {R} symbol.")
	assert_eq(decision.remaining_generic, 1)
	assert_eq(Scenario.pay_by_tapping(engine, _permanent_named(engine, "Forest")), "")

	assert_true(engine.pending_decision() is PriorityDecision, "Fully paid.")
	assert_eq(engine.game_state().stack.size(), 1)


func test_mana_of_the_wrong_color_is_not_offered() -> void:
	var cards: Array[MmCardDefinition] = Scenario.deck_of(Scenario.basic_land("Mountain"), 10, Scenario.bolt(), 20)
	cards.append_array(Scenario.copies(Scenario.basic_land("Forest"), 10))
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, Scenario.copies(Scenario.vanilla("Card"), 40)),
		func(running: MmEngine) -> bool:
			return Scenario.ready_in_main(running, 3, 2, "Bolt") and _controlled(running, "Forest") == 1 and _controlled(running, "Mountain") == 1)
	var forest: int = _permanent_named(engine, "Forest")
	engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, forest))
	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, Scenario.card_in_hand(engine, engine.hero(), "Bolt")))
	Scenario.choose_target(engine, MmReference.to_player(engine.villain().id))

	var decision: PayManaDecision = engine.pending_decision() as PayManaDecision
	for action: MmAction in decision.actions:
		assert_false(action is PayWithManaAction, "The floating {G} cannot pay {R}.")
	assert_ne(Scenario.pay_with(engine, Type.GREEN), "")


func test_extra_mana_from_an_ability_used_while_paying_stays_in_the_pool() -> void:
	var cards: Array[MmCardDefinition] = Scenario.deck_of(Scenario.mana_land("Ruby Spring", Type.RED, 2), 20, Scenario.bolt(), 20)
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, Scenario.copies(Scenario.vanilla("Card"), 40)),
		func(running: MmEngine) -> bool: return Scenario.ready_in_main(running, 1, 1, "Bolt"))
	var spring: int = Scenario.first_permanent_of(engine, engine.hero().id)
	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, Scenario.card_in_hand(engine, engine.hero(), "Bolt")))
	Scenario.choose_target(engine, MmReference.to_player(engine.villain().id))

	Scenario.pay_by_tapping(engine, spring)

	assert_true(engine.pending_decision() is PriorityDecision)
	var pool: Array[MmMana] = engine.hero().mana_pool()
	assert_eq(pool.size(), 1, "{R}{R} paid {R}; one {R} is left over.")
	assert_eq(pool[0].type, Type.RED)


func test_a_spell_with_no_cost_to_pay_skips_payment() -> void:
	var free_spell: MmCardDefinition = Scenario.instant("Freebie", Scenario.mana_cost(0), [], [Scenario.gain_life(2, YouSelection.new())])
	var engine: MmEngine = Scenario.find_engine(
		Scenario.setup_with(Scenario.copies(free_spell, 40), Scenario.copies(Scenario.vanilla("Card"), 40)),
		func(running: MmEngine) -> bool: return Scenario.keep_all(running) == "")

	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, Scenario.card_in_hand(engine, engine.hero(), "Freebie")))

	assert_true(engine.pending_decision() is PriorityDecision)
	assert_eq(engine.game_state().stack.size(), 1)


func test_a_payment_that_can_no_longer_finish_rewinds_the_whole_cast() -> void:
	# {R}{G} with a Forest and a Forest Mountain: tapping the dual for {G} leaves {R} unpayable.
	var gruul: MmCardDefinition = Scenario.instant("Gruul Charm", Scenario.mana_cost(0, [Type.RED, Type.GREEN]), [], [])
	var dual: MmCardDefinition = Scenario.basic_land("Forest")
	dual.name = "Wild Dual"
	dual.subtypes = ["Forest", "Mountain"]
	var cards: Array[MmCardDefinition] = Scenario.deck_of(Scenario.basic_land("Forest"), 10, gruul, 20)
	cards.append_array(Scenario.copies(dual, 10))
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, Scenario.copies(Scenario.vanilla("Card"), 40)),
		func(running: MmEngine) -> bool:
			return Scenario.ready_in_main(running, 3, 2, "Gruul Charm") and _controlled(running, "Forest") == 1 and _controlled(running, "Wild Dual") == 1)
	var before: String = engine.fingerprint()
	var logged: int = engine.decision_log().size()
	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, Scenario.card_in_hand(engine, engine.hero(), "Gruul Charm")))

	assert_eq(Scenario.pay_by_tapping(engine, _permanent_named(engine, "Wild Dual"), 0), "", "Tap the dual for {G}.")

	assert_true(engine.pending_decision() is PriorityDecision, "Back to before the cast.")
	assert_eq(engine.fingerprint(), before)
	assert_eq(engine.decision_log().size(), logged)


func _hero_with_bolt(game_turn: int) -> MmEngine:
	var cards: Array[MmCardDefinition] = Scenario.deck_of(Scenario.basic_land("Mountain"), 20, Scenario.bolt(), 20)
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, cards.duplicate()),
		func(running: MmEngine) -> bool: return Scenario.ready_in_main(running, game_turn, 1, "Bolt"))
	assert_not_null(engine, "No seed gave the needed hand.")
	return engine


func _controlled(engine: MmEngine, card_name: String) -> int:
	var found: int = 0
	for permanent: MmGameObject in engine.game_state().battlefield.objects():
		if permanent.controller_id == engine.hero().id and engine.game_state().characteristics_of(permanent).name == card_name:
			found += 1
	return found


func _permanent_named(engine: MmEngine, card_name: String) -> int:
	for permanent: MmGameObject in engine.game_state().battlefield.objects():
		if engine.game_state().characteristics_of(permanent).name == card_name:
			return permanent.id
	return -1


func _logged(engine: MmEngine, event_script: Script) -> bool:
	for event: MmEvent in engine.event_log():
		if is_instance_of(event, event_script):
			return true
	return false
