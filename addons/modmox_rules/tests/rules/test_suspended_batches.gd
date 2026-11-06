extends GutTest
## A batch of events stops part-way when a replacement choice is needed, and carries on
## once it is answered (ADR 0007, A134, A143): the rest of a resolving spell waits for it,
## and undo, copies and replays all work while a batch is suspended.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_the_affected_player_chooses_in_the_middle_of_another_players_spell() -> void:
	var engine: MmEngine = _main_ready([], [], _shield_cards_and_shock())
	var villain: MmReference = MmReference.to_player(engine.villain().id)
	Scenario.cast_and_resolve(engine, "Ward", [villain])
	Scenario.cast_and_resolve(engine, "Sanctuary", [villain])
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Shock and Draw"), [villain])
	var hand_size: int = engine.hero().hand.size()

	Scenario.pass_to_replacement_choice(engine)

	assert_eq(engine.pending_decision().player_id, engine.villain().id, "CR 616.1: the affected player chooses.")
	assert_eq(engine.hero().hand.size(), hand_size, "The draw waits until the damage is dealt.")
	assert_eq(engine.game_state().stack.size(), 1, "The spell stays on the stack until it has finished.")
	assert_eq(engine.submit(0), "")
	assert_eq(engine.hero().hand.size(), hand_size + 1)
	assert_eq(engine.game_state().stack.size(), 0)
	assert_eq(engine.villain().life, 20)
	assert_true(engine.pending_decision() is PriorityDecision)
	assert_eq(engine.pending_decision().player_id, engine.hero().id, "CR 117.3b")


func test_a_suspended_batch_is_copied_with_the_state() -> void:
	var engine: MmEngine = _main_ready([], [], _shield_cards_and_shock())
	var villain: MmReference = MmReference.to_player(engine.villain().id)
	Scenario.cast_and_resolve(engine, "Ward", [villain])
	Scenario.cast_and_resolve(engine, "Sanctuary", [villain])
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Shock and Draw"), [villain])
	Scenario.pass_to_replacement_choice(engine)

	var copy: MmGameState = engine.game_state().duplicate_state()

	assert_true(engine.game_state().is_batch_suspended())
	assert_true(copy.is_batch_suspended())
	assert_eq(copy.fingerprint(), engine.game_state().fingerprint())


func test_undo_inside_a_suspended_batch_returns_to_the_earlier_choice() -> void:
	var engine: MmEngine = _two_attackers_against_shields()
	var setup_engine_log: Array = engine.decision_log()
	assert_true(engine.pending_decision() is ChooseReplacementEffectDecision)
	var before: String = engine.fingerprint()
	var sanctuary: int = _option_card(engine, 1)

	assert_eq(Scenario.choose_replacement_from(engine, sanctuary), "")
	assert_true(engine.pending_decision() is ChooseReplacementEffectDecision, "The second attacker's damage needs a choice too.")
	assert_true(engine.can_undo())
	assert_eq(engine.undo(), "")

	assert_eq(engine.fingerprint(), before)
	assert_eq(engine.decision_log(), setup_engine_log)


func test_replaying_through_suspended_batches_reproduces_the_state() -> void:
	var setup: MmEncounterSetup = _two_attackers_setup()
	var engine: MmEngine = _two_attackers_against_shields(setup)
	assert_eq(Scenario.choose_replacement_from(engine, _option_card(engine, 1)), "")
	assert_eq(Scenario.choose_replacement_from(engine, _option_card(engine, 0)), "")
	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)
	assert_eq(engine.hero().life, 20)

	var replayed: MmEngine = MmEngine.replay(setup, engine.decision_log())

	assert_eq(replayed.fingerprint(), engine.fingerprint())


