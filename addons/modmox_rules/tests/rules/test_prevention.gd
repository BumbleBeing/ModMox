extends GutTest
## Prevention effects (CR 615): "prevent all" effects that last the turn, shields that
## prevent the next N damage, and the affected player choosing which applies first when
## several do (CR 616.1).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_fog_prevents_all_combat_damage_both_ways() -> void:
	var fog: MmCardDefinition = Scenario.free_fog("Fog")
	var engine: MmEngine = Scenario.combat_ready([_giant()], [_bear()], [fog])
	var giant: int = Scenario.permanent_named(engine, engine.hero().id, "Giant")
	var bear: int = Scenario.permanent_named(engine, engine.villain().id, "Bear")
	Scenario.declare_attackers(engine, [giant])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[bear, giant]])

	assert_eq(Scenario.cast_and_resolve(engine, "Fog"), "")
	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(Scenario.damage_on(engine, giant), 0, "CR 615.1")
	assert_eq(Scenario.damage_on(engine, bear), 0)
	assert_eq(Scenario.combat_damage_events(engine), [], "Prevented damage is never dealt.")
	assert_eq(Scenario.prevented(engine).size(), 2)


func test_fog_keeps_an_unblocked_attacker_from_damaging_the_player() -> void:
	var engine: MmEngine = Scenario.combat_ready([_giant()], [], [Scenario.free_fog("Fog")])
	Scenario.declare_attackers(engine, [Scenario.permanent_named(engine, engine.hero().id, "Giant")])

	assert_eq(Scenario.cast_and_resolve(engine, "Fog"), "")
	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(engine.villain().life, 20)
	var prevention: DamagePreventedEvent = Scenario.prevented(engine)[0] as DamagePreventedEvent
	assert_eq(prevention.amount, 5)
	assert_true(prevention.is_combat)
	assert_true(prevention.recipient.equals(MmReference.to_player(engine.villain().id)))


func test_fog_does_not_prevent_noncombat_damage() -> void:
	var engine: MmEngine = _main_ready([], [], [Scenario.free_fog("Fog"), Scenario.free_shock("Shock", 3)])
	Scenario.cast_and_resolve(engine, "Fog")

	Scenario.cast_and_resolve(engine, "Shock", [MmReference.to_player(engine.villain().id)])

	assert_eq(engine.villain().life, 17)
	assert_eq(Scenario.prevented(engine), [])


func test_fog_prevents_damage_from_a_creature_that_arrived_after_it_resolved() -> void:
	# CR 611.2c: an effect that changes the rules rather than characteristics applies to
	# objects that were not there when it began.
	var raider: MmCardDefinition = Scenario.creature("Raider", 3, 3, [HasteAbility.new()])
	var engine: MmEngine = _main_ready([], [], [Scenario.free_fog("Fog"), raider])
	Scenario.cast_and_resolve(engine, "Fog")
	Scenario.cast_and_resolve(engine, "Raider")
	Scenario.pass_until_step(engine, Step.DECLARE_ATTACKERS)

	Scenario.declare_attackers(engine, [Scenario.permanent_named(engine, engine.hero().id, "Raider")])
	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(engine.villain().life, 20)


func test_fog_stops_a_deathtouch_blocker_from_destroying_its_attacker() -> void:
	var viper: MmCardDefinition = Scenario.creature("Viper", 1, 1, [DeathtouchAbility.new()])
	var engine: MmEngine = Scenario.combat_ready([_giant()], [viper], [Scenario.free_fog("Fog")])
	var giant: int = Scenario.permanent_named(engine, engine.hero().id, "Giant")
	Scenario.declare_attackers(engine, [giant])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[Scenario.permanent_named(engine, engine.villain().id, "Viper"), giant]])

	Scenario.cast_and_resolve(engine, "Fog")
	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_not_null(engine.game_state().object(giant))
	assert_false(engine.game_state().object(giant).was_dealt_deathtouch_damage)


func test_a_shield_prevents_only_its_amount() -> void:
	var engine: MmEngine = _main_ready([_giant()], [], [Scenario.free_shield("Ward", 1), Scenario.free_shock("Shock", 3)])
	var giant: int = Scenario.permanent_named(engine, engine.hero().id, "Giant")
	Scenario.cast_and_resolve(engine, "Ward", [MmReference.to_object(giant)])

	Scenario.cast_and_resolve(engine, "Shock", [MmReference.to_object(giant)])

	assert_eq(Scenario.damage_on(engine, giant), 2)
	assert_eq((Scenario.prevented(engine)[0] as DamagePreventedEvent).amount, 1)
	assert_eq(engine.game_state().replacement_effects, [], "A used-up shield is gone.")


