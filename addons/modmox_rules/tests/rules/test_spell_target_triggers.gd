extends GutTest
## Heroic: "Whenever you cast a spell that targets this creature" (CR 601.2c, 601.2i). A
## spell's targets are chosen before it becomes cast, so a SpellCastTrigger whose filter is
## a TargetsFilter sees them. Activated abilities are not spells, and Heroic is an ability
## word with no rules meaning of its own (CR 207.2c).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const CardType := MmCardTypes.CardType


func test_casting_a_spell_that_targets_the_creature_triggers_it_once() -> void:
	var engine: MmEngine = _hero_main([Scenario.heroic(), _bears()], [], [_pump()])
	var life: int = engine.hero().life

	assert_eq(Scenario.cast(engine, _hand(engine, "Pump"), [_hero_creature(engine)]), "")

	var stack: Array[int] = Scenario.stack_ids(engine)
	assert_eq(stack.size(), 2, "The spell and one Heroic trigger.")
	assert_not_null(engine.game_state().object(stack[0]).ability, "CR 603.3: the trigger goes on top of the spell.")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(engine.hero().life, life + 5)


func test_a_spell_that_targets_another_creature_does_not_trigger_it() -> void:
	var engine: MmEngine = _hero_main([Scenario.heroic(), _bears()], [], [_pump()])
	var bears: int = Scenario.permanent_named(engine, engine.hero().id, "Bears")

	assert_eq(Scenario.cast(engine, _hand(engine, "Pump"), [MmReference.to_object(bears)]), "")

	assert_eq(Scenario.stack_ids(engine).size(), 1)


func test_an_opponents_spell_that_targets_the_creature_does_not_trigger_it() -> void:
	var engine: MmEngine = _hero_main([], [Scenario.heroic("Villain Hero")], [_pump()])
	var theirs: int = Scenario.permanent_named(engine, engine.villain().id, "Villain Hero")
	var life: int = engine.villain().life

	assert_eq(Scenario.cast(engine, _hand(engine, "Pump"), [MmReference.to_object(theirs)]), "")

	assert_eq(Scenario.stack_ids(engine).size(), 1, "\"Whenever you cast\": only its controller's spells.")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(engine.villain().life, life)


func test_a_spell_that_targets_only_a_player_does_not_trigger_it() -> void:
	var zap: MmCardDefinition = Scenario.free_shock("Zap", 1)
	var engine: MmEngine = _hero_main([Scenario.heroic()], [], [zap])

	assert_eq(Scenario.cast(engine, _hand(engine, "Zap"), [MmReference.to_player(engine.villain().id)]), "")

	assert_eq(Scenario.stack_ids(engine).size(), 1)


func test_an_activated_ability_that_targets_the_creature_does_not_trigger_it() -> void:
	var rod_ability: ActivatedAbility = ActivatedAbility.new()
	rod_ability.mana_cost = Scenario.mana_cost(0)
	rod_ability.targets = [Scenario.target(Scenario.of_type(CardType.CREATURE))]
	rod_ability.effects = [Scenario.until_end_of_turn(Scenario.modify_pt(1, 1, Scenario.targeted(0)))]
	var engine: MmEngine = _hero_main([Scenario.heroic(), Scenario.artifact("Rod", [rod_ability])], [], [])
	var rod: int = Scenario.permanent_named(engine, engine.hero().id, "Rod")

	assert_eq(Scenario.activate(engine, rod, [_hero_creature(engine)]), "")

	assert_eq(Scenario.stack_ids(engine).size(), 1, "Not a spell, so not \"whenever you cast\".")


func test_a_spell_with_two_targets_one_of_them_the_creature_triggers_it_once() -> void:
	var creature: TargetRequirement = Scenario.target(Scenario.of_type(CardType.CREATURE))
	var double: MmCardDefinition = Scenario.instant("Double", Scenario.mana_cost(0), [creature, creature.duplicate()], [
		Scenario.until_end_of_turn(Scenario.modify_pt(1, 1, Scenario.targeted(0))),
		Scenario.until_end_of_turn(Scenario.modify_pt(1, 1, Scenario.targeted(1))),
	])
	var engine: MmEngine = _hero_main([Scenario.heroic(), _bears()], [], [double])
	var bears: int = Scenario.permanent_named(engine, engine.hero().id, "Bears")
	var life: int = engine.hero().life

	assert_eq(Scenario.cast(engine, _hand(engine, "Double"), [MmReference.to_object(bears), _hero_creature(engine)]), "")

	assert_eq(Scenario.stack_ids(engine).size(), 2, "Its second target counts too, and only once.")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(engine.hero().life, life + 5)


func test_a_modal_spell_triggers_it_only_when_the_chosen_mode_targets_it() -> void:
	var engine: MmEngine = _hero_main([Scenario.heroic()], [], [_choice("Choice"), _choice("Other Choice")])

	assert_eq(Scenario.cast_mode(engine, _hand(engine, "Other Choice"), 1, [MmReference.to_player(engine.hero().id)]), "")
	assert_eq(Scenario.stack_ids(engine).size(), 1, "The other mode targets a player.")
	assert_eq(Scenario.cast_mode(engine, _hand(engine, "Choice"), 0, [_hero_creature(engine)]), "")

	assert_eq(Scenario.stack_ids(engine).size(), 3, "CR 700.2: the chosen mode's target.")


