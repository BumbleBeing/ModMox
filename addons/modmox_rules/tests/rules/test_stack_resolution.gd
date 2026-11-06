extends GutTest
## CR 405, 608: the stack resolves last in, first out when both players pass in
## succession; targets are rechecked on resolution.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const Type := MmMana.Type


func test_both_passing_resolves_the_top_item_and_the_step_continues() -> void:
	var engine: MmEngine = _hero_with(1, Scenario.bolt(), "Bolt", 1)
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bolt"), [MmReference.to_player(engine.villain().id)])

	Scenario.pass_priority(engine)
	assert_eq(engine.villain().life, 20, "One pass resolves nothing.")
	Scenario.pass_priority(engine)

	assert_eq(engine.villain().life, 17)
	assert_eq(engine.game_state().stack.size(), 0)
	assert_eq(engine.game_state().step, Step.PRECOMBAT_MAIN, "Resolving does not end the step.")
	assert_eq(engine.pending_decision().player_id, engine.hero().id, "The active player receives priority (CR 117.3b).")


func test_a_resolved_instant_goes_to_its_owners_graveyard() -> void:
	var engine: MmEngine = _hero_with(1, Scenario.bolt(), "Bolt", 1)
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bolt"), [MmReference.to_player(engine.villain().id)])

	Scenario.pass_priority(engine)
	Scenario.pass_priority(engine)

	assert_eq(Scenario.names(engine, engine.hero().graveyard), ["Bolt"])


func test_the_stack_resolves_last_in_first_out() -> void:
	var engine: MmEngine = _hero_with(3, Scenario.bolt(), "Bolt", 2, 2)
	var bolts: Array[int] = _cards_named(engine, engine.hero(), "Bolt")
	Scenario.cast(engine, bolts[0], [MmReference.to_player(engine.villain().id)])
	Scenario.cast(engine, bolts[1], [MmReference.to_player(engine.hero().id)])

	Scenario.pass_priority(engine)
	Scenario.pass_priority(engine)

	assert_eq(engine.hero().life, 17, "The second Bolt, cast last, resolves first.")
	assert_eq(engine.villain().life, 20)


func test_the_opponent_can_respond_with_an_instant() -> void:
	var cards: Array[MmCardDefinition] = Scenario.deck_of(Scenario.basic_land("Mountain"), 20, Scenario.bolt(), 20)
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, cards.duplicate()),
		func(running: MmEngine) -> bool:
			return (Scenario.ready_in_main(running, 3, 2, "Bolt")
				and Scenario.card_in_hand(running, running.villain(), "Bolt") != -1
				and Scenario.first_permanent_of(running, running.villain().id) != -1))
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bolt"), [MmReference.to_player(engine.villain().id)])
	Scenario.pass_priority(engine)

	var villain_bolt: int = Scenario.card_in_hand(engine, engine.villain(), "Bolt")
	assert_eq(Scenario.cast(engine, villain_bolt, [MmReference.to_player(engine.hero().id)]), "")
	assert_eq(engine.pending_decision().player_id, engine.villain().id, "The caster, not the active player, gets priority (CR 117.3c).")
	Scenario.pass_priority(engine)
	Scenario.pass_priority(engine)

	assert_eq(engine.hero().life, 17)
	assert_eq(engine.villain().life, 20, "Only the response has resolved so far.")


func test_a_spell_whose_only_target_became_illegal_does_not_resolve() -> void:
	# Target your own untapped Mountain, then tap it for mana in response.
	var probe: MmCardDefinition = Scenario.instant("Probe", Scenario.mana_cost(0, [Type.RED]),
		[Scenario.target(Scenario.untapped_land())], [Scenario.gain_life(5, YouSelection.new())])
	var engine: MmEngine = _hero_with(3, probe, "Probe", 2)
	var lands: Array[int] = _permanents_of(engine, engine.hero().id)
	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, Scenario.card_in_hand(engine, engine.hero(), "Probe")))
	Scenario.choose_target(engine, MmReference.to_object(lands[1]))
	Scenario.pay_by_tapping(engine, lands[0])
	engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, lands[1]))

	Scenario.pass_priority(engine)
	Scenario.pass_priority(engine)

	assert_eq(engine.hero().life, 20, "The spell did not resolve, so nothing happened.")
	assert_eq(Scenario.names(engine, engine.hero().graveyard), ["Probe"], "It still goes to the graveyard (CR 608.2n).")
	assert_true(_moved_with_reason(engine, ZoneChangeEvent.Reason.DID_NOT_RESOLVE))


