extends GutTest
## Zone-change triggers (CR 603.6). Enters-the-battlefield triggers look forward (603.6a):
## permanents entering together see each other. Leaves-the-battlefield triggers look back in
## time (603.10a): what left at the same moment still triggers, using last-known
## information (CR 608.2h).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const CardType := MmCardTypes.CardType


func test_a_land_entering_triggers_damage_to_its_controller() -> void:
	var engine: MmEngine = _ankh_in_play()

	var land: int = Scenario.play_first_land(engine)

	var stacked: Array[MmGameObject] = Scenario.stacked_abilities(engine)
	assert_eq(stacked.size(), 1)
	assert_eq(stacked[0].triggering_object_id, land)
	assert_eq(stacked[0].controller_id, engine.hero().id, "The Ankh's controller controls the trigger.")
	Scenario.resolve_stack(engine)
	assert_eq(engine.villain().life, 18, "That land's controller.")
	assert_eq(engine.hero().life, 20)


func test_a_nonland_entering_does_not_trigger_a_land_trigger() -> void:
	var engine: MmEngine = _ankh_in_play()

	Scenario.cast_and_resolve(engine, "Bear")

	assert_eq(Scenario.events_of(engine, AbilityTriggeredEvent).size(), 0)


func test_permanents_entering_together_see_each_other() -> void:
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(_ankh_deck(), _villain_deck()),
		func(running: MmEngine) -> bool:
			Scenario.play_until_step(running, 1, Step.PRECOMBAT_MAIN)
			return Scenario.card_in_hand(running, running.hero(), "Ankh") != -1 \
				and Scenario.card_in_hand(running, running.hero(), "Forest") != -1)
	var state: MmGameState = engine.game_state().duplicate_state()
	var ankh: MmGameObject = state.object(Scenario.card_in_hand(engine, engine.hero(), "Ankh"))
	var forest: MmGameObject = state.object(Scenario.card_in_hand(engine, engine.hero(), "Forest"))
	var ankh_enters: ZoneChangeEvent = ZoneChangeEvent.new(ankh, state.battlefield, MmZone.BOTTOM, ZoneChangeEvent.Reason.RESOLVED)
	var forest_enters: ZoneChangeEvent = ZoneChangeEvent.new(forest, state.battlefield, MmZone.BOTTOM, ZoneChangeEvent.Reason.PLAY_LAND)

	state.perform_together([ankh_enters, forest_enters])

	assert_eq(state.pending_triggers.size(), 1, "CR 603.6a: the Ankh sees the Forest enter with it.")
	assert_eq(state.pending_triggers[0].triggering_object_id, forest_enters.new_object_id)
	assert_eq(ankh_enters.batch, forest_enters.batch)


func test_a_creature_dying_triggers_an_observer() -> void:
	var engine: MmEngine = _dies_game([_watcher_artifact()], [_goblin()], [_shock()])
	var goblin: int = Scenario.permanent_named(engine, engine.villain().id, "Goblin")

	Scenario.cast_and_resolve(engine, "Shock", [MmReference.to_object(goblin)])

	var stacked: Array[MmGameObject] = Scenario.stacked_abilities(engine)
	assert_eq(stacked.size(), 1)
	assert_eq(stacked[0].triggering_object_id, goblin, "The creature as it was on the battlefield.")
	Scenario.resolve_stack(engine)
	assert_eq(engine.hero().life, 21)


func test_an_observer_dying_at_the_same_time_still_triggers() -> void:
	var watcher: MmCardDefinition = Scenario.creature("Watcher", 1, 1,
		[Scenario.triggered(Scenario.dies(Scenario.of_type(CardType.CREATURE)), [Scenario.gain_life(1, Scenario.you())])])
	var engine: MmEngine = _dies_game([watcher], [_goblin()], [_quake()])

	Scenario.cast_and_resolve(engine, "Quake")

	assert_eq(engine.hero().graveyard.size(), 2, "The Quake and the Watcher.")
	assert_true(engine.pending_decision() is OrderTriggersDecision, "Two triggers: for itself and for the Goblin.")
	assert_eq(engine.submit([0, 1]), "")
	Scenario.resolve_stack(engine)
	assert_eq(engine.hero().life, 22, "CR 603.10a: it looked back in time.")