func test_a_shield_counts_down_across_separate_damage_events() -> void:
	var twice: MmCardDefinition = Scenario.instant("Twin Bolt", Scenario.mana_cost(0), [Scenario.any_target()],
		[Scenario.deal_damage(2, Scenario.targeted(0)), Scenario.deal_damage(2, Scenario.targeted(0))])
	var engine: MmEngine = _main_ready([_giant()], [], [Scenario.free_shield("Ward", 3), twice])
	var giant: int = Scenario.permanent_named(engine, engine.hero().id, "Giant")
	Scenario.cast_and_resolve(engine, "Ward", [MmReference.to_object(giant)])

	Scenario.cast_and_resolve(engine, "Twin Bolt", [MmReference.to_object(giant)])

	assert_eq(Scenario.damage_on(engine, giant), 1)
	var amounts: Array[int] = []
	for event: MmEvent in Scenario.prevented(engine):
		amounts.append((event as DamagePreventedEvent).amount)
	assert_eq(amounts, [2, 1])


func test_a_shield_on_a_player_prevents_damage_to_that_player() -> void:
	var engine: MmEngine = _main_ready([], [], [Scenario.free_shield("Ward", 2), Scenario.free_shock("Shock", 3)])
	var villain: MmReference = MmReference.to_player(engine.villain().id)
	Scenario.cast_and_resolve(engine, "Ward", [villain])

	Scenario.cast_and_resolve(engine, "Shock", [villain])

	assert_eq(engine.villain().life, 19)


func test_an_unused_shield_ends_in_the_cleanup_step() -> void:
	# CR 514.2: "this turn" effects end with "until end of turn" ones.
	var engine: MmEngine = _main_ready([_giant()], [], [Scenario.free_shield("Ward", 1)])
	var giant: int = Scenario.permanent_named(engine, engine.hero().id, "Giant")
	Scenario.cast_and_resolve(engine, "Ward", [MmReference.to_object(giant)])
	assert_eq(engine.game_state().replacement_effects.size(), 1)

	Scenario.play_until_game_turn(engine, 4)

	assert_eq(engine.game_state().replacement_effects, [])


func test_the_affected_player_chooses_which_prevention_applies_first() -> void:
	# CR 616.1: the shield chosen first is used up; the other is kept for later.
	var engine: MmEngine = _main_ready([], [], _choice_cards())
	var hero: MmReference = MmReference.to_player(engine.hero().id)
	var ward: int = _cast_for_card_id(engine, "Ward", hero)
	var sanctuary: int = _cast_for_card_id(engine, "Sanctuary", hero)

	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Shock"), [hero])
	Scenario.pass_to_replacement_choice(engine)

	var decision: ChooseReplacementEffectDecision = engine.pending_decision() as ChooseReplacementEffectDecision
	assert_eq(decision.player_id, engine.hero().id)
	assert_eq(decision.options.size(), 2)
	assert_eq(Scenario.choose_replacement_from(engine, sanctuary), "")
	assert_eq(engine.hero().life, 20)
	assert_eq(engine.game_state().replacement_effects.size(), 2, "The Ward shield was not needed.")
	assert_eq(engine.game_state().replacement_effects[0].source_card_id, ward)
	assert_eq(engine.game_state().replacement_effects[0].remaining, 1)


func test_choosing_the_shield_first_uses_it_and_the_other_effect_prevents_the_rest() -> void:
	var engine: MmEngine = _main_ready([], [], _choice_cards())
	var hero: MmReference = MmReference.to_player(engine.hero().id)
	var ward: int = _cast_for_card_id(engine, "Ward", hero)
	_cast_for_card_id(engine, "Sanctuary", hero)
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Shock"), [hero])
	Scenario.pass_to_replacement_choice(engine)

	assert_eq(Scenario.choose_replacement_from(engine, ward), "")

	assert_eq(engine.hero().life, 20)
	assert_eq(engine.game_state().replacement_effects.size(), 1, "Only the turn-long effect is left.")
	var amounts: Array[int] = []
	for event: MmEvent in Scenario.prevented(engine):
		amounts.append((event as DamagePreventedEvent).amount)
	assert_eq(amounts, [1, 2])


func test_a_single_applicable_effect_needs_no_choice() -> void:
	var engine: MmEngine = _main_ready([], [], _choice_cards())
	var hero: MmReference = MmReference.to_player(engine.hero().id)
	_cast_for_card_id(engine, "Ward", hero)

	Scenario.cast_and_resolve(engine, "Shock", [hero])

	assert_true(engine.pending_decision() is PriorityDecision)
	assert_eq(engine.hero().life, 18)


