extends GutTest
## "[players] sacrifice(s) [count] [filter]" as an effect (CR 701.21a), as Agent of the
## Fates's "each opponent sacrifices a creature of their choice": each player chooses that
## many of the permanents they control that match, as it resolves, and they move to their
## owners' graveyards all at once. A player is asked only when there is a choice. It is not
## destruction, so indestructible never stops it. Edict is an instant costing {0}, "Each
## opponent sacrifices a creature."

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const NO_CARDS: Array[MmCardDefinition] = []


func test_the_opponent_chooses_which_creature_and_it_goes_to_their_graveyard() -> void:
	var engine: MmEngine = _hero_main([Scenario.creature("Mine", 1, 1)],
		[Scenario.creature("Bear", 2, 2), Scenario.creature("Wolf", 3, 3)])
	var wolf: int = Scenario.permanent_named(engine, engine.villain().id, "Wolf")
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Edict")), "")
	assert_eq(Scenario.pass_to_permanents_choice(engine), "")

	var asked: ChoosePermanentsDecision = engine.pending_decision() as ChoosePermanentsDecision
	assert_eq(asked.player_id, engine.villain().id, "Each opponent chooses their own.")
	assert_eq(asked.purpose, ChoosePermanentsDecision.Purpose.SACRIFICE)
	assert_true(asked.is_for_effect, "Asked by an effect as it resolves, not paid as a cost.")
	assert_eq(asked.count, 1)
	assert_eq(asked.candidate_ids.size(), 2, "Only the Villain's creatures.")
	assert_eq(engine.submit([wolf] as Array[int]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.card_in_graveyard(engine, engine.villain(), "Wolf"), -1)
	assert_ne(Scenario.permanent_named(engine, engine.villain().id, "Bear"), -1)
	assert_ne(Scenario.permanent_named(engine, engine.hero().id, "Mine"), -1, "The caster sacrifices nothing.")
	var moved: Array[MmEvent] = Scenario.events_of(engine, ZoneChangeEvent).filter(func(event: MmEvent) -> bool:
		return (event as ZoneChangeEvent).object_id == wolf)
	assert_eq((moved[0] as ZoneChangeEvent).reason, ZoneChangeEvent.Reason.SACRIFICE)


func test_with_one_creature_it_is_sacrificed_without_asking() -> void:
	var engine: MmEngine = _hero_main(NO_CARDS, [Scenario.creature("Bear", 2, 2)])

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Edict")), "")
	while not engine.game_state().stack.is_empty():
		assert_false(engine.pending_decision() is ChoosePermanentsDecision, "No choice to make.")
		assert_eq(Scenario.pass_priority(engine), "")

	assert_ne(Scenario.card_in_graveyard(engine, engine.villain(), "Bear"), -1)


func test_with_no_creature_nothing_happens() -> void:
	var engine: MmEngine = _hero_main([Scenario.creature("Mine", 1, 1)], NO_CARDS)
	var graveyard: int = engine.villain().graveyard.size()

	assert_eq(Scenario.cast_and_resolve(engine, "Edict"), "")

	assert_eq(engine.villain().graveyard.size(), graveyard)
	assert_ne(Scenario.permanent_named(engine, engine.hero().id, "Mine"), -1)


func test_an_indestructible_creature_is_sacrificed_all_the_same() -> void:
	var stone: MmCardDefinition = Scenario.creature("Stone", 2, 2, [IndestructibleAbility.new()])
	var engine: MmEngine = _hero_main(NO_CARDS, [stone])

	assert_eq(Scenario.cast_and_resolve(engine, "Edict"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.card_in_graveyard(engine, engine.villain(), "Stone"), -1, "CR 701.21a: not destruction.")


func test_only_what_matches_the_filter_may_be_chosen() -> void:
	var lamp: MmCardDefinition = Scenario.artifact("Lamp", [])
	var engine: MmEngine = _hero_main(NO_CARDS, [lamp, Scenario.creature("Bear", 2, 2)])

	assert_eq(Scenario.cast_and_resolve(engine, "Edict"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.card_in_graveyard(engine, engine.villain(), "Bear"), -1, "The only creature.")
	assert_ne(Scenario.permanent_named(engine, engine.villain().id, "Lamp"), -1)


func test_you_may_be_the_one_who_sacrifices() -> void:
	var own: MmCardDefinition = Scenario.instant("Offering", Scenario.mana_cost(0), [], [Scenario.sacrifice(Scenario.you())])
	var engine: MmEngine = _hero_main([Scenario.creature("Mine", 1, 1)], [Scenario.creature("Bear", 2, 2)], [own])

	assert_eq(Scenario.cast_and_resolve(engine, "Offering"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Mine"), -1)
	assert_ne(Scenario.permanent_named(engine, engine.villain().id, "Bear"), -1)


## The Hero in their main phase of Game Turn 3 holding an Edict, or [param hero_extras], with
## [param hero_permanents] cast on Game Turn 1 and [param villain_permanents] on Game Turn 2.
func _hero_main(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition] = [Scenario.free_edict()]) -> MmEngine:
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hero_extras, NO_CARDS,
		3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
