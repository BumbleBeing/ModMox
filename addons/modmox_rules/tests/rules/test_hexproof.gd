extends GutTest
## Hexproof (CR 702.11b): "This permanent can't be the target of spells or abilities your
## opponents control." Its controller may still target it, and an effect that does not
## target reaches it.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_an_opponents_spell_cannot_target_a_hexproof_creature() -> void:
	var engine: MmEngine = _main_ready([], [_slick(), Scenario.creature("Bear", 2, 2)], [Scenario.free_shock("Shock", 3)])
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Shock"))

	var decision: ChooseTargetDecision = engine.pending_decision() as ChooseTargetDecision

	assert_false(_has_candidate(decision, _permanent(engine, engine.villain().id, "Slick")), "CR 702.11b")
	assert_true(_has_candidate(decision, _permanent(engine, engine.villain().id, "Bear")))


func test_its_controllers_own_spell_can_target_a_hexproof_creature() -> void:
	var engine: MmEngine = _main_ready([_slick()], [], [Scenario.free_shock("Shock", 3)])
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Shock"))

	var decision: ChooseTargetDecision = engine.pending_decision() as ChooseTargetDecision

	assert_true(_has_candidate(decision, _permanent(engine, engine.hero().id, "Slick")), "Only opponents are kept out.")


func test_an_ability_an_opponent_controls_cannot_target_a_hexproof_creature() -> void:
	var pinger: MmCardDefinition = Scenario.creature("Pinger", 1, 1, [_ping_ability()])
	var engine: MmEngine = _main_ready([pinger], [_slick(), Scenario.creature("Bear", 2, 2)], [])

	Scenario.activate(engine, Scenario.permanent_named(engine, engine.hero().id, "Pinger"))

	var decision: ChooseTargetDecision = engine.pending_decision() as ChooseTargetDecision
	assert_false(_has_candidate(decision, _permanent(engine, engine.villain().id, "Slick")), "CR 702.11b")
	assert_true(_has_candidate(decision, _permanent(engine, engine.villain().id, "Bear")))


func test_a_spell_fizzles_when_its_only_target_gains_hexproof() -> void:
	# CR 608.2b: the target is rechecked on resolution.
	var gift: MmCardDefinition = Scenario.creature_spell_until_end_of_turn("Gift",
		Scenario.gain_abilities([HexproofAbility.new()], Scenario.targeted(0)))
	var engine: MmEngine = _main_ready([], [Scenario.creature("Bear", 2, 2)], [Scenario.free_shock("Shock", 3), gift])
	var bear: MmReference = _permanent(engine, engine.villain().id, "Bear")
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Shock"), [bear])
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Gift"), [bear])

	Scenario.resolve_stack(engine)

	assert_eq(Scenario.damage_on(engine, bear.id), 0)
	assert_eq(Scenario.last_reason_into(engine, MmZone.Kind.GRAVEYARD), ZoneChangeEvent.Reason.DID_NOT_RESOLVE)


func test_an_effect_that_does_not_target_still_reaches_a_hexproof_creature() -> void:
	var shock: MmCardDefinition = Scenario.overloaded(Scenario.free_shock("Shock", 3))
	var slick: MmCardDefinition = Scenario.creature("Slick", 2, 4, [HexproofAbility.new()])
	var engine: MmEngine = _main_ready([], [slick], [shock])

	assert_eq(Scenario.cast_and_resolve(engine, "Shock"), "")

	assert_eq(Scenario.damage_on(engine, _permanent(engine, engine.villain().id, "Slick").id), 3)


func _slick() -> MmCardDefinition:
	return Scenario.creature("Slick", 2, 2, [HexproofAbility.new()])


## "{T}: This deals 1 damage to any target."
func _ping_ability() -> ActivatedAbility:
	var ability: ActivatedAbility = ActivatedAbility.new()
	ability.costs = [TapCost.new()]
	ability.targets = [Scenario.any_target()]
	ability.effects = [Scenario.deal_damage(1, Scenario.targeted(0))]
	return ability


func _permanent(engine: MmEngine, player_id: int, card_name: String) -> MmReference:
	return MmReference.to_object(Scenario.permanent_named(engine, player_id, card_name))


func _has_candidate(decision: ChooseTargetDecision, wanted: MmReference) -> bool:
	for candidate: MmReference in decision.candidates:
		if candidate.equals(wanted):
			return true
	return false


func _main_ready(hero_creatures: Array[MmCardDefinition], villain_creatures: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_creatures, villain_creatures, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_creatures, villain_creatures, hero_extras, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	return engine