func test_interchangeable_shields_need_no_choice() -> void:
	var engine: MmEngine = _main_ready([_giant()], [],
		[Scenario.free_shield("Ward", 1), Scenario.free_shield("Other Ward", 1), Scenario.free_shock("Shock", 3)])
	var giant: MmReference = MmReference.to_object(Scenario.permanent_named(engine, engine.hero().id, "Giant"))
	Scenario.cast_and_resolve(engine, "Ward", [giant])
	Scenario.cast_and_resolve(engine, "Other Ward", [giant])

	Scenario.cast_and_resolve(engine, "Shock", [giant])

	assert_true(engine.pending_decision() is PriorityDecision, "Either order gives the same result.")
	assert_eq(Scenario.damage_on(engine, giant.id), 1)
	assert_eq(engine.game_state().replacement_effects, [], "Each shield prevented 1.")


func test_of_interchangeable_shields_the_earliest_is_used_first() -> void:
	var engine: MmEngine = _main_ready([_giant()], [],
		[Scenario.free_shield("Ward", 1), Scenario.free_shield("Other Ward", 1), Scenario.free_shock("Shock", 1)])
	var giant: MmReference = MmReference.to_object(Scenario.permanent_named(engine, engine.hero().id, "Giant"))
	_cast_for_card_id(engine, "Ward", giant)
	var other: int = _cast_for_card_id(engine, "Other Ward", giant)

	Scenario.cast_and_resolve(engine, "Shock", [giant])

	assert_eq(engine.game_state().replacement_effects.size(), 1)
	assert_eq(engine.game_state().replacement_effects[0].source_card_id, other)


func test_two_effects_that_prevent_everything_need_no_choice() -> void:
	var engine: MmEngine = _main_ready([_giant()], [], [Scenario.free_fog("Fog"), Scenario.free_fog("Haze")])
	Scenario.cast_and_resolve(engine, "Fog")
	Scenario.cast_and_resolve(engine, "Haze")
	Scenario.pass_until_step(engine, Step.DECLARE_ATTACKERS)

	Scenario.declare_attackers(engine, [Scenario.permanent_named(engine, engine.hero().id, "Giant")])
	assert_true(Scenario.pass_until_step_without_replacement_choice(engine, Step.END_OF_COMBAT), "No replacement decision is asked.")

	assert_eq(engine.villain().life, 20)
	assert_eq(Scenario.prevented(engine).size(), 1, "The first effect prevents it all; the other no longer applies.")


func test_a_tapped_healer_shields_a_creature() -> void:
	var engine: MmEngine = _main_ready([Scenario.healer("Healer"), _giant()], [], [Scenario.free_shock("Shock", 3)])
	var healer: int = Scenario.permanent_named(engine, engine.hero().id, "Healer")
	var giant: MmReference = MmReference.to_object(Scenario.permanent_named(engine, engine.hero().id, "Giant"))

	assert_eq(Scenario.activate(engine, healer, [giant]), "")
	Scenario.resolve_stack(engine)
	Scenario.cast_and_resolve(engine, "Shock", [giant])

	assert_true(engine.game_state().object(healer).is_tapped)
	assert_eq(Scenario.damage_on(engine, giant.id), 2)
	assert_eq((Scenario.prevented(engine)[0] as DamagePreventedEvent).prevented_by_card_id, Scenario.card_of(engine, healer))


func test_the_amount_a_shield_has_left_is_part_of_the_fingerprint() -> void:
	var engine: MmEngine = _main_ready([_giant()], [], [Scenario.free_shield("Ward", 2)])
	var giant: MmReference = MmReference.to_object(Scenario.permanent_named(engine, engine.hero().id, "Giant"))
	Scenario.cast_and_resolve(engine, "Ward", [giant])
	var shield: int = engine.game_state().replacement_effects[0].timestamp
	var used: MmGameState = engine.game_state().duplicate_state()
	var unused: MmGameState = engine.game_state().duplicate_state()

	used.perform(DamagePreventedEvent.new(giant.id, giant, 1, false, 0, shield))
	unused.perform(DamagePreventedEvent.new(giant.id, giant, 1, false, 0, 0))

	assert_ne(used.fingerprint(), unused.fingerprint())


func _choice_cards() -> Array[MmCardDefinition]:
	var sanctuary: MmCardDefinition = Scenario.instant("Sanctuary", Scenario.mana_cost(0), [Scenario.any_target()],
		[Scenario.prevent_all(Scenario.targeted(0), false)])
	return [Scenario.free_shield("Ward", 1), sanctuary, Scenario.free_shock("Shock", 3)]


## Casts and resolves [param card_name] at [param chosen], and returns its Card Identity.
func _cast_for_card_id(engine: MmEngine, card_name: String, chosen: MmReference) -> int:
	var card: int = engine.game_state().object(Scenario.card_in_hand(engine, engine.hero(), card_name)).card_id
	assert_eq(Scenario.cast_and_resolve(engine, card_name, [chosen]), "")
	return card


func _main_ready(hero_creatures: Array[MmCardDefinition], villain_creatures: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_creatures, villain_creatures, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_creatures, villain_creatures, hero_extras, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	return engine


func _giant() -> MmCardDefinition:
	return Scenario.creature("Giant", 5, 5)


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)
