extends GutTest
## CR 510: combat damage. Unblocked attackers damage the defending player, blocked ones
## and their blockers damage each other, and an attacker blocked by several creatures has
## its damage divided as its controller chooses (CR 510.1c, no damage assignment order).
## CR 702.19: trample. CR 514.2: damage wears off in the cleanup step.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_an_unblocked_attacker_deals_damage_equal_to_its_power_to_the_defending_player() -> void:
	var engine: MmEngine = Scenario.combat_ready([_bear()], [])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.declare_attackers(engine, [bear])

	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(engine.villain().life, 18)
	var events: Array[DamageEvent] = Scenario.combat_damage_events(engine)
	assert_eq(events.size(), 1)
	assert_eq(events[0].source_object_id, bear)
	assert_true(events[0].recipient.equals(MmReference.to_player(engine.villain().id)))


func test_an_attacker_and_its_blocker_deal_damage_to_each_other() -> void:
	var engine: MmEngine = Scenario.combat_ready([_bear()], [_ogre()])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	Scenario.declare_attackers(engine, [bear])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[ogre, bear]])

	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(Scenario.damage_on(engine, ogre), 2)
	assert_eq(Scenario.damage_on(engine, bear), 3)
	assert_eq(engine.villain().life, 20, "A blocked attacker without trample deals no damage to the player.")


func test_lethal_damage_leaves_the_creature_on_the_battlefield_until_state_based_actions_exist() -> void:
	var engine: MmEngine = Scenario.combat_ready([_bear()], [_ogre()])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	Scenario.declare_attackers(engine, [bear])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[ogre, bear]])

	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(engine.game_state().object(bear).zone(), engine.game_state().battlefield)


func test_an_attacker_blocked_by_two_creatures_divides_its_damage_as_its_controller_chooses() -> void:
	var engine: MmEngine = Scenario.combat_ready([_ogre()], [_bear(), _bear()])
	var ogre: int = Scenario.permanent_named(engine, engine.hero().id, "Ogre")
	var bears: Array[int] = Scenario.permanents_named(engine, engine.villain().id, "Bear")
	Scenario.declare_attackers(engine, [ogre])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[bears[0], ogre], [bears[1], ogre]])

	Scenario.pass_until_step(engine, Step.COMBAT_DAMAGE)

	var decision: DivideCombatDamageDecision = engine.pending_decision() as DivideCombatDamageDecision
	assert_not_null(decision)
	assert_eq(decision.player_id, engine.hero().id)
	assert_eq(decision.attacker_id, ogre)
	assert_eq(decision.amount, 3)
	assert_eq(decision.recipients.size(), 2)
	assert_true(decision.recipients[0].equals(MmReference.to_object(bears[0])))
	assert_true(decision.recipients[1].equals(MmReference.to_object(bears[1])))
	assert_eq(engine.submit([1, 2]), "")
	assert_eq(Scenario.damage_on(engine, bears[0]), 1)
	assert_eq(Scenario.damage_on(engine, bears[1]), 2)
	assert_eq(Scenario.damage_on(engine, ogre), 4, "Both blockers deal their damage.")


func test_all_of_the_damage_may_go_to_one_blocker() -> void:
	var engine: MmEngine = _ogre_double_blocked()
	var bears: Array[int] = Scenario.permanents_named(engine, engine.villain().id, "Bear")

	assert_eq(engine.submit([0, 3]), "")

	assert_eq(Scenario.damage_on(engine, bears[0]), 0)
	assert_eq(Scenario.damage_on(engine, bears[1]), 3)


func test_an_illegal_division_is_rejected_and_changes_nothing() -> void:
	var engine: MmEngine = _ogre_double_blocked()
	var before: String = engine.fingerprint()

	assert_ne(engine.submit([2, 2]), "", "More than the attacker's power.")
	assert_ne(engine.submit([1, 1]), "", "Less than the attacker's power.")
	assert_ne(engine.submit([-1, 4]), "", "A negative amount.")
	assert_ne(engine.submit([3]), "", "One amount per recipient.")
	assert_ne(engine.submit(3), "", "Not a list.")

	assert_eq(engine.fingerprint(), before)


