extends GutTest
## Mentor (CR 702.134a): "Whenever this creature attacks, put a +1/+1 counter on target
## attacking creature with lesser power." The power is compared as the target is chosen and
## again as it resolves (CR 608.2b). Each instance triggers on its own (CR 702.134b).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const PLUS_ONE := MmCounter.Kind.PLUS_ONE_PLUS_ONE


func test_it_puts_a_counter_on_an_attacker_with_lesser_power() -> void:
	var engine: MmEngine = _combat_ready([_mentor(), _creature("Squire", 1)], [])
	var mentor: int = Scenario.permanent_named(engine, engine.hero().id, "Mentor")
	var squire: int = Scenario.permanent_named(engine, engine.hero().id, "Squire")

	assert_eq(Scenario.declare_attackers(engine, [mentor, squire]), "")
	_answer_target(engine, squire)
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.counters_on(engine, squire, PLUS_ONE), 1)
	assert_eq(Scenario.counters_on(engine, mentor, PLUS_ONE), 0)


func test_only_an_attacking_creature_with_lesser_power_may_be_its_target() -> void:
	var engine: MmEngine = _combat_ready([_mentor(), _creature("Squire", 1), _creature("Peer", 2),
		_creature("Homebody", 1)], [])
	var mentor: int = Scenario.permanent_named(engine, engine.hero().id, "Mentor")
	var squire: int = Scenario.permanent_named(engine, engine.hero().id, "Squire")
	var peer: int = Scenario.permanent_named(engine, engine.hero().id, "Peer")

	assert_eq(Scenario.declare_attackers(engine, [mentor, squire, peer]), "")

	var asked: ChooseTargetDecision = engine.pending_decision() as ChooseTargetDecision
	var ids: Array[int] = []
	if asked != null:
		for candidate: MmReference in asked.candidates:
			ids.append(candidate.id)
		_answer_target(engine, squire)
	else:
		ids.append(squire)  # Its one legal target, chosen without asking.
	assert_eq(ids, [squire] as Array[int], "Not an equal power, not one at home, not itself.")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(Scenario.counters_on(engine, squire, PLUS_ONE), 1)
	assert_eq(Scenario.counters_on(engine, peer, PLUS_ONE), 0)


func test_with_no_lesser_attacker_it_does_nothing() -> void:
	var engine: MmEngine = _combat_ready([_mentor(), _creature("Peer", 2)], [])
	var mentor: int = Scenario.permanent_named(engine, engine.hero().id, "Mentor")
	var peer: int = Scenario.permanent_named(engine, engine.hero().id, "Peer")

	assert_eq(Scenario.declare_attackers(engine, [mentor, peer]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.counters_on(engine, peer, PLUS_ONE), 0)
	assert_eq(Scenario.counters_on(engine, mentor, PLUS_ONE), 0)


func test_a_target_grown_as_strong_as_the_mentor_by_then_gets_nothing() -> void:
	# CR 608.2b: the target is checked again as the ability resolves.
	var engine: MmEngine = _combat_ready([_mentor(), _creature("Squire", 1)], [],
		[Scenario.free_counters("Growth", PLUS_ONE, 1)])
	var mentor: int = Scenario.permanent_named(engine, engine.hero().id, "Mentor")
	var squire: int = Scenario.permanent_named(engine, engine.hero().id, "Squire")
	assert_eq(Scenario.declare_attackers(engine, [mentor, squire]), "")
	_answer_target(engine, squire)

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Growth"),
		[MmReference.to_object(squire)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.counters_on(engine, squire, PLUS_ONE), 1, "Growth's counter only: 2 is not less than 2.")


func test_two_instances_trigger_twice() -> void:
	# CR 702.134b.
	var engine: MmEngine = _combat_ready([_mentor("Mentor", [MentorAbility.new()]), _creature("Squire", 0)], [])
	var mentor: int = Scenario.permanent_named(engine, engine.hero().id, "Mentor")
	var squire: int = Scenario.permanent_named(engine, engine.hero().id, "Squire")

	assert_eq(Scenario.declare_attackers(engine, [mentor, squire]), "")
	_answer_target(engine, squire)
	_answer_target(engine, squire)
	_order_triggers(engine)
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.events_of(engine, AbilityTriggeredEvent).size(), 2)
	assert_eq(Scenario.counters_on(engine, squire, PLUS_ONE), 2)


func test_mentor_is_saved_with_its_card() -> void:
	var path: String = "user://test_mentor.tres"
	assert_eq(ResourceSaver.save(_mentor(), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var mentor: MentorAbility = loaded.abilities[0] as MentorAbility
	assert_not_null(mentor)
	assert_true(mentor.trigger is AttackersDeclaredTrigger)
	assert_eq(mentor.targets.size(), 1)
	assert_eq(mentor.effects.size(), 1)
	DirAccess.remove_absolute(path)


# --- Helpers ---------------------------------------------------------------------------


## A 2/2 costing {0} with mentor, then [param abilities].
func _mentor(card_name: String = "Mentor", abilities: Array[MmAbility] = []) -> MmCardDefinition:
	var all: Array[MmAbility] = [MentorAbility.new()]
	all.append_array(abilities)
	return Scenario.creature(card_name, 2, 2, all)


func _creature(card_name: String, power: int) -> MmCardDefinition:
	return Scenario.creature(card_name, power, 3)


## Answers a target decision with [param target], if one is asked.
func _answer_target(engine: MmEngine, target: int) -> void:
	if engine.pending_decision() is ChooseTargetDecision:
		assert_eq(Scenario.choose_target(engine, MmReference.to_object(target)), "")


## Orders two triggers waiting to go on the stack, if they are asked.
func _order_triggers(engine: MmEngine) -> void:
	if engine.pending_decision() is OrderTriggersDecision:
		assert_eq(engine.submit(Scenario.default_answer(engine.pending_decision())), "")


func _combat_ready(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition] = []) -> MmEngine:
	var engine: MmEngine = Scenario.combat_ready(hero_permanents, villain_permanents, hero_extras)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
