extends GutTest
## Prowess (CR 702.108a): "Whenever you cast a noncreature spell, this creature gets +1/+1
## until end of turn." It triggers as the spell becomes cast, so it resolves first, and each
## instance triggers on its own (CR 702.108b). A copy of a spell is never cast (CR 707.10).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_a_noncreature_spell_gives_it_plus_one_plus_one_until_end_of_turn() -> void:
	var engine: MmEngine = _hero_main([Scenario.monk()], [_gift()])
	var monk: int = Scenario.permanent_named(engine, engine.hero().id, "Monk")

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Gift")), "")

	var stacked: Array[MmGameObject] = Scenario.stacked_abilities(engine)
	assert_eq(stacked.size(), 1)
	assert_true(stacked[0].ability is ProwessAbility)
	assert_eq(Scenario.stack_ids(engine)[0], stacked[0].id, "It goes on the stack above the spell.")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(Scenario.pt(engine, monk), [2, 2])
	Scenario.play_until_step(engine, 4, Step.UPKEEP)
	assert_eq(Scenario.pt(engine, monk), [1, 1], "Until end of turn.")


func test_a_creature_spell_triggers_nothing() -> void:
	var engine: MmEngine = _hero_main([Scenario.monk()], [Scenario.creature("Bear", 2, 2)])

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bear")), "")

	assert_eq(Scenario.stacked_abilities(engine).size(), 0)


func test_an_opponents_spell_triggers_nothing() -> void:
	var engine: MmEngine = _hero_main([], [_gift()], [Scenario.monk()])

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Gift")), "")

	assert_eq(Scenario.stacked_abilities(engine).size(), 0, "\"You\" is the Villain, the Monk's controller.")


func test_two_instances_each_trigger() -> void:
	var twice: MmCardDefinition = Scenario.monk("Monk", [ProwessAbility.new()])
	var engine: MmEngine = _hero_main([twice], [_gift()])
	var monk: int = Scenario.permanent_named(engine, engine.hero().id, "Monk")

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Gift")), "")

	assert_eq(_triggers_of(engine, "Monk"), 2, "CR 702.108b.")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(Scenario.pt(engine, monk), [3, 3])


func test_a_copy_of_a_spell_triggers_nothing() -> void:
	var engine: MmEngine = _hero_main([Scenario.monk()], [_gift(), Scenario.free_twin()])
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Gift")), "")
	var gift: int = _stack_card_named(engine, "Gift")

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Twin"), [MmReference.to_object(gift)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(_triggers_of(engine, "Monk"), 2, "The Gift and the Twin were cast; the copy of the Gift was not.")


func test_prowess_is_saved_with_its_card() -> void:
	var path: String = "user://test_prowess.tres"
	assert_eq(ResourceSaver.save(Scenario.monk(), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var prowess: ProwessAbility = loaded.abilities[0] as ProwessAbility
	assert_not_null(prowess)
	assert_eq((prowess.trigger as SpellCastTrigger).whose, MmTrigger.Whose.YOU)
	assert_eq(prowess.effects.size(), 1)
	DirAccess.remove_absolute(path)


# --- Helpers ---------------------------------------------------------------------------


## An instant costing {0}: "You gain 1 life."
func _gift(card_name: String = "Gift") -> MmCardDefinition:
	return Scenario.instant(card_name, Scenario.mana_cost(0), [], [Scenario.gain_life(1, Scenario.you())])


## The ID of the spell named [param card_name] on the stack, or 0.
func _stack_card_named(engine: MmEngine, card_name: String) -> int:
	for item: MmGameObject in engine.game_state().stack.objects():
		if item.is_card_or_copy() and engine.game_state().characteristics_of(item).name == card_name:
			return item.id
	return 0


## How many times an ability of a permanent named [param card_name] has triggered.
func _triggers_of(engine: MmEngine, card_name: String) -> int:
	var count: int = 0
	for event: MmEvent in Scenario.events_of(engine, AbilityTriggeredEvent):
		if (event as AbilityTriggeredEvent).pending.source_name == card_name:
			count += 1
	return count


## The Hero in their first main phase of Game Turn 3 with [param hero_permanents] cast on
## Game Turn 1, holding [param hand]; the Villain cast [param villain_permanents] on Game Turn 2.
func _hero_main(hero_permanents: Array[MmCardDefinition], hand: Array[MmCardDefinition],
		villain_permanents: Array[MmCardDefinition] = []) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hand)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hand, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
