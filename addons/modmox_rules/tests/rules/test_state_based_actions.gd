extends GutTest
## CR 704: state-based actions are checked whenever a player would receive priority, and
## everything that applies happens at once. Creatures die from lethal damage (704.5g) and
## from toughness 0 or less (704.5f).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_a_creature_with_lethal_damage_is_destroyed() -> void:
	var bolt: MmCardDefinition = Scenario.free_shock("Bolt", 3)
	var engine: MmEngine = Scenario.combat_ready([], [_bear()], [bolt])
	var bear: int = Scenario.permanent_named(engine, engine.villain().id, "Bear")
	var card: int = engine.game_state().object(bear).card_id

	assert_eq(Scenario.cast_and_resolve(engine, "Bolt", [MmReference.to_object(bear)]), "")

	assert_null(engine.game_state().object(bear), "ADR 0008: it is a new object in the graveyard.")
	assert_eq(Scenario.card_ids(engine.villain().graveyard), [card])
	assert_eq(Scenario.last_reason_into(engine, MmZone.Kind.GRAVEYARD), ZoneChangeEvent.Reason.DESTROY)
	assert_true(engine.pending_decision() is PriorityDecision, "Checked before the player got priority.")


func test_a_creature_with_toughness_zero_is_put_into_the_graveyard() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(
		Scenario.copies(Scenario.creature("Shade", 1, 0), 40), Scenario.copies(Scenario.vanilla("Card"), 40)))
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)

	assert_eq(Scenario.cast_and_resolve(engine, "Shade"), "")

	assert_eq(Scenario.permanent_named(engine, engine.hero().id, "Shade"), -1)
	assert_eq(engine.hero().graveyard.size(), 1)
	assert_eq(Scenario.last_reason_into(engine, MmZone.Kind.GRAVEYARD), ZoneChangeEvent.Reason.ZERO_TOUGHNESS)


func test_damage_adds_up_until_it_is_lethal() -> void:
	var shock: MmCardDefinition = Scenario.free_shock("Shock", 1)
	var engine: MmEngine = Scenario.combat_ready([], [_bear()], [shock])
	var bear: int = Scenario.permanent_named(engine, engine.villain().id, "Bear")

	Scenario.cast_and_resolve(engine, "Shock", [MmReference.to_object(bear)])
	assert_eq(Scenario.damage_on(engine, bear), 1, "A 2/2 survives 1 damage.")
	Scenario.cast_and_resolve(engine, "Shock", [MmReference.to_object(bear)])

	assert_null(engine.game_state().object(bear))
	assert_eq(engine.villain().graveyard.size(), 1)


func test_creatures_that_trade_in_combat_die_together() -> void:
	var engine: MmEngine = Scenario.combat_ready([_bear()], [_bear()])
	var attacker: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var blocker: int = Scenario.permanent_named(engine, engine.villain().id, "Bear")
	Scenario.declare_attackers(engine, [attacker])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[blocker, attacker]])

	Scenario.pass_until_step(engine, Step.COMBAT_DAMAGE)

	assert_eq(engine.hero().graveyard.size(), 1)
	assert_eq(engine.villain().graveyard.size(), 1)


func test_a_first_striker_kills_its_blocker_before_the_blocker_strikes() -> void:
	var archer: MmCardDefinition = Scenario.creature("Archer", 1, 2, [FirstStrikeAbility.new()])
	var engine: MmEngine = Scenario.combat_ready([archer], [Scenario.creature("Goblin", 1, 1)])
	var archer_id: int = Scenario.permanent_named(engine, engine.hero().id, "Archer")
	var goblin: int = Scenario.permanent_named(engine, engine.villain().id, "Goblin")
	Scenario.declare_attackers(engine, [archer_id])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[goblin, archer_id]])

	Scenario.pass_until_step(engine, Step.COMBAT_DAMAGE)
	assert_null(engine.game_state().object(goblin), "Dead before the regular damage step.")
	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(Scenario.damage_on(engine, archer_id), 0)
	assert_eq(engine.villain().life, 20, "Still blocked, so no damage to the player.")


func test_a_double_striker_that_kills_its_blocker_deals_nothing_more_without_trample() -> void:
	var duelist: MmCardDefinition = Scenario.creature("Duelist", 2, 2, [DoubleStrikeAbility.new()])
	var engine: MmEngine = Scenario.combat_ready([duelist], [_bear()])
	var duelist_id: int = Scenario.permanent_named(engine, engine.hero().id, "Duelist")
	var bear: int = Scenario.permanent_named(engine, engine.villain().id, "Bear")
	Scenario.declare_attackers(engine, [duelist_id])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[bear, duelist_id]])

	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_null(engine.game_state().object(bear))
	assert_eq(engine.villain().life, 20)
	assert_eq(Scenario.combat_damage_events(engine).size(), 1)


func test_a_trampling_double_striker_that_kills_its_blocker_hits_the_player_next() -> void:
	var brute: MmCardDefinition = Scenario.creature("Brute", 2, 2, [DoubleStrikeAbility.new(), TrampleAbility.new()])
	var engine: MmEngine = Scenario.combat_ready([brute], [_bear()])
	var brute_id: int = Scenario.permanent_named(engine, engine.hero().id, "Brute")
	var bear: int = Scenario.permanent_named(engine, engine.villain().id, "Bear")
	Scenario.declare_attackers(engine, [brute_id])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[bear, brute_id]])

	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_null(engine.game_state().object(bear))
	assert_eq(engine.villain().life, 18, "CR 702.19e: all of the second strike goes to the player.")


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)