func test_a_creature_sees_its_own_death() -> void:
	var martyr: MmCardDefinition = Scenario.creature("Martyr", 1, 1,
		[Scenario.triggered(Scenario.dies(IsSourceFilter.new()), [Scenario.gain_life(2, Scenario.you())])])
	var engine: MmEngine = _dies_game([martyr], [], [_shock()])
	var martyr_id: int = Scenario.permanent_named(engine, engine.hero().id, "Martyr")

	Scenario.cast_and_resolve(engine, "Shock", [MmReference.to_object(martyr_id)])
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().life, 22)


func test_a_dies_trigger_can_read_the_creatures_last_known_power() -> void:
	var power: PowerValue = PowerValue.new()
	power.selection = TriggeringObjectSelection.new()
	var gain: GainLifeEffect = GainLifeEffect.new()
	gain.amount = power
	gain.players = Scenario.you()
	var mourner: MmCardDefinition = Scenario.artifact("Mourner", [Scenario.triggered(Scenario.dies(Scenario.of_type(CardType.CREATURE)), [gain])])
	var engine: MmEngine = _dies_game([mourner], [Scenario.creature("Ogre", 3, 1)], [_shock()])
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")

	Scenario.cast_and_resolve(engine, "Shock", [MmReference.to_object(ogre)])
	Scenario.resolve_stack(engine)

	assert_null(engine.game_state().object(ogre))
	assert_eq(engine.hero().life, 23, "CR 608.2h: its power as it last existed on the battlefield.")


func test_going_to_the_graveyard_from_the_stack_is_not_dying() -> void:
	var engine: MmEngine = _dies_game([_watcher_artifact()], [_goblin()], [_shock()])

	Scenario.cast_and_resolve(engine, "Shock", [MmReference.to_player(engine.villain().id)])

	assert_eq(Scenario.events_of(engine, AbilityTriggeredEvent).size(), 0)


## The Villain's first main phase, with the Hero's Ankh on the battlefield ("Whenever a
## land enters the battlefield, this deals 2 damage to that land's controller") and the
## Villain holding a Forest and a Bear.
func _ankh_in_play() -> MmEngine:
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(_ankh_deck(), _villain_deck()),
		func(running: MmEngine) -> bool:
			Scenario.play_until_step(running, 1, Step.PRECOMBAT_MAIN)
			if Scenario.cast_and_resolve(running, "Ankh") != "":
				return false
			Scenario.play_until_step(running, 2, Step.PRECOMBAT_MAIN)
			return Scenario.card_in_hand(running, running.villain(), "Forest") != -1 \
				and Scenario.card_in_hand(running, running.villain(), "Bear") != -1)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


func _ankh_deck() -> Array[MmCardDefinition]:
	var ankh: MmCardDefinition = Scenario.artifact("Ankh", [Scenario.triggered(
		Scenario.enters(Scenario.of_type(CardType.LAND)),
		[Scenario.deal_damage(2, Scenario.controller_of(TriggeringObjectSelection.new()))])])
	return Scenario.cycled([ankh, Scenario.basic_land("Forest")])


func _villain_deck() -> Array[MmCardDefinition]:
	return Scenario.cycled([Scenario.basic_land("Forest"), Scenario.creature("Bear", 2, 2)])


## Players with these permanents cast on Game Turns 1 and 2, stopped in the Hero's first
## main phase of Game Turn 3 with the extra cards in hand.
func _dies_game(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var no_extras: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hero_extras,
		no_extras, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


## "Whenever a creature dies, you gain 1 life."
func _watcher_artifact() -> MmCardDefinition:
	return Scenario.artifact("Watcher", [Scenario.triggered(Scenario.dies(Scenario.of_type(CardType.CREATURE)),
		[Scenario.gain_life(1, Scenario.you())])])


func _goblin() -> MmCardDefinition:
	return Scenario.creature("Goblin", 1, 1)


func _shock() -> MmCardDefinition:
	return Scenario.free_shock("Shock", 3)


## "Quake deals 1 damage to each creature."
func _quake() -> MmCardDefinition:
	return Scenario.instant("Quake", Scenario.mana_cost(0), [], [Scenario.deal_damage(1, Scenario.each(Scenario.of_type(CardType.CREATURE)))])