func test_no_division_is_asked_for_an_attacker_with_one_blocker() -> void:
	var engine: MmEngine = Scenario.combat_ready([_ogre()], [_bear()])
	var ogre: int = Scenario.permanent_named(engine, engine.hero().id, "Ogre")
	var bear: int = Scenario.permanent_named(engine, engine.villain().id, "Bear")
	Scenario.declare_attackers(engine, [ogre])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[bear, ogre]])

	Scenario.pass_until_step(engine, Step.COMBAT_DAMAGE)

	assert_true(engine.pending_decision() is PriorityDecision)
	assert_eq(Scenario.damage_on(engine, bear), 3)


func test_an_attacker_with_no_power_deals_no_damage() -> void:
	var engine: MmEngine = Scenario.combat_ready([Scenario.creature("Wall", 0, 4)], [])
	Scenario.declare_attackers(engine, Scenario.permanents_named(engine, engine.hero().id, "Wall"))

	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(engine.villain().life, 20)
	assert_eq(Scenario.combat_damage_events(engine), [], "CR 120.8: 0 damage is not dealt.")


func test_an_attacker_stays_blocked_after_its_only_blocker_leaves() -> void:
	var exile: MmCardDefinition = Scenario.exile_spell("Banish")
	var engine: MmEngine = Scenario.combat_ready([_bear()], [_ogre()], [exile])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	Scenario.declare_attackers(engine, [bear])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[ogre, bear]])

	Scenario.cast_and_resolve(engine, "Banish", [MmReference.to_object(ogre)])
	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_true(engine.game_state().combat.is_blocked(bear), "CR 509.1h: it remains blocked.")
	assert_eq(engine.game_state().combat.blockers_of(engine.game_state(), bear), [], "CR 506.4")
	assert_eq(engine.villain().life, 20, "CR 510.1c: a blocked creature with no blockers assigns no damage.")
	assert_eq(Scenario.combat_damage_events(engine), [])


func test_a_blocker_whose_attacker_left_deals_no_damage() -> void:
	var exile: MmCardDefinition = Scenario.exile_spell("Banish")
	var engine: MmEngine = Scenario.combat_ready([_bear()], [_ogre()], [], [exile])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	Scenario.declare_attackers(engine, [bear])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[ogre, bear]])
	Scenario.pass_priority(engine)

	Scenario.cast_and_resolve(engine, "Banish", [MmReference.to_object(bear)])
	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(Scenario.combat_damage_events(engine), [])


# --- Trample --------------------------------------------------------------------------


func test_a_trampler_must_assign_lethal_damage_to_its_blocker_before_the_player() -> void:
	var engine: MmEngine = _rhino_blocked_by_bear()
	var decision: DivideCombatDamageDecision = engine.pending_decision() as DivideCombatDamageDecision
	assert_not_null(decision, "A trampler with one blocker still chooses.")
	assert_eq(decision.recipients.size(), 2)
	assert_true(decision.recipients[1].equals(MmReference.to_player(engine.villain().id)))

	assert_ne(engine.submit([1, 3]), "", "The Bear has not been assigned lethal damage.")
	assert_eq(engine.submit([2, 2]), "")

	assert_eq(engine.villain().life, 18)
	assert_eq(Scenario.damage_on(engine, Scenario.permanent_named(engine, engine.villain().id, "Bear")), 2)


func test_a_trampler_may_assign_more_than_lethal_damage_to_its_blocker() -> void:
	var engine: MmEngine = _rhino_blocked_by_bear()

	assert_eq(engine.submit([4, 0]), "")

	assert_eq(engine.villain().life, 20)


func test_lethal_damage_for_trample_counts_damage_already_marked() -> void:
	var shock: MmCardDefinition = Scenario.free_shock("Shock", 1)
	var engine: MmEngine = Scenario.combat_ready([_rhino()], [_bear()], [shock])
	var rhino: int = Scenario.permanent_named(engine, engine.hero().id, "Rhino")
	var bear: int = Scenario.permanent_named(engine, engine.villain().id, "Bear")
	Scenario.declare_attackers(engine, [rhino])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[bear, rhino]])
	Scenario.cast_and_resolve(engine, "Shock", [MmReference.to_object(bear)])

	Scenario.pass_until_step(engine, Step.COMBAT_DAMAGE)

	assert_eq(engine.submit([1, 3]), "", "One more damage is lethal for a 2/2 with 1 damage.")
	assert_eq(engine.villain().life, 17)


