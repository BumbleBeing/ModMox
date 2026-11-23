extends GutTest
## "This creature can't be blocked." (CR 509.1b): a restriction on each blocker, so no
## creature may block it, as no creature without flying or reach may block a flyer.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_a_blocker_can_block_another_attacker_but_not_one_that_cant_be_blocked() -> void:
	var engine: MmEngine = Scenario.combat_ready([_phantom(), _bear()], [_bear()])
	var phantom: int = Scenario.permanent_named(engine, engine.hero().id, "Phantom")
	var attacking_bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var blocker: int = Scenario.permanent_named(engine, engine.villain().id, "Bear")
	Scenario.declare_attackers(engine, [phantom, attacking_bear])
	Scenario.pass_to_blockers(engine)
	var before: String = engine.fingerprint()

	var decision: DeclareBlockersDecision = engine.pending_decision() as DeclareBlockersDecision
	assert_eq(decision.blockable_by_blocker[blocker], [attacking_bear])
	assert_ne(engine.submit([[blocker, phantom]]), "")
	assert_eq(engine.fingerprint(), before)
	assert_eq(engine.submit([[blocker, attacking_bear]]), "")


func test_alone_it_asks_for_no_blockers_and_deals_its_damage_to_the_player() -> void:
	var engine: MmEngine = Scenario.combat_ready([_phantom()], [_bear(), _bear()])
	Scenario.declare_attackers(engine, [Scenario.permanent_named(engine, engine.hero().id, "Phantom")])

	Scenario.pass_until_step(engine, Step.DECLARE_BLOCKERS)

	assert_true(engine.pending_decision() is PriorityDecision, "No creature can block anything.")
	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)
	assert_eq(engine.villain().life, 18)


func test_a_creature_that_gains_it_after_attacking_cant_be_blocked() -> void:
	var fade: MmCardDefinition = Scenario.creature_spell_until_end_of_turn("Fade",
		Scenario.gain_abilities([CantBeBlockedAbility.new()] as Array[MmAbility], Scenario.targeted(0)))
	var hero_creatures: Array[MmCardDefinition] = [_bear()]
	var villain_creatures: Array[MmCardDefinition] = [Scenario.creature("Ogre", 3, 3)]
	var extras: Array[MmCardDefinition] = [fade]
	var engine: MmEngine = Scenario.combat_ready(hero_creatures, villain_creatures, extras)
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.declare_attackers(engine, [bear])

	assert_eq(Scenario.cast_and_resolve(engine, "Fade", [MmReference.to_object(bear)]), "")
	Scenario.pass_until_step(engine, Step.DECLARE_BLOCKERS)

	assert_true(engine.pending_decision() is PriorityDecision, "The Ogre can no longer block the Bear.")


## A 2/1 with "This creature can't be blocked."
func _phantom() -> MmCardDefinition:
	return Scenario.creature("Phantom", 2, 1, [CantBeBlockedAbility.new()])


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)