func test_damage_to_each_creature_is_dealt_in_one_batch() -> void:
	# CR 120: "deals 1 damage to each creature" deals it all at once (A144).
	var sweep: MmCardDefinition = Scenario.instant("Sweep", Scenario.mana_cost(0), [], [Scenario.deal_damage(1, Scenario.each_creature())])
	var engine: MmEngine = _main_ready([Scenario.creature("Bear", 2, 2)], [Scenario.creature("Bear", 2, 2)], [sweep])

	Scenario.cast_and_resolve(engine, "Sweep")

	var batches: Array[int] = []
	for event: MmEvent in Scenario.events_of(engine, DamageEvent):
		batches.append(event.batch)
	assert_eq(batches.size(), 2)
	assert_eq(batches[0], batches[1])


func test_drawing_several_cards_is_still_one_draw_at_a_time() -> void:
	# CR 121.2: each draw is its own event.
	var engine: MmEngine = _main_ready([], [], [Scenario.free_draw("Insight", 2)])

	Scenario.cast_and_resolve(engine, "Insight", [MmReference.to_player(engine.hero().id)])

	var draws: Array[int] = []
	for event: MmEvent in engine.event_log():
		var moved: ZoneChangeEvent = event as ZoneChangeEvent
		if moved != null and moved.reason == ZoneChangeEvent.Reason.DRAW and event.batch > 0:
			draws.append(event.batch)
	assert_ne(draws[draws.size() - 1], draws[draws.size() - 2])


func _shield_cards() -> Array[MmCardDefinition]:
	var sanctuary: MmCardDefinition = Scenario.instant("Sanctuary", Scenario.mana_cost(0), [Scenario.any_target()],
		[Scenario.prevent_all(Scenario.targeted(0), false)])
	return [Scenario.free_shield("Ward", 1), sanctuary]


func _shield_cards_and_shock() -> Array[MmCardDefinition]:
	var cards: Array[MmCardDefinition] = _shield_cards()
	cards.append(_shock_and_draw())
	return cards


func _shock_and_draw() -> MmCardDefinition:
	return Scenario.instant("Shock and Draw", Scenario.mana_cost(0), [Scenario.any_target()],
		[Scenario.deal_damage(3, Scenario.targeted(0)), Scenario.draw_cards(1, Scenario.you())])


func _two_attackers_setup() -> MmEncounterSetup:
	var no_cards: Array[MmCardDefinition] = []
	return Scenario.combat_setup(no_cards, _attackers(), _shield_cards())


## The Villain attacks with two creatures on Game Turn 4, and the Hero, protected by Ward
## and Sanctuary, faces a replacement choice for the first attacker's damage.
func _two_attackers_against_shields(setup: MmEncounterSetup = null) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var combat: MmEncounterSetup = _two_attackers_setup() if setup == null else setup
	var engine: MmEngine = Scenario.permanents_ready_with(combat, no_cards, _attackers(), _shield_cards(), no_cards, 4, Step.DECLARE_ATTACKERS)
	assert_not_null(engine, "No seed gave the needed hand.")
	var hero: MmReference = MmReference.to_player(engine.hero().id)
	Scenario.declare_attackers(engine, (engine.pending_decision() as DeclareAttackersDecision).candidate_ids)
	Scenario.pass_priority(engine)
	Scenario.cast_and_resolve(engine, "Ward", [hero])
	Scenario.pass_priority(engine)
	Scenario.cast_and_resolve(engine, "Sanctuary", [hero])
	Scenario.pass_to_replacement_choice(engine)
	return engine


func _attackers() -> Array[MmCardDefinition]:
	return [Scenario.creature("Raider", 2, 2), Scenario.creature("Brute", 2, 2)]


## The source Card Identity of option [param index] of the pending replacement decision.
func _option_card(engine: MmEngine, index: int) -> int:
	return (engine.pending_decision() as ChooseReplacementEffectDecision).options[index].source_card_id


func _main_ready(hero_creatures: Array[MmCardDefinition], villain_creatures: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_creatures, villain_creatures, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_creatures, villain_creatures, hero_extras, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	return engine