func test_a_spell_cast_with_flashback_that_targets_the_creature_triggers_it() -> void:
	var echo: MmCardDefinition = Scenario.flashback_sorcery("Echo", [Scenario.target(Scenario.of_type(CardType.CREATURE))],
		[Scenario.until_end_of_turn(Scenario.modify_pt(1, 1, Scenario.targeted(0)))], Scenario.flashback(Scenario.mana_cost(0)))
	var engine: MmEngine = _hero_main([Scenario.heroic()], [], [echo])
	var life: int = engine.hero().life
	assert_eq(Scenario.cast(engine, _hand(engine, "Echo"), [_hero_creature(engine)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	var in_graveyard: int = Scenario.card_in_graveyard(engine, engine.hero(), "Echo")

	assert_eq(Scenario.cast(engine, in_graveyard, [_hero_creature(engine)]), "")

	assert_eq(Scenario.stack_ids(engine).size(), 2, "CR 702.34a: cast from the graveyard, still cast.")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(engine.hero().life, life + 10)


func test_the_trigger_resolves_even_when_the_spell_is_countered() -> void:
	var engine: MmEngine = _hero_main([Scenario.heroic()], [], [_pump(), Scenario.free_counter("Counter")])
	var life: int = engine.hero().life
	assert_eq(Scenario.cast(engine, _hand(engine, "Pump"), [_hero_creature(engine)]), "")
	var pump: int = Scenario.stack_ids(engine)[1]

	assert_eq(Scenario.cast(engine, _hand(engine, "Counter"), [MmReference.to_object(pump)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.hero().life, life + 5, "CR 603.2: it triggered as the spell was cast.")
	assert_eq(Scenario.now(engine, _hero_creature(engine).id).power, 2, "The pump was countered.")


func test_a_spell_that_targets_a_creature_you_control_matches_an_inner_filter() -> void:
	var yours: ControlledByFilter = ControlledByFilter.new()
	yours.whose = MmTrigger.Whose.YOU
	var watcher: MmCardDefinition = Scenario.artifact("Watcher", [Scenario.triggered(
		Scenario.casts(Scenario.targets(yours), MmTrigger.Whose.YOU), [Scenario.gain_life(5, Scenario.you())])])
	var engine: MmEngine = _hero_main([watcher, _bears()], [_bears("Ogre")], [_pump(), _pump("Other Pump")])
	var bears: int = Scenario.permanent_named(engine, engine.hero().id, "Bears")
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")

	assert_eq(Scenario.cast(engine, _hand(engine, "Pump"), [MmReference.to_object(ogre)]), "")
	assert_eq(Scenario.stack_ids(engine).size(), 1, "The Ogre is the Villain's.")
	assert_eq(Scenario.cast(engine, _hand(engine, "Other Pump"), [MmReference.to_object(bears)]), "")

	assert_eq(Scenario.stack_ids(engine).size(), 3)


func test_copies_and_replays_see_the_trigger() -> void:
	var setup: MmEncounterSetup = _setup([Scenario.heroic()], [], [_pump()])
	var engine: MmEngine = _ready_engine(setup, [Scenario.heroic()], [], [_pump()])
	assert_not_null(engine, "No seed gave the needed hands.")
	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))

	assert_eq(Scenario.cast(copy, _hand(copy, "Pump"), [_hero_creature(copy)]), "")
	assert_eq(Scenario.cast(engine, _hand(engine, "Pump"), [_hero_creature(engine)]), "")

	assert_eq(Scenario.stack_ids(copy).size(), 2)
	var replayed: MmEngine = MmEngine.replay(setup, engine.decision_log())
	assert_eq(replayed.fingerprint(), engine.fingerprint())


## The Hero's first main phase of Game Turn 3, with [param hero_permanents] and
## [param villain_permanents] on the battlefield and [param hand] in the Hero's hand.
func _hero_main(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hand: Array[MmCardDefinition]) -> MmEngine:
	var engine: MmEngine = _ready_engine(_setup(hero_permanents, villain_permanents, hand), hero_permanents, villain_permanents, hand)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


func _setup(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hand: Array[MmCardDefinition]) -> MmEncounterSetup:
	return Scenario.combat_setup(hero_permanents, villain_permanents, hand)


func _ready_engine(setup: MmEncounterSetup, hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hand: Array[MmCardDefinition]) -> MmEngine:
	return Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hand, [], 3, Step.PRECOMBAT_MAIN)


func _pump(card_name: String = "Pump") -> MmCardDefinition:
	return Scenario.pump_spell(card_name, 1, 1)


## An instant costing {0}: "Choose one — • Target creature gets +1/+1 until end of turn.
## • Target player gains 1 life."
func _choice(card_name: String) -> MmCardDefinition:
	return Scenario.free_modal(card_name, [
		Scenario.ability_mode([Scenario.target(Scenario.of_type(CardType.CREATURE))],
			[Scenario.until_end_of_turn(Scenario.modify_pt(1, 1, Scenario.targeted(0)))]),
		Scenario.ability_mode([Scenario.target_player()], [Scenario.gain_life(1, Scenario.targeted(0))]),
	])


func _bears(card_name: String = "Bears") -> MmCardDefinition:
	return Scenario.creature(card_name, 2, 2)


func _hand(engine: MmEngine, card_name: String) -> int:
	return Scenario.card_in_hand(engine, engine.hero(), card_name)


func _hero_creature(engine: MmEngine) -> MmReference:
	return MmReference.to_object(Scenario.permanent_named(engine, engine.hero().id, "Hero"))