func test_a_trampler_without_power_beyond_lethal_is_not_asked() -> void:
	var engine: MmEngine = Scenario.combat_ready([_trampler("Boar", 2, 2)], [_bear()])
	var boar: int = Scenario.permanent_named(engine, engine.hero().id, "Boar")
	var bear: int = Scenario.permanent_named(engine, engine.villain().id, "Bear")
	Scenario.declare_attackers(engine, [boar])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[bear, boar]])

	Scenario.pass_until_step(engine, Step.COMBAT_DAMAGE)

	assert_true(engine.pending_decision() is PriorityDecision)
	assert_eq(Scenario.damage_on(engine, bear), 2)
	assert_eq(engine.villain().life, 20)


func test_a_trampler_whose_blockers_all_left_deals_all_its_damage_to_the_player() -> void:
	var exile: MmCardDefinition = Scenario.exile_spell("Banish")
	var engine: MmEngine = Scenario.combat_ready([_rhino()], [_bear()], [exile])
	var rhino: int = Scenario.permanent_named(engine, engine.hero().id, "Rhino")
	var bear: int = Scenario.permanent_named(engine, engine.villain().id, "Bear")
	Scenario.declare_attackers(engine, [rhino])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[bear, rhino]])
	Scenario.cast_and_resolve(engine, "Banish", [MmReference.to_object(bear)])

	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(engine.villain().life, 16, "CR 702.19e")


# --- Damage outside combat and cleanup --------------------------------------------------


func test_a_spell_marks_damage_on_a_creature() -> void:
	var shock: MmCardDefinition = Scenario.free_shock("Shock", 3)
	var engine: MmEngine = Scenario.combat_ready([], [_ogre()], [shock])
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")

	assert_eq(Scenario.cast_and_resolve(engine, "Shock", [MmReference.to_object(ogre)]), "")

	assert_eq(Scenario.damage_on(engine, ogre), 3, "CR 120.3e")
	var damage: DamageEvent = null
	for event: MmEvent in engine.event_log():
		if event is DamageEvent:
			damage = event as DamageEvent
	assert_false(damage.is_combat)


func test_damage_is_removed_in_the_cleanup_step() -> void:
	var engine: MmEngine = Scenario.combat_ready([_bear()], [_ogre()])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	Scenario.declare_attackers(engine, [bear])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[ogre, bear]])

	Scenario.play_until_game_turn(engine, 4)

	assert_eq(Scenario.damage_on(engine, bear), 0, "CR 514.2")
	assert_eq(Scenario.damage_on(engine, ogre), 0)
	var removed: Array[int] = []
	for event: MmEvent in engine.event_log():
		if event is DamageRemovedEvent:
			removed.append((event as DamageRemovedEvent).object_id)
	removed.sort()
	var expected: Array[int] = [bear, ogre]
	expected.sort()
	assert_eq(removed, expected, "One event per damaged permanent, and none for the others.")


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)


func _ogre() -> MmCardDefinition:
	return Scenario.creature("Ogre", 3, 3)


func _rhino() -> MmCardDefinition:
	return _trampler("Rhino", 4, 4)


func _trampler(card_name: String, power: int, toughness: int) -> MmCardDefinition:
	return Scenario.creature(card_name, power, toughness, [TrampleAbility.new()])


## The Hero's 3/3 Ogre attacking, blocked by two 2/2 Bears, with the division pending.
func _ogre_double_blocked() -> MmEngine:
	var engine: MmEngine = Scenario.combat_ready([_ogre()], [_bear(), _bear()])
	var ogre: int = Scenario.permanent_named(engine, engine.hero().id, "Ogre")
	var bears: Array[int] = Scenario.permanents_named(engine, engine.villain().id, "Bear")
	Scenario.declare_attackers(engine, [ogre])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[bears[0], ogre], [bears[1], ogre]])
	Scenario.pass_until_step(engine, Step.COMBAT_DAMAGE)
	assert_true(engine.pending_decision() is DivideCombatDamageDecision)
	return engine


## The Hero's 4/4 trampling Rhino attacking, blocked by a 2/2 Bear, with the division
## pending.
func _rhino_blocked_by_bear() -> MmEngine:
	var engine: MmEngine = Scenario.combat_ready([_rhino()], [_bear()])
	var rhino: int = Scenario.permanent_named(engine, engine.hero().id, "Rhino")
	var bear: int = Scenario.permanent_named(engine, engine.villain().id, "Bear")
	Scenario.declare_attackers(engine, [rhino])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[bear, rhino]])
	Scenario.pass_until_step(engine, Step.COMBAT_DAMAGE)
	return engine