func test_with_one_target_still_legal_the_spell_resolves_for_that_target() -> void:
	var probe: MmCardDefinition = Scenario.instant("Probe", Scenario.mana_cost(0, [Type.RED]),
		[Scenario.target(Scenario.untapped_land()), Scenario.target_player()], [Scenario.gain_life(5, Scenario.targeted(1))])
	var engine: MmEngine = _hero_with(3, probe, "Probe", 2)
	var lands: Array[int] = _permanents_of(engine, engine.hero().id)
	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, Scenario.card_in_hand(engine, engine.hero(), "Probe")))
	Scenario.choose_target(engine, MmReference.to_object(lands[1]))
	Scenario.choose_target(engine, MmReference.to_player(engine.hero().id))
	Scenario.pay_by_tapping(engine, lands[0])
	engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, lands[1]))

	Scenario.pass_priority(engine)
	Scenario.pass_priority(engine)

	assert_eq(engine.hero().life, 25)
	assert_true(_moved_with_reason(engine, ZoneChangeEvent.Reason.RESOLVED))


func test_an_ability_that_uses_the_stack_is_a_game_object_that_is_not_a_card() -> void:
	var cards: Array[MmCardDefinition] = Scenario.copies(Scenario.life_land(), 40)
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(cards, cards.duplicate()))
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)
	var land: int = Scenario.play_first_land(engine)

	engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, land))
	Scenario.choose_target(engine, MmReference.to_player(engine.hero().id))

	assert_eq(engine.game_state().stack.size(), 1)
	var on_stack: MmGameObject = engine.game_state().stack.objects()[0]
	assert_false(on_stack.is_card())
	assert_eq(on_stack.source_object_id, land)
	assert_eq(engine.game_state().characteristics_of(on_stack).name, "Life Land ability")
	assert_true(engine.game_state().object(land).is_tapped, "Costs are paid on activation.")
	Scenario.pass_priority(engine)
	Scenario.pass_priority(engine)
	assert_eq(engine.hero().life, 21)
	assert_eq(engine.game_state().stack.size(), 0)
	assert_null(engine.game_state().object(on_stack.id), "The ability is gone once it resolves.")


func test_a_spell_that_adds_mana_uses_the_stack() -> void:
	# A spell is never a mana ability, so Dark Ritual-style mana arrives on resolution.
	var ritual: MmCardDefinition = Scenario.instant("Ritual", Scenario.mana_cost(0, [Type.BLACK]), [], [Scenario.add_mana(Type.BLACK, 3)])
	var engine: MmEngine = _hero_with(1, ritual, "Ritual", 1, 1, "Swamp")
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Ritual"))

	assert_eq(engine.game_state().stack.size(), 1)
	assert_eq(engine.hero().mana_pool().size(), 0)
	Scenario.pass_priority(engine)
	Scenario.pass_priority(engine)

	var pool: Array[MmMana] = engine.hero().mana_pool()
	assert_eq(pool.size(), 3)
	for mana: MmMana in pool:
		assert_eq(mana.type, Type.BLACK)


## The Hero in their main phase of [param game_turn] controlling [param lands] lands and
## holding at least [param copies_needed] cards named [param card_name].
func _hero_with(game_turn: int, card: MmCardDefinition, card_name: String, lands: int,
		copies_needed: int = 1, land_type: String = "Mountain") -> MmEngine:
	var cards: Array[MmCardDefinition] = Scenario.deck_of(Scenario.basic_land(land_type), 20, card, 20)
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, Scenario.copies(Scenario.vanilla("Card"), 40)),
		func(running: MmEngine) -> bool:
			return Scenario.ready_in_main(running, game_turn, lands, card_name) and _cards_named(running, running.hero(), card_name).size() >= copies_needed)
	assert_not_null(engine, "No seed gave the needed hand.")
	return engine


func _cards_named(engine: MmEngine, player: MmPlayer, card_name: String) -> Array[int]:
	var result: Array[int] = []
	for card: MmGameObject in player.hand.objects():
		if engine.game_state().characteristics_of(card).name == card_name:
			result.append(card.id)
	return result


func _permanents_of(engine: MmEngine, player_id: int) -> Array[int]:
	var result: Array[int] = []
	for permanent: MmGameObject in engine.game_state().battlefield.objects():
		if permanent.controller_id == player_id:
			result.append(permanent.id)
	return result


func _moved_with_reason(engine: MmEngine, reason: ZoneChangeEvent.Reason) -> bool:
	for event: MmEvent in engine.event_log():
		if event is ZoneChangeEvent and (event as ZoneChangeEvent).reason == reason:
			return true
	return false
